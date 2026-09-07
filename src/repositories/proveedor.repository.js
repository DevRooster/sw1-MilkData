const BaseRepository = require('./base.repository');
const { Proveedor } = require('../entities');

class ProveedorRepository extends BaseRepository {
  constructor() {
    super(Proveedor);
  }

  async findByDni(dni) {
    return this.findByField('dni', dni);
  }

  async findByCodigo(codigo) {
    return this.findByField('codigo', codigo);
  }

  async findByZona(zonaId) {
    return this.findAllByField('zonaId', zonaId);
  }
}

module.exports = new ProveedorRepository();
