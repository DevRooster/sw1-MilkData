const BaseController = require('./base.controller');
const calidadService = require('../services/impl/calidad.service');

class CalidadController extends BaseController {
  constructor() {
    super();
    this.service = calidadService;
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }
}

module.exports = new CalidadController();
