const { Op } = require('sequelize');
const BaseService = require('./base.service');
const asistenciaRepository = require('../../repositories/asistencia.repository');
const { toDTO } = require('../../dtos/asistencia.dto');

class AsistenciaService extends BaseService {
  constructor() {
    super(asistenciaRepository, toDTO);
  }

  /**
   * A quién se le anotó y quién lo anotó.
   *
   * Sin esto el DTO devolvía dos `null` y la lista tenía que enseñar
   * "Proveedor #1", que es justo lo que se lee para saber a quién se le registró
   * la asistencia.
   */
  _incluir() {
    return [
      { association: 'proveedor' },
      { association: 'usuario' },
      // El evento del catálogo. Va con `LEFT JOIN` implícito porque `eventoId` es
      // nullable: las asistencias viejas no lo tienen y sin esto se quedarían
      // fuera de la lista al pedir el evento.
      { association: 'eventoRelacion' },
    ];
  }

  /**
   * Filtros del listado de asistencias.
   *
   * `evento` busca **por fragmento**: es texto libre, no un catálogo cerrado, así que
   * quien recuerda que fue "reunión de ruta" y no "Reunión de ruta" —con o sin
   * tilde, todo en mayúsculas— tiene que encontrarlo. Coincidencia exacta sobre
   * un campo de texto libre solo funciona si te sabes la cadena exacta, y en un
   * `VARCHAR(150)` que escribe quien quiera eso no se sabe nunca.
   *
   * `registradoPor` separa lo escaneado con QR de lo apuntado a mano: es la
   * diferencia entre un registro fiable y una anotación de memoria.
   */
  _filtros() {
    return {
      evento: (valor) => ({ evento: { [Op.like]: `%${valor}%` } }),
      /**
       * Filtra por el **evento del catálogo**, no por el texto libre.
       *
       * Se llama también `evento` y hay dos cosas distintas con ese nombre a
       * propósito de no equivocarse: el filtro de arriba busca dentro del texto
       * que escribió cada quien —donde está "reunion" sin tilde— y este busca el
       * evento que se eligió de una lista, que es lo que quiere quien ya sabe qué
       * evento está mirando.
       */
      eventoId: (valor) => ({ eventoId: valor }),
      registradoPor: (valor) => ({ registradoPor: valor }),
      proveedorId: (valor) => ({ proveedorId: valor }),
      usuarioId: (valor) => ({ usuarioId: valor }),
      fecha: (valor) => ({ fecha: valor }),
      /** Rango de la fecha de la asistencia. */
      desde: (valor) => ({ fecha: { [Op.gte]: valor } }),
      hasta: (valor) => ({ fecha: { [Op.lte]: valor } }),
    };
  }

  findByProveedor(contexto, proveedorId, trace = []) {
    return this.listByField(contexto, 'proveedorId', proveedorId, trace);
  }

  findByEvento(contexto, evento, trace = []) {
    return this.listByField(contexto, 'evento', evento, trace);
  }
}

module.exports = new AsistenciaService();
module.exports.AsistenciaService = AsistenciaService;
