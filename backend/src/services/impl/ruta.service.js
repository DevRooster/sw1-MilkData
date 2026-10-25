const { Op } = require('sequelize');
const BaseService = require('./base.service');
const rutaRepository = require('../../repositories/ruta.repository');
const rutaParadaRepository = require('../../repositories/rutaParada.repository');
const proveedorRepository = require('../../repositories/proveedor.repository');
const zonaRepository = require('../../repositories/zona.repository');
const recorridoParadaRepository = require('../../repositories/recorridoParada.repository');
const { notFound, badRequest } = require('../../utils/http-error');
const { POR_PAGINA } = require('../../config/pagination.config');

/** Orden reservado para apartar paradas y evitar chocar con (ruta, orden). */
const ORDEN_LIBRE = 100000;

/**
 * Rutas de recolección y sus paradas ordenadas.
 *
 * El sistema no inventa el orden: la planta lo mantiene, porque el acopiador
 * ya sabe recorrerla. Lo que sí hace es *sugerir* en qué ruta entra un
 * proveedor nuevo, a partir de la zona a la que pertenece.
 */
class RutaService extends BaseService {
  constructor() {
    super(rutaRepository);
  }

  findByCodigo(contexto, codigo, trace = []) {
    return this.findOneByField(contexto, 'codigo', codigo, trace);
  }

  /**
     * Filtros del listado de rutas.
     *
     * `busqueda` mira nombre y código, los dos textos que alguien teclea para
     * encontrar una ruta. No la descripción: es texto libre, y una coincidencia
     * dentro de una descripción larga devuelve rutas que no son la que se busca.
     */
    _filtros() {
      return {
        busqueda: (valor) => ({
          [Op.or]: [
            { nombre: { [Op.like]: `%${valor}%` } },
            { codigo: { [Op.like]: `%${valor}%` } },
          ],
        }),
        activa: (valor) => ({ activa: valor === 'true' || valor === true || valor === 1 }),
      };
    }

  /**
   * Lista las rutas con el conteo de paradas.
   *
   * Las paradas vienen incluidas solo para las rutas de la página: así el
   * conteo es barato y no se arrastra la tabla entera.
   */
  async list(contexto, trace = [], { pagina = 1, limite = POR_PAGINA, ...resto } = {}) {
    trace.push('service');
    const numeroPagina = Number(pagina);
    const numeroLimite = Number(limite);

    // Los filtros declarados van por `_whereDeFiltros`, no sueltos en `resto`.
    // Si se expandieran tal cual, Sequelize los ignoraría: `busqueda` sería una
    // clave suelta de las opciones y `?busqueda=zzzz` devolvería todas las
    // rutas. Eso es exactamente lo que pasaba.
    //
    // Se mezclan con cualquier `where` que venga en `resto`, igual que hace la
    // base: al mezclar, no se pisa lo que ya le hayan puesto.
    const where = { ...(resto.where || {}), ...this._whereDeFiltros(resto) };

    // `where` solo se pasa si hay algo que decir: un `where: {}` vacío cambia la
    // forma de la llamada sin cambiar el resultado.
    //
    // Cuenta también las claves de símbolo, igual que la base: un filtro que solo
    // devuelva `{ [Op.or]: [...] }` tiene cero claves de texto, y con el guard
    // solo de `Object.keys` el `where` se tiraba entero y el filtro no hacía nada.
    const diceAlgo = Object.keys(where).length + Object.getOwnPropertySymbols(where).length > 0;
    const opciones = diceAlgo ? { ...resto, where } : { ...resto };

    const { count, rows } = await this.repository.findAndCountAll({
      ...this._options(contexto, opciones),
      include: [{ association: 'paradas', attributes: ['id'] }],
      /**
       * **`distinct`, y no un `COUNT(*)` a pelo.** La inclusion de `paradas` es
       * un `hasMany`, asi que el join multiplica las filas: una ruta con dos
       * paradas sale dos veces. Contando filas salen **6 rutas donde hay 4**, y
       * el `totalPaginas` sale mal con el.
       *
       * Medido: con cuatro rutas en la planta y cinco paradas en total, la API
       * anunciaba `total: 6`.
       *
       * El `include` se queda porque el listado enseña cuantas paradas tiene
       * cada ruta, pero el conteo tiene que ser sobre la tabla padre. Con
       * `distinct` cada ruta cuenta una vez, tenga las paradas que tenga.
       *
       * **`distinct` va suelto, no dentro de `count: {...}`.** Sequelize 6 pasa
       * las opciones enteras a `Model.count`, y `count` lee `options.distinct` y
       * `options.col` del nivel superior. Un `count: { distinct: true }` se
       * ignora en silencio y la lista sigue salieron con el total inflado.
       *
       * Y `col` va **sin tabla**: `count` ya le pone delante el nombre del
       * modelo cuando hay `include`. Poner `ruta.id` a mano acaba en
       * `ruta.ruta.id`.
       */
      distinct: true,
      col: 'id',
      limit: numeroLimite,
      offset: (numeroPagina - 1) * numeroLimite,
    }, trace);

    return {
      items: rows.map((ruta) => ({
        ...ruta.toJSON(),
        paradas: (ruta.paradas || []).length,
      })),
      paginacion: this._paginacion(numeroPagina, numeroLimite, count),
    };
  }

