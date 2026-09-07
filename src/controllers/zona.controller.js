const BaseController = require('./base.controller');
const zonaService = require('../services/impl/zona.service');

class ZonaController extends BaseController {
  constructor() {
    super();
    this.service = zonaService;
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }
}

module.exports = new ZonaController();
