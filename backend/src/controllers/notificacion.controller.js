const BaseController = require('./base.controller');
const notificacionService = require('../services/impl/notificacion.service');

class NotificacionController extends BaseController {
  constructor() {
    super();
    this.service = notificacionService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.send = this.send.bind(this);
    this.filterByProveedor = this.filterWith('findByProveedor', 'proveedorId');
    this.filterByTipo = this.filterWith('findByTipo', 'tipo');
  }

  send(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.send(contexto, req.body, trace);
      return { item };
    }, 'Notificación enviada', 201);
  }
}

module.exports = new NotificacionController();