  async findById(contexto, id, trace = []) {
    trace.push('service');
    const ruta = await this.repository.findOne(
      this._options(contexto, {
        where: { id },
        include: [
          { association: 'zonas' },
          { association: 'paradas', include: [{ association: 'proveedor' }] },
        ],
      })
    );

    if (!ruta) {
      throw notFound('Ruta no encontrada.');
    }
    return this._ordenar(ruta.toJSON());
  }

  /**
   * Ruta recomendada para el móvil: las paradas en orden, marcadas con lo que
   * ya se hizo en el recorrido indicado.
   *
   * @param {object} opciones  { recorridoId }
   */
  async recomendada(contexto, id, trace = [], opciones = {}) {
    const ruta = await this.findById(contexto, id, trace);
    const { recorridoId } = opciones;

    if (!recorridoId) {
      return { ...ruta, recorridoId: null, paradas: ruta.paradas.map((p) => ({
        ...p,
        estado: 'PENDIENTE',
        recorridoParadaId: null,
        litros: null,
        recoleccionId: null,
      })) };
    }

    const ejecutadas = await recorridoParadaRepository.findAll(
      this._options(contexto, {
        where: { recorridoId },
        include: [{ association: 'proveedor' }],
      }),
      trace
    );
    const porProveedor = new Map(ejecutadas.map((p) => [p.proveedorId, p.toJSON()]));

    return {
      ...ruta,
      recorridoId,
      paradas: ruta.paradas.map((parada) => {
        const ejecucion = porProveedor.get(parada.proveedorId);
        return {
          ...parada,
          estado: ejecucion ? ejecucion.estado : 'PENDIENTE',
          recorridoParadaId: ejecucion ? ejecucion.id : null,
          litros: ejecucion ? ejecucion.litros : null,
          recoleccionId: ejecucion ? ejecucion.recoleccionId : null,
          horaLlegada: ejecucion ? ejecucion.horaLlegada : null,
          horaSalida: ejecucion ? ejecucion.horaSalida : null,
        };
      }),
    };
  }

  _ordenar(ruta) {
    return {
      id: ruta.id,
      plantaId: ruta.plantaId,
      nombre: ruta.nombre,
      codigo: ruta.codigo,
      descripcion: ruta.descripcion ?? null,
      horaInicio: ruta.horaInicio ?? null,
      horaFin: ruta.horaFin ?? null,
      activa: ruta.activa,
      zonas: (ruta.zonas || []).map((zona) => ({ id: zona.id, nombre: zona.nombre })),
      paradas: (ruta.paradas || [])
        .slice()
        .sort((a, b) => a.orden - b.orden)
        .map((parada) => ({
          id: parada.id,
          rutaId: parada.rutaId,
          proveedorId: parada.proveedorId,
          orden: parada.orden,
          horaEstimada: parada.horaEstimada ?? null,
          activa: parada.activa,
          proveedor: parada.proveedor
            ? {
              id: parada.proveedor.id,
              nombre: parada.proveedor.nombre,
              apellido: parada.proveedor.apellido,
              dni: parada.proveedor.dni,
              codigo: parada.proveedor.codigo,
              telefono: parada.proveedor.telefono ?? null,
              direccion: parada.proveedor.direccion ?? null,
              imagen: parada.proveedor.imagen ?? null,
            }
            : null,
        })),
    };
  }

