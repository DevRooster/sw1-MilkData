const { Rol, Usuario } = require('../entities');
const { authMiddleware } = require('./auth.middleware');
const permissionsService = require('../security/permissions.service');
const { errorResponse } = require('../utils/response');

async function registerAccessMiddleware(req, res, next) {
  try {
    const adminRole = await Rol.findOne({ where: { nombre: 'admin' } });
    const adminExists = adminRole
      ? await Usuario.findOne({ where: { rolId: adminRole.id } })
      : false;

    if (!adminExists) {
      if (Number(req.body.rolId) !== Number(adminRole && adminRole.id)) {
        return errorResponse(res, 'Debe existir un administrador antes de registrar otros roles.', 400, ['Bootstrap de administrador requerido']);
      }
      return next();
    }

    if (!req.headers.authorization) {
      return errorResponse(res, 'Token de autorización requerido.', 401, ['Unauthorized']);
    }

    return authMiddleware(req, res, () => {
      if (!permissionsService.canAccess(req.user, adminRole.id)) {
        return errorResponse(res, 'Se requiere rol admin para registrar usuarios.', 403, ['Forbidden']);
      }
      return next();
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  registerAccessMiddleware,
};
