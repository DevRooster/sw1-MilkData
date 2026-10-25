const BaseRepository = require('./base.repository');
const { Ruta } = require('../entities');

class RutaRepository extends BaseRepository {
  constructor() {
    super(Ruta);
  }
}

module.exports = new RutaRepository();
module.exports.RutaRepository = RutaRepository;
