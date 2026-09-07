const BaseController = require('./base.controller');
const entregaService = require('../services/impl/entrega.service');

class EntregaController extends BaseController {
  constructor() {
    super();
    this.service = entregaService;
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }
}

module.exports = new EntregaController();
