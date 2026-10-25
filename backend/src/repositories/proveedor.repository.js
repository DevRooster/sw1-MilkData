const BaseRepository = require('./base.repository');
const { Proveedor } = require('../entities');

class ProveedorRepository extends BaseRepository {
  constructor() {
    super(Proveedor);
  }
}

module.exports = new ProveedorRepository();
module.exports.ProveedorRepository = ProveedorRepository;
