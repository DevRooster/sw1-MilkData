const BaseRepository = require('./base.repository');
const { Zona } = require('../entities');

class ZonaRepository extends BaseRepository {
  constructor() {
    super(Zona);
  }

  async findByNombre(nombre) {
    return this.findByField('nombre', nombre);
  }

  async findByUnidad(unidadId) {
    return this.findAllByField('unidadId', unidadId);
  }
}

module.exports = new ZonaRepository();
