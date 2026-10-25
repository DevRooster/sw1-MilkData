const { verifyToken } = require('../security/auth.service');
const permissionsService = require('../security/permissions.service');
const { unauthorized } = require('../utils/http-error');

/**
 * Verifica el JWT y arma `req.contexto` con la planta del usuario.
 *
 * El token lleva `plantaId`. Ese es el único origen del aislamiento: el
 * servicio lo usa para filtrar, e ignora cualquier `plantaId` que llegue en
 * el cuerpo de la petición.
 *
 * El superadmin no tiene excepciones a esa regla: opera en una sola planta a
 * la vez, la que lleva en el token. Lo que puede hacer es pedir otro token
 * para otra planta con `POST /auth/planta`.
 */
async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
      throw unauthorized();
    }

    const payload = await verifyToken(token);
    if (!payload.plantaId) {
      throw unauthorized('El token no tiene planta asignada.');
    }

    req.user = payload;
    req.contexto = {
      userId: payload.sub,
      email: payload.email,
      rol: payload.rol,
      rolId: payload.rolId,
      plantaId: payload.plantaId,
      superadmin: permissionsService.isSuperadmin(payload),
    };

    return next();
  } catch (error) {
    return next(error.statusCode ? error : unauthorized(error.message));
  }
}

module.exports = {
  authMiddleware,
};
