const BaseController = require('./base.controller');
const asistenciaService = require('../services/impl/asistencia.service');

class AsistenciaController extends BaseController {
  constructor() {
    super();
    this.service = asistenciaService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.filterByProveedor = this.filterWith('findByProveedor', 'proveedorId');
    this.filterByEvento = this.filterWith('findByEvento', 'evento');
  }
}

module.exports = new AsistenciaController();
