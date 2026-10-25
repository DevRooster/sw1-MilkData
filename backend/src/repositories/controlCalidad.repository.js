const BaseRepository = require('./base.repository');
const { ControlCalidad } = require('../entities');

class ControlCalidadRepository extends BaseRepository {
  constructor() {
    super(ControlCalidad);
  }
}

module.exports = new ControlCalidadRepository();
module.exports.ControlCalidadRepository = ControlCalidadRepository;
