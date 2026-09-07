const BaseRepository = require('./base.repository');
const { Notificacion } = require('../entities');

class NotificacionRepository extends BaseRepository {
  constructor() {
    super(Notificacion);
  }

  async findByProveedor(proveedorId) {
    return this.findAllByField('proveedorId', proveedorId);
  }

  async findByTipo(tipo) {
    return this.findAllByField('tipo', tipo);
  }
}

module.exports = new NotificacionRepository();
