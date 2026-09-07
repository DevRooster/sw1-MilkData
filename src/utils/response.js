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

function paginatedResponse(res, data = [], total = 0, page = 1, limit = 10, message = 'Consulta exitosa', statusCode = 200) {
  const totalPages = limit > 0 ? Math.ceil(total / limit) : 0;

  return res.status(statusCode).json({
    success: true,
    data,
    message,
    errors: [],
    pagination: {
      page,
      limit,
      total,
      totalPages,
    },
  });
}

module.exports = {
  successResponse,
  errorResponse,
  paginatedResponse,
};
