const permissionsService = require('../security/permissions.service');
const { forbidden } = require('../utils/http-error');

/**
 * Middleware de autorizacion por recurso y operacion.
 * Debe instalarse siempre despues de `authMiddleware`.
 *
 * @param {string} recurso   Recurso protegido (ver role-permissions.config).
 * @param {'read'|'write'} operacion
 */
function authorize(recurso, operacion) {
  return function authorizeMiddleware(req, res, next) {
    if (!permissionsService.can(req.user, recurso, operacion)) {
      return next(forbidden());
    }
    return next();
  };
}

module.exports = {
  authorize,
};
