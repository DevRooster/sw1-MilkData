const BaseService = require('./base.service');
const plantaRepository = require('../../repositories/planta.repository');

/**
 * Gestión de plantas. No se aísla por planta: es la tabla raíz, y solo un
 * administrador global debería poder listar o crear plantas.
 */
class PlantaService extends BaseService {
  constructor() {
    super(plantaRepository, undefined, { aislarPorPlanta: false });
  }

  findByCodigo(codigo, trace = []) {
    return this.findOneByField({}, 'codigo', codigo, trace);
  }
}

module.exports = new PlantaService();
module.exports.PlantaService = PlantaService;
