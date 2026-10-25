function httpError(message, statusCode = 400, errors) {
  const error = new Error(message);
  error.statusCode = statusCode;
  if (errors) {
    error.errors = errors;
  }
  return error;
}

const notFound = () => httpError('Registro no encontrado.', 404);
const unauthorized = (message = 'Token de autorización requerido.') => httpError(message, 401, ['Unauthorized']);
const forbidden = (message = 'No tiene permisos para acceder a este recurso.') => httpError(message, 403, ['Forbidden']);
const badRequest = (message) => httpError(message, 400);

module.exports = {
  httpError,
  notFound,
  unauthorized,
  forbidden,
  badRequest,
};
