const rolRepository = require('../repositories/rol.repository');
const usuarioRepository = require('../repositories/usuario.repository');
const permissionsService = require('../security/permissions.service');
const { authMiddleware } = require('./auth.middleware');
const { ROLES } = require('../security/role-permissions.config');
const { httpError, unauthorized } = require('../utils/http-error');

/**
 * Permite el bootstrap del primer admin de una planta sin token. Una vez que
 * esa planta tiene un admin, el registro exige un JWT con rol admin de la
 * misma planta.
 */
async function registerAccessMiddleware(req, res, next) {
  try {
    const plantaId = req.body ? req.body.plantaId : undefined;
    if (!plantaId) {
      return next(httpError('El campo plantaId es obligatorio.'));
    }

    const adminRole = await rolRepository.findByNombre(ROLES.admin);
    if (!adminRole) {
      return next(httpError('El rol admin no está configurado.'));
    }

    const adminDeLaPlanta = await usuarioRepository.findOne({
      where: { rolId: adminRole.id, plantaId },
    });

    // El bootstrap sin token solo sirve para la primera planta del sistema.
    const hayAdminEnElSistema = await usuarioRepository.findOne({ where: { rolId: adminRole.id } });
    if (!hayAdminEnElSistema) {
      if (Number(req.body.rolId) !== Number(adminRole.id)) {
        return next(httpError('Debe existir un administrador antes de registrar otros roles.'));
      }
      return next();
    }

    if (!req.headers.authorization) {
      return next(unauthorized());
    }

    // Se resuelve antes de `authMiddleware` porque su callback no es `async` y
    // ahí no se puede usar `await`.
    const rolSuperadmin = await rolRepository.findByNombre(ROLES.superadmin);
    const pideSuperadmin = rolSuperadmin && Number(req.body.rolId) === Number(rolSuperadmin.id);

    return authMiddleware(req, res, (error) => {
      if (error) {
        return next(error);
      }
      if (!permissionsService.isAdmin(req.user)) {
        return next(httpError('Se requiere rol admin para registrar usuarios.', 403, ['Forbidden']));
      }

      // Crear un superadmin está reservado a quien ya lo es.
      //
      // Sin este chequeo, el admin de cualquier planta podía registrar a otro
      // usuario con `rolId` de superadmin, y ese usuario nuevo pasaba a
      // administrar TODAS las plantas. Es decir, un admin de una sola planta
      // escalaba a control global: el mismo poder que por diseño solo tiene el
      // superadmin.
      if (pideSuperadmin && !permissionsService.isSuperadmin(req.user)) {
        return next(
          httpError('Solo un superadmin puede crear otro superadmin.', 403, ['Forbidden'])
        );
      }

      // El superadmin administra todas las plantas, así que puede fundar una y
      // crearle su primer admin. El resto, solo dentro de la suya.
      if (permissionsService.isSuperadmin(req.user)) {
        if (!adminDeLaPlanta && Number(req.body.rolId) !== Number(adminRole.id)) {
          return next(httpError('La planta indicada aún no tiene administrador.', 403, ['Forbidden']));
        }
        return next();
      }

      // Levantar una planta nueva requiere que alguien con rol admin la cree,
      // y ese admin puede quedarse en otra planta: por eso el registro en una
      // planta sin admin se permite siempre que se trate del primer admin.
      // Despues de eso, cada planta administra solo a los suyos.
      if (!adminDeLaPlanta) {
        if (Number(req.body.rolId) !== Number(adminRole.id)) {
          return next(httpError('La planta indicada aún no tiene administrador.', 403, ['Forbidden']));
        }
        return next();
      }

      if (String(req.user.plantaId) !== String(plantaId)) {
        return next(httpError('Solo puede registrar usuarios en su propia planta.', 403, ['Forbidden']));
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
