const BaseRepository = require('./base.repository');
const { Usuario } = require('../entities');

class UsuarioRepository extends BaseRepository {
  constructor() {
    super(Usuario);
  }
}

module.exports = new UsuarioRepository();
module.exports.UsuarioRepository = UsuarioRepository;
