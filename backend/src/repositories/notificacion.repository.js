const BaseRepository = require('./base.repository');
const { Notificacion } = require('../entities');

class NotificacionRepository extends BaseRepository {
  constructor() {
    super(Notificacion);
  }
}

module.exports = new NotificacionRepository();
module.exports.NotificacionRepository = NotificacionRepository;
