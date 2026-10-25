const BaseController = require('./base.controller');
const calidadService = require('../services/impl/calidad.service');

class CalidadController extends BaseController {
  constructor() {
    super();
    this.service = calidadService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.filterByRecoleccion = this.findWith('findByRecoleccion');
  }
}

module.exports = new CalidadController();
