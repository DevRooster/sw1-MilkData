const BaseRepository = require('./base.repository');
const { Unidad } = require('../entities');

class UnidadRepository extends BaseRepository {
  constructor() {
    super(Unidad);
  }

  async findByNombre(nombre) {
    return this.findByField('nombre', nombre);
  }
}

module.exports = new UnidadRepository();
