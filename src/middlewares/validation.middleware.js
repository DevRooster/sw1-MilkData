const { validationResult } = require('express-validator');
const { errorResponse } = require('../utils/response');

function validationMiddleware(req, res, next) {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    return errorResponse(res, 'Validación fallida.', 400, errors.array().map((err) => err.msg));
  }

  return next();
}

module.exports = {
  validationMiddleware,
};
