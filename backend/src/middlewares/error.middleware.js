const { errorResponse } = require('../utils/response');
const logger = require('../utils/logger');

function errorMiddleware(err, req, res, next) {
  const name = err && err.name;

  let statusCode = 500;
  let message = 'Error interno del servidor.';
  let errors = null;

  // Un 500 sin registrar es un fallo que no se puede diagnosticar: el cliente ve
  // "error interno" y en los logs no hay nada. Los 4xx sí son parte del contrato
  // y no necesitan registrarse.
  if (statusCode === 500 && !(err && err.statusCode && err.statusCode < 500)) {
    logger.error(
      `Error no controlado en ${req.method} ${req.originalUrl}: ${err && err.message}`,
      err
    );
  }

  if (name === 'SequelizeForeignKeyConstraintError' || name === 'SequelizeUniqueConstraintError' || name === 'SequelizeValidationError') {
    statusCode = 400;
  }

  if (name === 'SequelizeForeignKeyConstraintError') {
    message = 'La referencia relacionada no es válida.';
    errors = ['Referencia inválida'];
  } else if (name === 'SequelizeUniqueConstraintError') {
    message = 'Ya existe un registro con ese valor único.';
    errors = ['Valor duplicado'];
  } else if (name === 'SequelizeValidationError') {
    message = 'Los datos enviados no son válidos.';
    errors = (err.errors || []).map((item) => item.message);
  } else if (err && err.statusCode) {
    statusCode = err.statusCode;
    message = err.message;
    errors = err.errors;
  }

  return errorResponse(res, message, statusCode, errors || [message]);
}

module.exports = {
  errorMiddleware,
};
