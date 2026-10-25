const BaseController = require('./base.controller');
const proveedorService = require('../services/impl/proveedor.service');

class ProveedorController extends BaseController {
  constructor() {
    super();
    this.service = proveedorService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.setImagen = this.setImagen.bind(this);
    this.findByDni = this.findWith('findByDni');
    this.findByCodigo = this.findWith('findByCodigo');
    this.filterByZona = this.filterWith('findByZona', 'zonaId');
  }
}

module.exports = new ProveedorController();
