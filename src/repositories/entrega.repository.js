const BaseRepository = require('./base.repository');
const { Entrega } = require('../entities');

class EntregaRepository extends BaseRepository {
  constructor() {
    super(Entrega);
  }

  async findByFecha(fecha) {
    return this.findAllByField('fecha', fecha);
  }

  async findByProveedor(proveedorId) {
    return this.findAllByField('proveedorId', proveedorId);
  }
}

module.exports = new EntregaRepository();
