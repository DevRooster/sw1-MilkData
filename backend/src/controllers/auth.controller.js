const authService = require('../services/impl/auth.service');
const { successResponse } = require('../utils/response');

function withTrace(req, res, next, operation, message, statusCode) {
  const trace = req.layerTrace || ['routes'];
  trace.push('controller');
  return Promise.resolve()
    .then(() => operation(trace))
    .then((data) => successResponse(res, { ...data, layerTrace: trace }, message, statusCode))
    .catch(next);
}

function register(req, res, next) {
  return withTrace(
    req, res, next,
    (trace) => authService.register(req.body, trace).then((user) => ({ user })),
    'Usuario registrado',
    201
  );
}

function login(req, res, next) {
  return withTrace(req, res, next, (trace) => authService.login(req.body, trace), 'Login exitoso');
}

function verify(req, res, next) {
  return withTrace(req, res, next, async () => {
    const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    return { user: await authService.verifyToken(token) };
  }, 'Token válido');
}

function refresh(req, res, next) {
  return withTrace(req, res, next, async () => {
    const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    return authService.refreshToken(token);
  }, 'Token renovado');
}

function logout(req, res, next) {
  return withTrace(req, res, next, async () => authService.logout(), 'Sesión cerrada');
}

function perfil(req, res, next) {
  // Se pasa la planta del token, que es la que manda: `usuario.planta_id` es la
  // planta de origen del usuario y no cambia al cambiar de planta con
  // `POST /auth/planta`.
  return withTrace(
    req, res, next,
    (trace) => authService
      .perfil(req.user.sub, req.user.plantaId, trace)
      .then((user) => ({ user })),
    'Perfil obtenido'
  );
}

function actualizarPerfil(req, res, next) {
  return withTrace(
    req, res, next,
    (trace) => authService.actualizarPerfil(req.user.sub, req.body, trace).then((user) => ({ user })),
    'Perfil actualizado'
  );
}

/** Plantas que el usuario puede supervisar: todas si es superadmin, la suya si no. */
function plantasDisponibles(req, res, next) {
  return withTrace(
    req, res, next,
    (trace) => authService.plantasDisponibles(req.user, trace),
    'Plantas disponibles'
  );
}

/** Qué recursos puede usar este token, y con qué operaciones. */
function permisos(req, res, next) {
  return withTrace(req, res, next, (trace) => authService.permisos(req.user, trace), 'Permisos obtenidos');
}

/** Emite un token para otra planta. Solo el superadmin. */
function cambiarPlanta(req, res, next) {
  return withTrace(
    req, res, next,
    (trace) => authService.cambiarPlanta(req.body, req.user, trace),
    'Planta activa cambiada'
  );
}

module.exports = {
  register, login, verify, refresh, logout, perfil, actualizarPerfil,
  plantasDisponibles, permisos, cambiarPlanta,
};
