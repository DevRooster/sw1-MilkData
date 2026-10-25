const BaseController = require('./base.controller');
const eventoService = require('../services/impl/evento.service');

class EventoController extends BaseController {
  constructor() {
    super();
    this.service = eventoService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.filterByNombre = this.filterWith('findByNombre', 'nombre');
  }
}

module.exports = new EventoController();