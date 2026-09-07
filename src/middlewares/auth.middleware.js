const { verifyToken } = require('../security/auth.service');
const { errorResponse } = require('../utils/response');

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return errorResponse(res, 'Token de autorización requerido.', 401, ['Unauthorized']);
    }

    const payload = await verifyToken(token);
    req.user = payload;
    return next();
  } catch (error) {
    const statusCode = error && error.statusCode ? error.statusCode : 401;
    return errorResponse(res, error.message || 'Token inválido.', statusCode, [error.message || 'Token inválido.']);
  }
}

module.exports = {
  authMiddleware,
};
