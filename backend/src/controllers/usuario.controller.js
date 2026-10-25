const BaseController = require('./base.controller');
const usuarioService = require('../services/impl/usuario.service');
const { badRequest } = require('../utils/http-error');

/**
 * CRUD de usuarios de la planta.
 *
 * Hereda listar, ver, editar y borrar de `BaseController`. Añade las tres
 * operaciones que necesitan reglas propias: cambiar rol, activar/desactivar y
 * cambiar contraseña.
 */
class UsuarioController extends BaseController {
  constructor() {
    super();
    this.service = usuarioService;
    this.bindHandlers();
  }

  /**
   * Enlaza los handlers a la instancia.
   *
   * Las rutas se registran como `controller.list`, no `controller.list.bind(...)`:
   * al guardarse la referencia suelta, `this` deja de ser el controller y
   * `this.service` y `this.handle` quedan en `undefined`. Pasa en todos los
   * controllers de este proyecto.
   */
  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.cambiarRol = this.cambiarRol.bind(this);
    this.cambiarActivo = this.cambiarActivo.bind(this);
    this.cambiarPassword = this.cambiarPassword.bind(this);
  }

  /**
   * Igual que el de `BaseController`, pero añadiendo quién pide a la petición.
   *
   * Va aquí y no en `authMiddleware` a propósito: `req.contexto` es la planta
   * sobre la que se opera, igual para todos los endpoints. Meter aquí el token
   * completo ampliaría ese contrato para todos y no lo necesita nadie más.
   */
  async handle(req, res, next, operation, message, statusCode) {
    const actor = req.user;
    const operacion = (contexto, trace) => operation({ ...contexto, actor }, trace);

    return super.handle(req, res, next, operacion, message, statusCode);
  }

  /** `PUT /usuarios/:id/rol` */
  cambiarRol(req, res, next) {
    const rolId = req.body ? req.body.rolId : undefined;
    if (rolId === undefined || rolId === null || rolId === '') {
      return next(badRequest('El campo rolId es obligatorio.'));
    }

    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await usuarioService.cambiarRol(contexto, req.params.id, rolId, trace);
      return { item };
    }, 'Rol actualizado');
  }

  /** `PUT /usuarios/:id/activo` */
  cambiarActivo(req, res, next) {
    const activo = req.body ? req.body.activo : undefined;
    if (activo === undefined) {
      return next(badRequest('El campo activo es obligatorio.'));
    }

    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await usuarioService.cambiarActivo(
        contexto,
        req.params.id,
        activo,
        trace
      );
      return { item };
    }, 'Usuario actualizado');
  }

  /** `PUT /usuarios/:id/password` */
  cambiarPassword(req, res, next) {
    const password = req.body ? req.body.password : undefined;
    if (!password) {
      return next(badRequest('El campo password es obligatorio.'));
    }

    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await usuarioService.update(
        contexto,
        req.params.id,
        { password },
        trace
      );
      return { item };
    }, 'Contraseña actualizada');
  }
}

module.exports = new UsuarioController();
module.exports.UsuarioController = UsuarioController;