const BaseRepository = require('./base.repository');
const { Usuario } = require('../entities');

class UsuarioRepository extends BaseRepository {
  constructor() {
    super(Usuario);
  }

  async findByEmail(email) {
    return this.findByField('email', email);
  }

  async findByRol(rolId) {
    return this.findAllByField('rolId', rolId);
  }
}

module.exports = new UsuarioRepository();
