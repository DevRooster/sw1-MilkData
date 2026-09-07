const proveedorService = require('../services/impl/proveedor.service');
const { successResponse } = require('../utils/response');

async function update(req, res, next) {
  const trace = req.layerTrace || [];
  trace.push('controller');
  try {
    const proveedor = await proveedorService.update(req.params.id, req.body, trace);
    if (!proveedor) {
      const error = new Error('Registro no encontrado.');
      error.statusCode = 404;
      throw error;
    }
    return successResponse(res, { proveedor, layerTrace: trace }, 'Proveedor actualizado');
  } catch (error) {
    return next(error);
  }
}

async function remove(req, res, next) {
  const trace = req.layerTrace || [];
  trace.push('controller');
  try {
    const deleted = await proveedorService.delete(req.params.id, trace);
    if (!deleted) {
      const error = new Error('Registro no encontrado.');
      error.statusCode = 404;
      throw error;
    }
    return successResponse(res, { deleted: true, layerTrace: trace }, 'Proveedor eliminado');
  } catch (error) {
    return next(error);
  }
}

async function create(req, res, next) {
  const trace = req.layerTrace || [];
  trace.push('controller');

  try {
    const proveedor = await proveedorService.create(req.body, trace);
    return successResponse(res, { proveedor, layerTrace: trace }, 'Proveedor creado', 201);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  create,
  update,
  remove,
};