  /**
   * Agrega una parada. El proveedor pasa a esta ruta y deja de estar en la
   * anterior: un proveedor pertenece a una sola ruta activa a la vez.
   */
  async agregarParada(contexto, rutaId, datos, trace = []) {
    trace.push('service');
    const plantaId = this._plantaId(contexto);

    const ruta = await this._ruta(contexto, rutaId, trace);
    const proveedor = await this._proveedor(contexto, datos.proveedorId, trace);

    const existente = await rutaParadaRepository.findOne(
      { where: { rutaId, proveedorId: proveedor.id, plantaId } },
      trace
    );
    if (existente) {
      throw badRequest('El proveedor ya está en esta ruta.');
    }

    const otraRuta = await rutaParadaRepository.findOne(
      { where: { proveedorId: proveedor.id, plantaId } },
      trace
    );
    if (otraRuta) {
      // Sale de la ruta anterior en lugar de duplicarse.
      await rutaParadaRepository.delete(otraRuta.id);
      await this._compactar(contexto, otraRuta.rutaId, trace);
    }

    const orden = datos.orden !== undefined && datos.orden !== null && datos.orden !== ''
      ? Number(datos.orden)
      : await this._siguienteOrden(contexto, rutaId, trace);

    const parada = await rutaParadaRepository.create({
      plantaId,
      rutaId,
      proveedorId: proveedor.id,
      orden,
      horaEstimada: datos.horaEstimada || null,
      activa: true,
    }, trace);

    // El proveedor y su zona pasan a esta ruta.
    await proveedorRepository.update(proveedor.id, { rutaId });
    if (proveedor.zonaId) {
      await zonaRepository.update(proveedor.zonaId, { rutaId });
    }

    return parada;
  }

  /** Reordena varias paradas de una vez. */
  async reordenarParadas(contexto, rutaId, ordenes, trace = []) {
    trace.push('service');
    await this._ruta(contexto, rutaId, trace);

    if (!Array.isArray(ordenes) || !ordenes.length) {
      throw badRequest('Envía el nuevo orden como [{ idParada, orden }].');
    }

    const existentes = await rutaParadaRepository.findAll(
      this._options(contexto, { where: { rutaId } }),
      trace
    );
    const porId = new Map(existentes.map((p) => [p.id, p]));

    for (const entrada of ordenes) {
      if (!porId.has(Number(entrada.idParada))) {
        throw notFound('La parada indicada no pertenece a esta ruta.');
      }
    }

    // Se apartan primero porque (ruta_id, orden) es único.
    for (const parada of existentes) {
      await rutaParadaRepository.update(parada.id, { orden: ORDEN_LIBRE + parada.id });
    }
    for (const entrada of ordenes) {
      await rutaParadaRepository.update(Number(entrada.idParada), { orden: Number(entrada.orden) });
    }

    // Las paradas no incluidas en la petición quedan con el número grande de
    // apartamiento, así que hay que renumerar para cerrar la secuencia.
    await this._compactar(contexto, rutaId, trace);

    return this.findById(contexto, rutaId, trace);
  }

  async quitarParada(contexto, rutaId, paradaId, trace = []) {
    trace.push('service');
    const plantaId = this._plantaId(contexto);

    const parada = await rutaParadaRepository.findOne(
      this._options(contexto, { where: { id: paradaId, rutaId } }),
      trace
    );
    if (!parada) {
      throw notFound('La parada no existe en esta ruta.');
    }

    await rutaParadaRepository.delete(parada.id);
    await this._compactar(contexto, rutaId, trace);

    // Si el proveedor quedó sin ninguna ruta, se le quita la referencia.
    const restantes = await rutaParadaRepository.findAll(
      this._options(contexto, { where: { proveedorId: parada.proveedorId } })
    );
    if (!restantes.length) {
      const proveedor = await proveedorRepository.findOne(
        { where: { id: parada.proveedorId, plantaId } },
        trace
      );
      if (proveedor) {
        await proveedorRepository.update(proveedor.id, { rutaId: null });
      }
    }

    return { quitada: true, paradaId: Number(paradaId), rutaId: Number(rutaId) };
  }

