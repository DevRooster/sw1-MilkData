const BaseService = require('./base.service');
const recorridoRepository = require('../../repositories/recorrido.repository');
const rutaRepository = require('../../repositories/ruta.repository');
const unidadRepository = require('../../repositories/unidad.repository');
const usuarioRepository = require('../../repositories/usuario.repository');
const rutaParadaRepository = require('../../repositories/rutaParada.repository');
const recorridoParadaRepository = require('../../repositories/recorridoParada.repository');
const recoleccionRepository = require('../../repositories/recoleccion.repository');
const proveedorRepository = require('../../repositories/proveedor.repository');
const { notFound, badRequest, forbidden } = require('../../utils/http-error');
const { ROLES } = require('../../security/role-permissions.config');
const { POR_PAGINA } = require('../../config/pagination.config');

const ESTADOS = {
  PLANIFICADO: 'PLANIFICADO',
  EN_RUTA: 'EN_RUTA',
  FINALIZADO: 'FINALIZADO',
  CANCELADO: 'CANCELADO',
};

/** Hora en HH:MM:SS a partir de la hora local del servidor. */
function horaActual() {
  const ahora = new Date();
  return [ahora.getHours(), ahora.getMinutes(), ahora.getSeconds()]
    .map((n) => String(n).padStart(2, '0'))
    .join(':');
}

function fechaActual() {
  const hoy = new Date();
  return [
    hoy.getFullYear(),
    String(hoy.getMonth() + 1).padStart(2, '0'),
    String(hoy.getDate()).padStart(2, '0'),
  ].join('-');
}

/**
 * Recorridos: la ejecución real de una ruta.
 *
 * El recorrido no empieza al crearse. Nace `PLANIFICADO` y recién cuando el
 * acopiador marca `EN_RUTA` se registra `horaInicio` y se copian las paradas
 * de la ruta. Sin ese cambio de estado no hay recoil.
 */
class RecorridoService extends BaseService {
  constructor() {
    super(recorridoRepository);
  }

  /**
   * Nombres de filtro que admite este listado.
   *
   * `list` está sobrescrito y construye su propio `where`, así que no usa
   * `_filtros()` de la base. Aun así tiene que declarar qué admite, porque el
   * controller rechaza con un 400 lo que no reconoce: sin esto, las consultas
   * que este servicio sí sabe responder llegarían como desconocidas.
   */
  nombresDeFiltro() {
    return ['estado', 'fecha', 'unidadId'];
  }

  // --- consultas ---

  async findById(contexto, id, trace = []) {
    trace.push('service');
    const recorrido = await this.repository.findOne(
      this._options(contexto, {
        where: { id },
        include: [
          { association: 'ruta' },
          { association: 'unidad' },
          { association: 'acopiador' },
          {
            association: 'paradas',
            include: [{ association: 'proveedor' }],
          },
        ],
      })
    );

    if (!recorrido) {
      throw notFound('Recorrido no encontrado.');
    }
    return this._ordenarParadas(recorrido.toJSON());
  }

  /**
   * Lista recorridos con filtros por estado, fecha y unidad.
   *
   * Los filtros llegan en la query (`?estado=EN_RUTA&fecha=2026-10-03`), así
   * que se convierten en `where` antes de paginar.
   */
  async list(contexto, trace = [], {
    pagina = 1, limite = POR_PAGINA, estado, fecha, unidadId, ...resto
  } = {}) {
    trace.push('service');
    const numeroPagina = Number(pagina);
    const numeroLimite = Number(limite);

    const where = this._where(contexto);
    if (estado) where.estado = estado;
    if (fecha) where.fecha = fecha;
    if (unidadId) where.unidadId = unidadId;

    const { count, rows } = await this.repository.findAndCountAll({
      ...this._options(contexto, resto),
      where,
      include: [{ association: 'ruta' }, { association: 'unidad' }],
      limit: numeroLimite,
      offset: (numeroPagina - 1) * numeroLimite,
    }, trace);

    return {
      items: rows.map((r) => r.toJSON()),
      paginacion: this._paginacion(numeroPagina, numeroLimite, count),
    };
  }

  /** El recorrido en curso de un acopiador, si tiene uno. */
  async actual(contexto, trace = []) {
    trace.push('service');
    const recorrido = await this.repository.findOne(
      this._options(contexto, {
        where: { acopiadorId: contexto.userId, estado: ESTADOS.EN_RUTA },
        include: [{ association: 'ruta' }, { association: 'unidad' }],
      }),
      trace
    );
    return recorrido ? recorrido.toJSON() : null;
  }

  // --- ciclo de vida ---

