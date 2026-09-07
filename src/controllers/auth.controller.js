const authService = require('../services/impl/auth.service');
const { successResponse } = require('../utils/response');

async function register(req, res, next) {
  const trace = req.layerTrace || ['routes'];
  trace.push('controller');
  try {
    const user = await authService.register(req.body, trace);
    return successResponse(res, { user, layerTrace: trace }, 'Usuario registrado', 201);
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
  const trace = req.layerTrace || ['routes'];
  trace.push('controller');
  try {
    const result = await authService.login(req.body, trace);
    return successResponse(res, { ...result, layerTrace: trace }, 'Login exitoso');
  } catch (error) {
    return next(error);
  }
}

async function verify(req, res, next) {
  try {
    const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    const payload = await authService.verifyToken(token);
    return successResponse(res, { user: payload }, 'Token válido');
  } catch (error) {
    return next(error);
  }
}

module.exports = { register, login, verify };
