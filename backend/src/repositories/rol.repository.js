const BaseRepository = require('./base.repository');
const { Rol } = require('../entities');

class RolRepository extends BaseRepository {
  constructor() {
    super(Rol);
  }

  findByNombre(nombre) {
    return this.findByField('nombre', nombre);
  }
}

module.exports = new RolRepository();
module.exports.RolRepository = RolRepository;
