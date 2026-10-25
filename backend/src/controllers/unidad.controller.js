const BaseController = require('./base.controller');
const unidadService = require('../services/impl/unidad.service');

class UnidadController extends BaseController {
  constructor() {
    super();
    this.service = unidadService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.setImagen = this.setImagen.bind(this);
    this.filterByTipo = this.filterWith('findByTipo', 'tipo');
    this.filterByNombre = this.findWith('findByNombre');
  }
}

module.exports = new UnidadController();