  /**
   * Crea un recorrido en PLANIFICADO. No copia paradas todavía: eso pasa al
   * arrancar, para que el plan refleje la ruta tal como está en ese momento.
   */
  async create(contexto, datos, trace = []) {
    trace.push('service');
    const plantaId = this._plantaId(contexto);

    const ruta = await rutaRepository.findOne(
      { where: { id: datos.rutaId, plantaId } },
      trace
    );
    if (!ruta) {
      throw notFound('Ruta no encontrada.');
    }

    const unidad = await unidadRepository.findOne(
      { where: { id: datos.unidadId, plantaId } },
      trace
    );
    if (!unidad) {
      throw notFound('Unidad no encontrada.');
    }

    const acopiador = await this._acopiador(contexto, datos.acopiadorId, trace);
    await this._validarAyudante(contexto, datos, trace);

    const recorrido = await this.repository.create({
      plantaId,
      rutaId: ruta.id,
      unidadId: unidad.id,
      acopiadorId: acopiador.id,
      ayudanteUsuarioId: datos.ayudanteUsuarioId || null,
      ayudanteNombre: datos.ayudanteNombre || null,
      ayudanteApellido: datos.ayudanteApellido || null,
      ayudanteDni: datos.ayudanteDni || null,
      ayudanteCelular: datos.ayudanteCelular || null,
      estado: ESTADOS.PLANIFICADO,
      fecha: datos.fecha || fechaActual(),
      observaciones: datos.observaciones || null,
    }, trace);

    return this.findById(contexto, recorrido.id, trace);
  }

  /**
   * EN RUTA. Solo el acopiador del recorrido puede arrancarlo, y solo desde
   * PLANIFICADO. Aquí se sellan las paradas de la ruta.
   */
  async iniciar(contexto, id, trace = [], datos = {}) {
    trace.push('service');
    const { recorrido, plantaId } = await this._recorrido(contexto, id, trace);

    this._exigirAcopiador(contexto, recorrido, 'arrancar');
    if (recorrido.estado !== ESTADOS.PLANIFICADO) {
      throw badRequest(`El recorrido ya está en estado ${recorrido.estado}.`);
    }

    const yaExiste = await recorridoParadaRepository.findAll(
      { where: { recorridoId: recorrido.id } },
      trace
    );
    if (!yaExiste.length) {
      const paradas = await rutaParadaRepository.findAll({
        where: { rutaId: recorrido.rutaId, plantaId },
        order: [['orden', 'ASC']],
      });
      for (const parada of paradas) {
        await recorridoParadaRepository.create({
          plantaId,
          recorridoId: recorrido.id,
          rutaParadaId: parada.id,
          proveedorId: parada.proveedorId,
          orden: parada.orden,
          estado: 'PENDIENTE',
        }, trace);
      }
    }

    const ahora = new Date();
    const cambios = {
      estado: ESTADOS.EN_RUTA,
      horaInicio: ahora.toTimeString().slice(0, 8),
      fechaInicio: ahora.toISOString().slice(0, 10),
    };
    if (datos.kilometrajeInicio !== undefined && datos.kilometrajeInicio !== null) {
      cambios.kilometrajeInicio = Number(datos.kilometrajeInicio);
    }

    await this.repository.update(recorrido.id, cambios);
    return this.findById(contexto, recorrido.id, trace);
  }

  /** FINALIZADO. Solo desde EN RUTA, y solo el acopiador. */
  async finalizar(contexto, id, trace = [], datos = {}) {
    trace.push('service');
    const { recorrido } = await this._recorrido(contexto, id, trace);

    this._exigirAcopiador(contexto, recorrido, 'finalizar');
    if (recorrido.estado !== ESTADOS.EN_RUTA) {
      throw badRequest('Solo un recorrido EN RUTA se puede finalizar.');
    }

    // Lo que quedó pendiente pasa a OMITIDA, para que el reporte cuadre.
    const pendientes = await recorridoParadaRepository.findAll({
      where: { recorridoId: recorrido.id, estado: 'PENDIENTE' },
    });
    for (const parada of pendientes) {
      await recorridoParadaRepository.update(parada.id, { estado: 'OMITIDA' });
    }

    const ahora = new Date();
    const cambios = {
      estado: ESTADOS.FINALIZADO,
      horaFin: ahora.toTimeString().slice(0, 8),
      fechaFin: ahora.toISOString().slice(0, 10),
    };
    if (datos.kilometrajeFin !== undefined && datos.kilometrajeFin !== null) {
      cambios.kilometrajeFin = Number(datos.kilometrajeFin);
    }
    if (datos.observaciones) {
      cambios.observaciones = datos.observaciones;
    }

    await this.repository.update(recorrido.id, cambios);
    return this.findById(contexto, recorrido.id, trace);
  }

