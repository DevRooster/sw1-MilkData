const BaseRepository = require('./base.repository');
const { Planta } = require('../entities');

class PlantaRepository extends BaseRepository {
  constructor() {
    super(Planta);
  }

  findByCodigo(codigo) {
    return this.findByField('codigo', codigo);
  }
}

module.exports = new PlantaRepository();
module.exports.PlantaRepository = PlantaRepository;