  /**
   * Sugiere en qué ruta debería entrar un proveedor que aún no tiene.
   *
   * Prioriza las rutas que ya atienden la zona del proveedor; entre varias,
   * la que tiene menos paradas, que es la que quedó menos cargada.
   */
  async sugerirRuta(contexto, proveedorId, trace = []) {
    trace.push('service');
    const proveedor = await this._proveedor(contexto, proveedorId, trace);

    if (proveedor.rutaId) {
      const actual = await this.repository.findOne(
        this._options(contexto, { where: { id: proveedor.rutaId } }),
        trace
      );
      return {
        proveedorId: proveedor.id,
        zonaId: proveedor.zonaId ?? null,
        sugerencia: 'YA_ESTA_EN_RUTA',
        rutaId: actual.id,
        rutaNombre: actual.nombre,
        candidatas: [],
        motivo: 'El proveedor ya tiene una ruta activa.',
      };
    }

    const rutas = await this.repository.findAll(
      this._options(contexto, { where: { activa: true } }),
      trace
    );
    if (!rutas.length) {
      return {
        proveedorId: proveedor.id,
        zonaId: proveedor.zonaId ?? null,
        sugerencia: 'SIN_RUTAS',
        rutaId: null,
        rutaNombre: null,
        candidatas: [],
        motivo: 'La planta aún no tiene rutas activas.',
      };
    }

    const paradas = await rutaParadaRepository.findAll(
      this._options(contexto, { where: { rutaId: rutas.map((r) => r.id) } }),
      trace
    );

    const zonasPorRuta = new Map();
    if (proveedor.zonaId) {
      for (const ruta of rutas) {
        const zonas = await zonaRepository.findAll(
          this._options(contexto, { where: { rutaId: ruta.id } }),
          trace
        );
        if (zonas.some((zona) => zona.id === proveedor.zonaId)) {
          zonasPorRuta.set(ruta.id, zonas.length);
        }
      }
    }

    const candidatas = rutas
      .map((ruta) => ({
        rutaId: ruta.id,
        rutaNombre: ruta.nombre,
        paradas: paradas.filter((p) => p.rutaId === ruta.id).length,
        zonasDeLaMisma: zonasPorRuta.get(ruta.id) || 0,
      }))
      .sort((a, b) => {
        if (b.zonasDeLaMisma !== a.zonasDeLaMisma) {
          return b.zonasDeLaMisma - a.zonasDeLaMisma;
        }
        return a.paradas - b.paradas;
      });

    const sugerida = candidatas[0];

    return {
      proveedorId: proveedor.id,
      zonaId: proveedor.zonaId ?? null,
      sugerencia: 'SUGERIDA',
      rutaId: sugerida ? sugerida.rutaId : null,
      rutaNombre: sugerida ? sugerida.rutaNombre : null,
      candidatas,
      motivo: 'La ruta que ya atiende la zona del proveedor y tiene menos paradas.',
    };
  }

  // --- auxiliares ---

  async _ruta(contexto, rutaId, trace) {
    const ruta = await this.repository.findOne(
      this._options(contexto, { where: { id: rutaId } }),
      trace
    );
    if (!ruta) {
      throw notFound('Ruta no encontrada.');
    }
    return ruta;
  }

  async _proveedor(contexto, proveedorId, trace) {
    const proveedor = await proveedorRepository.findOne(
      this._options(contexto, { where: { id: proveedorId } }),
      trace
    );
    if (!proveedor) {
      throw notFound('Proveedor no encontrado.');
    }
    return proveedor;
  }

  async _siguienteOrden(contexto, rutaId, trace) {
    const paradas = await rutaParadaRepository.findAll(
      this._options(contexto, { where: { rutaId } }),
      trace
    );
    return paradas.reduce((mayor, parada) => Math.max(mayor, parada.orden), 0) + 1;
  }

  /** Cierra los huecos que deja un borrado en el orden. */
  async _compactar(contexto, rutaId, trace) {
    const paradas = await rutaParadaRepository.findAll(
      this._options(contexto, { where: { rutaId } }),
      trace
    );
    paradas.sort((a, b) => a.orden - b.orden);

    for (let i = 0; i < paradas.length; i += 1) {
      if (paradas[i].orden !== i + 1) {
        await rutaParadaRepository.update(paradas[i].id, { orden: i + 1 });
      }
    }
  }
}

module.exports = new RutaService();
module.exports.RutaService = RutaService;

