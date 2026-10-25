const BaseRepository = require('./base.repository');
const { RecorridoParada } = require('../entities');

class RecorridoParadaRepository extends BaseRepository {
  constructor() {
    super(RecorridoParada);
  }
}

module.exports = new RecorridoParadaRepository();
module.exports.RecorridoParadaRepository = RecorridoParadaRepository;
