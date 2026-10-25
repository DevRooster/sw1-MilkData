const { Op } = require('sequelize');
const BaseService = require('./base.service');
const zonaRepository = require('../../repositories/zona.repository');

class ZonaService extends BaseService {
  constructor() {
    super(zonaRepository);
  }

  /**
   * Filtros del listado de zonas.
   *
   * Se declaran aqui y no en la pantalla porque `BaseController.list` rechaza
   * con un 400 cualquier filtro que no reconozca. Un filtro dibujado en la app y
   * no declarado aqui daria error; uno declarado solo en Dart devolveria la
   * lista entera sin filtrar y la pantalla mintiria.
   *
   * `busqueda` mira solo el nombre. Es el unico texto que tiene una zona, y a
   * diferencia de las rutas no hay un codigo por el que teclear.
   *
   * `rutaId` y `unidadId` son opcionales en la base (`allowNull: true`), asi que
   * `null` significa "sin ruta" o "sin unidad" y no "cualquiera": si se mandara
   * el filtro vacio se estarian mezclando las zonas sueltas con todas.
   */
  _filtros() {
    return {
      busqueda: (valor) => ({ nombre: { [Op.like]: `%${valor}%` } }),
      activo: (valor) => ({ activo: valor === 'true' || valor === true || valor === 1 }),
      rutaId: (valor) => ({ rutaId: valor }),
      unidadId: (valor) => ({ unidadId: valor }),
    };
  }

  findByNombre(contexto, nombre, trace = []) {
    return this.findOneByField(contexto, 'nombre', nombre, trace);
  }

  findByUnidad(contexto, unidadId, trace = []) {
    return this.listByField(contexto, 'unidadId', unidadId, trace);
  }
}

module.exports = new ZonaService();
module.exports.ZonaService = ZonaService;
