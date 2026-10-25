const reporteService = require('../services/impl/reporte.service');
const { successResponse } = require('../utils/response');

async function execute(req, res, next, name, operation) {
  const trace = req.layerTrace || ['routes'];
  trace.push('controller');
  try {
    const items = await operation(req.contexto, trace);
    return successResponse(res, {
      name,
      items,
      plantaId: req.contexto ? req.contexto.plantaId : null,
      layerTrace: trace,
    }, 'Reporte generado');
  } catch (error) {
    return next(error);
  }
}

function reporteContraste(req, res, next) {
  return execute(req, res, next, 'contraste', (contexto, trace) => reporteService.contraste(contexto, trace));
}

function reporteCalidad(req, res, next) {
  return execute(req, res, next, 'calidad', (contexto, trace) => reporteService.calidad(contexto, trace, null));
}

function reporteCalidadProveedor(req, res, next) {
  return execute(req, res, next, 'calidadProveedor', (contexto, trace) => reporteService.calidadProveedor(contexto, trace));
}

function reporteCalidadPorProveedor(req, res, next) {
  return execute(req, res, next, 'calidadProveedor', (contexto, trace) =>
    reporteService.calidad(contexto, trace, req.params.proveedorId));
}

module.exports = {
  reporteContraste,
  reporteCalidad,
  reporteCalidadProveedor,
  reporteCalidadPorProveedor,
};
