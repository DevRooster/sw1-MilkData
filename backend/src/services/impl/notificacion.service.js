const BaseService = require('./base.service');
const notificacionRepository = require('../../repositories/notificacion.repository');
const { toDTO } = require('../../dtos/notificacion.dto');
const { createResilientNotificationSender } = require('../../resilience/notification.sender');

class NotificacionService extends BaseService {
  constructor(notificationSender = createResilientNotificationSender()) {
    super(notificacionRepository, toDTO);
    this.notificationSender = notificationSender;
    this.send = this.send.bind(this);
  }

  /**
   * A quién va dirigida y quién la escribió.
   *
   * Sin esto el DTO devolvía dos `null` y la lista tenía que enseñar
   * "Proveedor #1", que es justo lo que se lee para saber a quién se le avisa.
   */
  _incluir() {
    return [{ association: 'proveedor' }, { association: 'usuario' }];
  }

  /**
   * Filtros del listado de avisos.
   *
   * `leida` y `enviada` no son adornos: separan lo pendiente de mirar de lo ya
   * visto, y lo que solo se guardó de lo que llegó al proveedor. Sin ellos la
   * lista solo enseña "todos los avisos" y no sirve para trabajar.
   *
   * Los dos booleanos llegan como texto desde el query string, y hay que
   * convertirlos a `true`/`false` de verdad. Con `Boolean("false")` el filtro de
   * no leídas devolvería exactamente lo contrario de lo pedido.
   */
  _filtros() {
    return {
      tipo: (valor) => ({ tipo: valor }),
      proveedorId: (valor) => ({ proveedorId: valor }),
      usuarioId: (valor) => ({ usuarioId: valor }),
      leida: (valor) => ({ leida: valor === 'true' || valor === true || valor === 1 }),
      enviada: (valor) => ({ enviada: valor === 'true' || valor === true || valor === 1 }),
    };
  }

  findByProveedor(contexto, proveedorId, trace = []) {
    return this.listByField(contexto, 'proveedorId', proveedorId, trace);
  }

  findByTipo(contexto, tipo, trace = []) {
    return this.listByField(contexto, 'tipo', tipo, trace);
  }

  async send(contexto, data, trace = []) {
    trace.push('service');
    // Se manda **antes** de guardar: si el envío revienta, no queda un aviso
    // marcado como enviado que en realidad no llegó a nadie.
    await this.notificationSender.send(data);

    const datos = { ...data, plantaId: this._plantaId(contexto), enviada: true, fechaEnvio: new Date() };
    // `_conRelaciones` y no un `create` a pelo, por lo mismo que en el `create`
    // de la base: sin recargar, la respuesta a un envío sale con el proveedor a
    // `null` mientras que un GET de esa misma fila sí lo trae.
    return toDTO(await this._conRelaciones(await this.repository.create(datos, trace)));
  }
}

module.exports = new NotificacionService();
module.exports.NotificacionService = NotificacionService;
