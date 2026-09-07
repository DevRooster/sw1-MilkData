const BaseController = require('./base.controller');
const unidadService = require('../services/impl/unidad.service');

class UnidadController extends BaseController {
  constructor() {
    super();
    this.service = unidadService;
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }
}

module.exports = new UnidadController();
