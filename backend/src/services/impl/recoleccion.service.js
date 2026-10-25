const { Op } = require('sequelize');
const BaseService = require('./base.service');
const recoleccionRepository = require('../../repositories/recoleccion.repository');
const { toDTO } = require('../../dtos/recoleccion.dto');

class RecoleccionService extends BaseService {
  constructor() {
    super(recoleccionRepository, toDTO);
  }

  /**
   * Filtros del listado de recolecciones.
   *
   * Se declaran aqui y no en la pantalla porque `BaseController.list` rechaza
   * con un 400 cualquier filtro que no reconozca.
   *
   * `registradoEn` y `sincronizado` no son adornos: separan lo que se anotó en
   * el campo de lo que se anotó ya en la planta, y lo que aún no se ha
   * sincronizado de lo que ya está subido. Sin ellos, la lista solo enseña
   * "todas las recogidas" y no sirve para trabajar.
   */
  /**
   * Relaciones de cada recogida: de quién es la leche, de qué zona y con qué
   * unidad se recogió, y quién la anotó.
   *
   * Sin esto el DTO devolvía cuatro `null` y la lista enseñaba "Proveedor #1".
   * Los ids sí venían; lo que faltaba eran los nombres, que es justo lo que se
   * lee en pantalla.
   */
  _incluir() {
    return [
      { association: 'proveedor' },
      { association: 'zona' },
      { association: 'unidad' },
      { association: 'usuario' },
    ];
  }

  _filtros() {
    return {
      fecha: (valor) => ({ fecha: valor }),
      proveedorId: (valor) => ({ proveedorId: valor }),
      zonaId: (valor) => ({ zonaId: valor }),
      unidadId: (valor) => ({ unidadId: valor }),
      recorridoParadaId: (valor) => ({ recorridoParadaId: valor }),
      registradoEn: (valor) => ({ registradoEn: valor }),
      sincronizado: (valor) => ({
        sincronizado: valor === 'true' || valor === true || valor === 1,
      }),
      // Rango de fechas: `desde` y `hasta` van juntos y ambos son opcionales.
      // Un día suelto no es un rango, así que no hay un filtro `fecha` de una
      // sola cara que compita con este.
      desde: (valor) => ({ fecha: { [Op.gte]: valor } }),
      hasta: (valor) => ({ fecha: { [Op.lte]: valor } }),
    };
  }

  findByProveedor(contexto, proveedorId, trace = []) {
    return this.listByField(contexto, 'proveedorId', proveedorId, trace);
  }

  findByZona(contexto, zonaId, trace = []) {
    return this.listByField(contexto, 'zonaId', zonaId, trace);
  }

  findByFecha(contexto, fecha, trace = []) {
    return this.listByField(contexto, 'fecha', fecha, trace);
  }
}

module.exports = new RecoleccionService();
module.exports.RecoleccionService = RecoleccionService;
