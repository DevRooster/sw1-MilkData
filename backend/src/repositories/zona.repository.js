const BaseRepository = require('./base.repository');
const { Zona } = require('../entities');

class ZonaRepository extends BaseRepository {
  constructor() {
    super(Zona);
  }
}

module.exports = new ZonaRepository();
module.exports.ZonaRepository = ZonaRepository;
