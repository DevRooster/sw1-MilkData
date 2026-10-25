const { Op } = require('sequelize');
const BaseService = require('./base.service');
const productoRepository = require('../../repositories/producto.repository');
const { toDTO } = require('../../dtos/producto.dto');

class ProductoService extends BaseService {
  constructor() {
    super(productoRepository, toDTO);
  }

  /**
   * Filtros del listado de productos.
   *
   * Se declaran aqui y no en la pantalla porque `BaseService.list` rechaza con
   * un 400 cualquier filtro que no reconozca. Un filtro dibujado en la app y no
   * declarado aqui daria error; uno declarado solo en Dart devolveria la lista
   * entera sin filtrar y la pantalla mentiria.
   *
   * `busqueda` mira nombre y descripcion: quien busca "yogurt" lo espera
   * encontrar tanto si aparece en el nombre como en la descripcion.
   */
  _filtros() {
    return {
      busqueda: (valor) => ({
        [Op.or]: [
          { nombre: { [Op.like]: `%${valor}%` } },
          { descripcion: { [Op.like]: `%${valor}%` } },
        ],
      }),
      estado: (valor) => ({ estado: valor === 'true' || valor === true || valor === 1 }),
      unidadMedida: (valor) => ({ unidadMedida: valor }),
    };
  }

  findByNombre(contexto, nombre, trace = []) {
    return this.findOneByField(contexto, 'nombre', nombre, trace);
  }
}

module.exports = new ProductoService();
module.exports.ProductoService = ProductoService;
