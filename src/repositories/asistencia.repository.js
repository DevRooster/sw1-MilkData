const BaseRepository = require('./base.repository');
const { Asistencia } = require('../entities');

class AsistenciaRepository extends BaseRepository {
  constructor() {
    super(Asistencia);
  }

  async findByProveedor(proveedorId) {
    return this.findAllByField('proveedorId', proveedorId);
  }

  async findByEvento(evento) {
    return this.findAllByField('evento', evento);
  }
}

module.exports = new AsistenciaRepository();
