const BaseRepository = require('./base.repository');
const { Asistencia } = require('../entities');

class AsistenciaRepository extends BaseRepository {
  constructor() {
    super(Asistencia);
  }
}

module.exports = new AsistenciaRepository();
module.exports.AsistenciaRepository = AsistenciaRepository;
