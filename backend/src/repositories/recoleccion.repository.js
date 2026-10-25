const BaseRepository = require('./base.repository');
const { Recoleccion } = require('../entities');

class RecoleccionRepository extends BaseRepository {
  constructor() {
    super(Recoleccion);
  }
}

module.exports = new RecoleccionRepository();
module.exports.RecoleccionRepository = RecoleccionRepository;
