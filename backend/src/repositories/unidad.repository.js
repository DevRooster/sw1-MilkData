const BaseRepository = require('./base.repository');
const { Unidad } = require('../entities');

class UnidadRepository extends BaseRepository {
  constructor() {
    super(Unidad);
  }
}

module.exports = new UnidadRepository();
module.exports.UnidadRepository = UnidadRepository;
