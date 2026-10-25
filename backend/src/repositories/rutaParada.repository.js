const BaseRepository = require('./base.repository');
const { RutaParada } = require('../entities');

class RutaParadaRepository extends BaseRepository {
  constructor() {
    super(RutaParada);
  }
}

module.exports = new RutaParadaRepository();
module.exports.RutaParadaRepository = RutaParadaRepository;
