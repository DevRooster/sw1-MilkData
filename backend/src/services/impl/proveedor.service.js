const { Op } = require('sequelize');
const BaseService = require('./base.service');
const proveedorRepository = require('../../repositories/proveedor.repository');
const { toDTO } = require('../../dtos/proveedor.dto');
const { badRequest } = require('../../utils/http-error');

class ProveedorService extends BaseService {
  constructor() {
    super(proveedorRepository, toDTO);
  }

  /**
   * Filtros del listado de proveedores.
   *
   * Se declaran aqui y no en la pantalla porque `BaseController.list` rechaza
   * con un 400 cualquier filtro que no reconozca. Un filtro dibujado en la app y
   * no declarado aqui daria error; uno declarado solo en Dart devolveria la
   * lista entera sin filtrar y la pantalla mintiria.
   *
   * `busqueda` mira cuatro campos porque son los cuatro por los que se localiza
   * a un proveedor en una planta lechera: por nombre, por el segundo nombre, por
   * el DNI cuando se tiene el documento delante, y por el codigo cuando se
   * trabaja con una hoja de rutas.
   */
  _filtros() {
    return {
      busqueda: (valor) => ({
        [Op.or]: [
          { nombre: { [Op.like]: `%${valor}%` } },
          { apellido: { [Op.like]: `%${valor}%` } },
          { dni: { [Op.like]: `%${valor}%` } },
          { codigo: { [Op.like]: `%${valor}%` } },
        ],
      }),
      activo: (valor) => ({ activo: valor === 'true' || valor === true || valor === 1 }),
      zonaId: (valor) => ({ zonaId: valor }),
    };
  }

  findByDni(contexto, dni, trace = []) {
    return this.findOneByField(contexto, 'dni', dni, trace);
  }

  findByCodigo(contexto, codigo, trace = []) {
    return this.findOneByField(contexto, 'codigo', codigo, trace);
  }

  findByZona(contexto, zonaId, trace = []) {
    return this.listByField(contexto, 'zonaId', zonaId, trace);
  }

  /**
   * Saca `rutaId` del cuerpo de una alta o una edición, y se niega si viene.
   *
   * En qué ruta está un proveedor se dice en dos sitios a la vez: la columna
   * `proveedor.ruta_id` y la fila en `ruta_parada` (con su orden y su hora
   * estimada). `ruta.service` mantiene los dos de acuerdo cuando se usan sus
   * endpoints, pero eso no ocurre si la columna se escribe por su cuenta:
   * aceptarla dejaba proveedores que decían estar en una ruta y cuya parada
   * seguía en otra. Medido, no supuesto: un `PUT /proveedores/6` con
   * `rutaId: 1` dejó `ruta_id = 1` y la parada en la ruta 3.
   *
   * La misma regla que impide cambiar el rol de un usuario por
   * `PUT /usuarios/{id}`: una columna desnormalizada tiene un solo dueño, y aquí
   * es `POST /rutas/{id}/paradas` y `DELETE /rutas/{id}/paradas/{paradaId}`,
   * que son los que saben mover la parada y su orden.
   *
   * Se aplica igual en el alta: un proveedor nuevo nace sin ruta, y se coloca
   * en una al añadirlo a su parada. Aceptarlo aquí dejaba la inconsistencia
   * desde el minuto uno.
   */
  _sinRuta(datos) {
    if (!datos || datos.rutaId === undefined) {
      return datos || {};
    }

    throw badRequest(
      'La ruta no se cambia con este endpoint. Usa POST o DELETE en /rutas/{id}/paradas.'
    );
  }

  async create(contexto, data, trace = []) {
    const limpio = this._sinRuta(data);

    if (limpio.codigo === undefined || limpio.codigo === null || limpio.codigo === '') {
      limpio.codigo = await this._siguienteCodigo(contexto, trace);
    }

    return super.create(contexto, limpio, trace);
  }

  /**
   * El siguiente código libre de proveedor: `PROV-006`, `PROV-007`...
   *
   * **Se genera aquí y no en la app por dos razones.** `proveedor.codigo` es
   * `unique`, y la unicidad es una cosa del servidor: la app solo ve una página
   * de la lista y no puede saber qué códigos existen. Y si lo generara el
   * cliente, dos altas simultáneas pedirían el mismo número y una fallaría.
   *
   * El formato sale de los que ya hay, y si no hay ninguno se arranca en `001`.
   * Un hueco no se reutiliza a propósito: reutilizarlo haría que el código
   * `PROV-006` hubiera sido dos proveedores distintos según cuándo se mirara,
   * y en una hoja de rutas eso se paga.
   */
  async _siguienteCodigo(contexto, trace) {
    const plantaId = this._plantaId(contexto);

    const existentes = await proveedorRepository.findAll(
      { attributes: ['codigo'], where: { plantaId } },
      trace
    );

    const mayor = existentes.reduce((maximo, fila) => {
      const numeros = /^PROV-(\d+)$/.exec(fila.codigo || '');
      if (!numeros) {
        return maximo;
      }
      const numero = Number(numeros[1]);
      return numero > maximo ? numero : maximo;
    }, 0);

    return `PROV-${String(mayor + 1).padStart(3, '0')}`;
  }

  async update(contexto, id, data, trace = []) {
    return super.update(contexto, id, this._sinRuta(data), trace);
  }
}

module.exports = new ProveedorService();
module.exports.ProveedorService = ProveedorService;