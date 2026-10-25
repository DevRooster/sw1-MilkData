function successResponse(res, data = null, message = 'Operación exitosa', statusCode = 200) {
  return res.status(statusCode).json({
    success: true,
    data,
    message,
    errors: [],
  });
}

function errorResponse(res, message = 'Error en la operación', statusCode = 400, errors = []) {
  return res.status(statusCode).json({
    success: false,
    data: null,
    message,
    errors: Array.isArray(errors) ? errors : [errors],
  });
}

module.exports = {
  successResponse,
  errorResponse,
};
