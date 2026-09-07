const BaseController = require('./base.controller');
const asistenciaService = require('../services/impl/asistencia.service');

class AsistenciaController extends BaseController {
  constructor() {
    super();
    this.service = asistenciaService;
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }
}

module.exports = new AsistenciaController();
