const BaseController = require('./base.controller');
const zonaService = require('../services/impl/zona.service');

class ZonaController extends BaseController {
  constructor() {
    super();
    this.service = zonaService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.filterByNombre = this.findWith('findByNombre');
    this.filterByUnidad = this.filterWith('findByUnidad', 'unidadId');
  }
}

module.exports = new ZonaController();
