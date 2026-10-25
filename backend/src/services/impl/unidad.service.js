const { Op } = require('sequelize');
const BaseService = require('./base.service');
const unidadRepository = require('../../repositories/unidad.repository');

class UnidadService extends BaseService {
  constructor() {
    super(unidadRepository);
  }

  /**
   * Filtros del listado de unidades.
   *
   * `tipo` y `nombre` también existen como rutas propias
   * (`GET /unidades/tipo/{tipo}`), pero esas no se combinan con la paginación ni
   * con los demás filtros: devuelven la lista entera. Para filtrar **dentro de
   * una página** hace falta esto.
   *
   * El enum `tipo` se deja validar en la base de datos: si el servidor aceptara
   * un tipo inventado devolvería una lista vacía, que es una respuesta
   * silenciosa a una pregunta mal escrita.
   */
  _filtros() {
    return {
      tipo: (valor) => ({ tipo: valor }),
      activo: (valor) => ({ activo: valor === 'true' || valor === true || valor === 1 }),
      cerrado: (valor) => ({ cerrado: valor === 'true' || valor === true || valor === 1 }),
      busqueda: (valor) => ({
        [Op.or]: [{ nombre: { [Op.like]: `%${valor}%` } }],
      }),
    };
  }

  findByTipo(contexto, tipo, trace = []) {
    return this.listByField(contexto, 'tipo', tipo, trace);
  }

  findByNombre(contexto, nombre, trace = []) {
    return this.findOneByField(contexto, 'nombre', nombre, trace);
  }
}

module.exports = new UnidadService();
module.exports.UnidadService = UnidadService;