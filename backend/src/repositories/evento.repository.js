const BaseRepository = require('./base.repository');
const { Evento } = require('../entities');

class EventoRepository extends BaseRepository {
  constructor() {
    super(Evento);
  }
}

module.exports = new EventoRepository();
module.exports.EventoRepository = EventoRepository;