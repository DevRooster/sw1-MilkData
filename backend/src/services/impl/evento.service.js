const { Op } = require('sequelize');
const BaseService = require('./base.service');
const eventoRepository = require('../../repositories/evento.repository');
const { toDTO } = require('../../dtos/evento.dto');

/**
 * Eventos a los que se puede asistir.
 *
 * **Sin relaciones que traer.** Un evento es un nombre, un día, un sitio y una
 * nota: no tiene a nadie asociado, así que `_incluir()` está vacío y el servicio
 * no pide joins que no sirven para nada.
 */
class EventoService extends BaseService {
  constructor() {
    super(eventoRepository, toDTO);
  }

  _incluir() {
    return [];
  }

  /**
   * Filtros del listado de eventos.
   *
   * `nombre` y `busqueda` van **por fragmento**, porque es el problema que motivó
   * esto: quien recuerda "reunion" tiene que encontrar "Reunión de ruta del Norte".
   * El `LIKE` de MySQL con la collation del proyecto no distingue mayúsculas ni
   * acentos, así que el filtro se comporta igual que el servidor; si divergieran,
   * la lista se quedaría corta y parecería que el evento no existe.
   *
   * `desde` y `hasta` van sobre la fecha y se **acumulan**: `?desde=X&hasta=Y`
   * tiene que ser un rango, no el último que se procesó.
   */
  _filtros() {
    return {
      nombre: (valor) => ({ nombre: { [Op.like]: `%${valor}%` } }),
      busqueda: (valor) => ({
        [Op.or]: [
          { nombre: { [Op.like]: `%${valor}%` } },
          { lugar: { [Op.like]: `%${valor}%` } },
          { descripcion: { [Op.like]: `%${valor}%` } },
        ],
      }),
      lugar: (valor) => ({ lugar: { [Op.like]: `%${valor}%` } }),
      fecha: (valor) => ({ fecha: valor }),
      desde: (valor) => ({ fecha: { [Op.gte]: valor } }),
      hasta: (valor) => ({ fecha: { [Op.lte]: valor } }),
    };
  }

  findByNombre(contexto, nombre, trace = []) {
    return this.listByField(contexto, 'nombre', nombre, trace);
  }
}

module.exports = new EventoService();
module.exports.EventoService = EventoService;