  /** CANCELADO. Se puede cancelar un recorrido que no llegó a arrancar. */
  async cancelar(contexto, id, trace = [], datos = {}) {
    trace.push('service');
    const { recorrido } = await this._recorrido(contexto, id, trace);

    if (recorrido.estado === ESTADOS.FINALIZADO) {
      throw badRequest('Un recorrido finalizado no se puede cancelar.');
    }

    await this.repository.update(recorrido.id, {
      estado: ESTADOS.CANCELADO,
      observaciones: datos.observaciones || recorrido.observaciones || null,
    });
    return this.findById(contexto, recorrido.id, trace);
  }

  /**
   * Marca una parada como atendida y deja la recolección enlazada.
   * Solo tiene sentido con el recorrido en ruta.
   */
  async atenderParada(contexto, recorridoId, paradaId, datos, trace = []) {
    trace.push('service');
    const { recorrido, plantaId } = await this._recorrido(contexto, recorridoId, trace);
    this._exigirAcopiador(contexto, recorrido, 'registrar la parada');

    if (recorrido.estado !== ESTADOS.EN_RUTA) {
      throw badRequest('El recorrido no está en ruta.');
    }

    const parada = await recorridoParadaRepository.findOne({
      where: { id: paradaId, recorridoId: recorrido.id, plantaId },
    });
    if (!parada) {
      throw notFound('La parada no pertenece a este recorrido.');
    }

    const cambios = {
      estado: datos.estado === 'OMITIDA' ? 'OMITIDA' : 'ATENDIDA',
      horaLlegada: datos.horaLlegada || parada.horaLlegada || horaActual(),
      horaSalida: datos.horaSalida || horaActual(),
      litros: datos.litros === undefined || datos.litros === null ? null : Number(datos.litros),
      observaciones: datos.observaciones || null,
    };

    await recorridoParadaRepository.update(parada.id, cambios);
    return this.findById(contexto, recorrido.id, trace);
  }

  /**
   * Registra la recolección de una parada del recorrido.
   * La recolección nace ligada a la parada, así se sabe qué visita del día la
   * generó sin depender del horario.
   */
  async recolectarEnParada(contexto, recorridoId, paradaId, datos, trace = []) {
    trace.push('service');
    const { recorrido, plantaId } = await this._recorrido(contexto, recorridoId, trace);
    this._exigirAcopiador(contexto, recorrido, 'registrar la recolección');

    if (recorrido.estado !== ESTADOS.EN_RUTA) {
      throw badRequest('El recorrido no está en ruta.');
    }

    const parada = await recorridoParadaRepository.findOne({
      where: { id: paradaId, recorridoId: recorrido.id, plantaId },
    });
    if (!parada) {
      throw notFound('La parada no pertenece a este recorrido.');
    }
    if (parada.recoleccionId) {
      throw badRequest('Esta parada ya tiene una recolección registrada.');
    }

    // La recolecci�n hereda la zona del proveedor: es donde se recogi�.
    const proveedor = await proveedorRepository.findOne(
      { where: { id: parada.proveedorId, plantaId } },
      trace
    );
    const zonaId = datos.zonaId || (proveedor ? proveedor.zonaId : null);
    if (!zonaId) {
      throw badRequest(
        'El proveedor no tiene zona asignada. Indica zonaId o as�gnale una zona.'
      );
    }

    const recoleccion = await recoleccionRepository.create({
      plantaId,
      recorridoParadaId: parada.id,
      proveedorId: parada.proveedorId,
      zonaId,
      unidadId: recorrido.unidadId,
      usuarioId: contexto.userId,
      cantidad: datos.cantidad,
      fecha: datos.fecha || recorrido.fecha,
      hora: datos.hora || null,
      temperatura: datos.temperatura ?? null,
      registradoEn: datos.registradoEn || 'campo',
      sincronizado: true,
    }, trace);

    await recorridoParadaRepository.update(parada.id, {
      estado: 'ATENDIDA',
      litros: datos.cantidad,
      recoleccionId: recoleccion.id,
      horaLlegada: parada.horaLlegada || horaActual(),
      horaSalida: horaActual(),
    });

    return this.findById(contexto, recorrido.id, trace);
  }

  // --- auxiliares ---

  async _recorrido(contexto, id, trace) {
    const recorrido = await this.repository.findOne(
      this._options(contexto, { where: { id } }),
      trace
    );
    if (!recorrido) {
      throw notFound('Recorrido no encontrado.');
    }
    return { recorrido, plantaId: recorrido.plantaId };
  }

  _exigirAcopiador(contexto, recorrido, accion) {
    const esAdmin = contexto.rol === ROLES.admin;
    const esSupervisor = contexto.rol === ROLES.supervisor;
    if (esAdmin || esSupervisor) {
      return;
    }
    if (Number(recorrido.acopiadorId) !== Number(contexto.userId)) {
      throw forbidden(`Solo el acopiador del recorrido puede ${accion}.`);
    }
  }

