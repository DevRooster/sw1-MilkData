const { errorResponse } = require('../utils/response');

function errorMiddleware(err, req, res, next) {
  const statusCode = err && err.statusCode ? err.statusCode : 500;
  const message = err && err.message ? err.message : 'Error interno del servidor.';
  const errors = err && err.errors ? err.errors : [message];

  return errorResponse(res, message, statusCode, errors);
}

module.exports = {
  errorMiddleware,
};
