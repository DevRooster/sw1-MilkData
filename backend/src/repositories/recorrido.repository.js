const BaseRepository = require('./base.repository');
const { Recorrido } = require('../entities');

class RecorridoRepository extends BaseRepository {
  constructor() {
    super(Recorrido);
  }
}

module.exports = new RecorridoRepository();
module.exports.RecorridoRepository = RecorridoRepository;
