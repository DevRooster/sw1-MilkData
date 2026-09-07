const BaseController = require('./base.controller');
const notificacionService = require('../services/impl/notificacion.service');

class NotificacionController extends BaseController {
  constructor() {
    super();
    this.service = notificacionService;
    this.send = this.send.bind(this);
    this.create = this.create.bind(this);
    this.list = this.list.bind(this);
  }

  async send(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const notification = await this.service.send(req.body, trace);
      return require('../utils/response').successResponse(res, { item: notification, layerTrace: trace }, 'Notificación enviada', 201);
    } catch (error) {
      return next(error);
    }
  }
}

module.exports = new NotificacionController();
