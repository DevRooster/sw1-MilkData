const BaseController = require('./base.controller');
const productoService = require('../services/impl/producto.service');

class ProductoController extends BaseController {
  constructor() {
    super();
    this.service = productoService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.setImagen = this.setImagen.bind(this);
    this.findByNombre = this.findWith('findByNombre');
  }
}

module.exports = new ProductoController();
