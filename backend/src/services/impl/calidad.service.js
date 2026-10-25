const { Op } = require('sequelize');
const BaseService = require('./base.service');
const calidadRepository = require('../../repositories/controlCalidad.repository');
const { toDTO } = require('../../dtos/calidad.dto');

class CalidadService extends BaseService {
  constructor() {
    super(calidadRepository, toDTO);
  }

  /**
   * La recolección analizada y el laboratorio que la firmó.
   *
   * Sin la recolección un control de calidad no dice nada: es un número suelto
   * sin de qué leche es. Con ella, la fila enseña los litros y la fecha de la
   * recogida a la que pertenece.
   */
  _incluir() {
    return [{ association: 'recoleccion' }, { association: 'usuario' }];
  }

  /**
   * Filtros del listado de controles.
   *
   * `resultado` separa lo puro de lo adulterado, que es la pregunta que se le
   * hace a esta pantalla más veces que ninguna otra.
   */
  _filtros() {
    return {
      recoleccionId: (valor) => ({ recoleccionId: valor }),
      usuarioId: (valor) => ({ usuarioId: valor }),
      resultado: (valor) => ({ resultado: valor }),

      /**
       * Rango de la fecha de la recolección analizada.
       *
       * El `$` de `$recoleccion.fecha$` es parte de la sintaxis de Sequelize para
       * filtrar por una columna de una relación incluida. Escribirlo como
       * `{ recoleccion: { fecha: ... } }` no da error de sintaxis: da un **500**
       * en tiempo de ejecución, porque Sequelize se lo toma por un valor objeto
       * cualquiera y no sabe qué columna comparar. Medido contra la API, no deducido.
       */
      desde: (valor) => ({ ['$recoleccion.fecha$']: { [Op.gte]: valor } }),
      hasta: (valor) => ({ ['$recoleccion.fecha$']: { [Op.lte]: valor } }),
    };
  }

  findByRecoleccion(contexto, recoleccionId, trace = []) {
    return this.findOneByField(contexto, 'recoleccionId', recoleccionId, trace);
  }
}

module.exports = new CalidadService();
module.exports.CalidadService = CalidadService;
