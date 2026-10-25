const BaseController = require('./base.controller');
const recoleccionService = require('../services/impl/recoleccion.service');

class RecoleccionController extends BaseController {
  constructor() {
    super();
    this.service = recoleccionService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.filterByProveedor = this.filterWith('findByProveedor', 'proveedorId');
    this.filterByZona = this.filterWith('findByZona', 'zonaId');
    this.filterByFecha = this.filterWith('findByFecha', 'fecha');
  }
}

module.exports = new RecoleccionController();
