const { errorResponse } = require('../utils/response');
const { ForeignKeyConstraintError } = require('sequelize');

function errorMiddleware(err, req, res, next) {
  const isForeignKeyError = err instanceof ForeignKeyConstraintError || err?.name === 'SequelizeForeignKeyConstraintError';
  const statusCode = isForeignKeyError ? 400 : (err && err.statusCode ? err.statusCode : 500);
  const message = isForeignKeyError ? 'La referencia relacionada no es válida.' : (err && err.message ? err.message : 'Error interno del servidor.');
  const errors = isForeignKeyError ? ['Referencia inválida'] : (err && err.errors ? err.errors : [message]);

  return errorResponse(res, message, statusCode, errors);
}

module.exports = {
  errorMiddleware,
};
