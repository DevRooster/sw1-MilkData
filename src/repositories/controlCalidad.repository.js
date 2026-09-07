const BaseRepository = require('./base.repository');
const { ControlCalidad } = require('../entities');

class ControlCalidadRepository extends BaseRepository {
  constructor() {
    super(ControlCalidad);
  }

  async findByEntrega(entregaId) {
    return this.findByField('entregaId', entregaId);
  }

  async findByUsuario(usuarioId) {
    return this.findAllByField('usuarioId', usuarioId);
  }
}

module.exports = new ControlCalidadRepository();
