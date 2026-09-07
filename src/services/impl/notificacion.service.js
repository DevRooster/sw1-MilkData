const notificacionRepository = require('../../repositories/notificacion.repository');
const { toDTO } = require('../../dtos/notificacion.dto');
const { createResilientNotificationSender } = require('../../resilience/notification.sender');

class NotificacionService {
  constructor(notificationSender = createResilientNotificationSender()) {
    this.notificationSender = notificationSender;
    this.send = this.send.bind(this);
  }

  async create(data, trace = []) {
    trace.push('service');
    const record = await notificacionRepository.create(data, trace);
    return toDTO(record);
  }

  async list(trace = []) {
    trace.push('service');
    const records = await notificacionRepository.findAll({}, trace);
    return records.map(toDTO);
  }

  async send(data, trace = []) {
    trace.push('service');
    await this.notificationSender.send(data);
    const record = await notificacionRepository.create({
      ...data,
      enviada: true,
      fechaEnvio: new Date(),
    }, trace);
    return toDTO(record);
  }
}

module.exports = new NotificacionService();
module.exports.NotificacionService = NotificacionService;