  async _acopiador(contexto, acopiadorId, trace) {
    const id = acopiadorId || contexto.userId;
    const usuario = await usuarioRepository.findOne(
      { where: { id, plantaId: this._plantaId(contexto) } },
      trace
    );
    if (!usuario) {
      throw notFound('El acopiador no pertenece a la planta.');
    }
    return usuario;
  }

  /**
   * El ayudante es opcional. Si es personal interno se busca por id; si es
   * externo se registran sus datos y el dni es obligatorio.
   */
  async _validarAyudante(contexto, datos, trace) {
    const plantaId = this._plantaId(contexto);

    if (datos.ayudanteUsuarioId) {
      const interno = await usuarioRepository.findOne(
        { where: { id: datos.ayudanteUsuarioId, plantaId } },
        trace
      );
      if (!interno) {
        throw notFound('El ayudante interno no pertenece a la planta.');
      }
      // Con usuario interno los datos sueltos sobran.
      datos.ayudanteNombre = null;
      datos.ayudanteApellido = null;
      datos.ayudanteDni = null;
      datos.ayudanteCelular = null;
      return;
    }

    const esExterno = datos.ayudanteNombre || datos.ayudanteApellido || datos.ayudanteDni;
    if (!esExterno) {
      return;
    }

    const faltan = [];
    if (!datos.ayudanteNombre) faltan.push('nombre');
    if (!datos.ayudanteApellido) faltan.push('apellido');
    if (!datos.ayudanteDni) faltan.push('dni');
    if (faltan.length) {
      throw badRequest(
        `El ayudante externo necesita: ${faltan.join(', ')}. O usa ayudanteUsuarioId.`
      );
    }
  }

  _ordenarParadas(recorrido) {
    return {
      id: recorrido.id,
      plantaId: recorrido.plantaId,
      rutaId: recorrido.rutaId,
      unidadId: recorrido.unidadId,
      acopiadorId: recorrido.acopiadorId,
      ayudanteUsuarioId: recorrido.ayudanteUsuarioId ?? null,
      ayudanteNombre: recorrido.ayudanteNombre ?? null,
      ayudanteApellido: recorrido.ayudanteApellido ?? null,
      ayudanteDni: recorrido.ayudanteDni ?? null,
      ayudanteCelular: recorrido.ayudanteCelular ?? null,
      estado: recorrido.estado,
      fecha: recorrido.fecha,
      horaInicio: recorrido.horaInicio ?? null,
      horaFin: recorrido.horaFin ?? null,
      fechaInicio: recorrido.fechaInicio ?? null,
      fechaFin: recorrido.fechaFin ?? null,
      kilometrajeInicio: recorrido.kilometrajeInicio ?? null,
      kilometrajeFin: recorrido.kilometrajeFin ?? null,
      observaciones: recorrido.observaciones ?? null,
      ruta: recorrido.ruta
        ? { id: recorrido.ruta.id, nombre: recorrido.ruta.nombre, codigo: recorrido.ruta.codigo }
        : null,
      unidad: recorrido.unidad
        ? { id: recorrido.unidad.id, nombre: recorrido.unidad.nombre, tipo: recorrido.unidad.tipo }
        : null,
      acopiador: recorrido.acopiador
        ? {
          id: recorrido.acopiador.id,
          nombre: recorrido.acopiador.nombre,
          apellido: recorrido.acopiador.apellido,
          imagen: recorrido.acopiador.imagen ?? null,
        }
        : null,
      paradas: (recorrido.paradas || [])
        .slice()
        .sort((a, b) => a.orden - b.orden)
        .map((parada) => ({
          id: parada.id,
          recorridoId: parada.recorridoId,
          rutaParadaId: parada.rutaParadaId ?? null,
          proveedorId: parada.proveedorId,
          orden: parada.orden,
          estado: parada.estado,
          horaLlegada: parada.horaLlegada ?? null,
          horaSalida: parada.horaSalida ?? null,
          recoleccionId: parada.recoleccionId ?? null,
          litros: parada.litros ?? null,
          observaciones: parada.observaciones ?? null,
          proveedor: parada.proveedor
            ? {
              id: parada.proveedor.id,
              nombre: parada.proveedor.nombre,
              apellido: parada.proveedor.apellido,
              dni: parada.proveedor.dni,
              codigo: parada.proveedor.codigo,
              imagen: parada.proveedor.imagen ?? null,
            }
            : null,
        })),
    };
  }
}

module.exports = new RecorridoService();
module.exports.RecorridoService = RecorridoService;
module.exports.ESTADOS_RECORRIDO = ESTADOS;

