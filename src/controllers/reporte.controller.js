const reporteService = require('../services/impl/reporte.service');
const { successResponse } = require('../utils/response');

async function reporteContraste(req, res, next) {
  return executeReport(req, res, next, 'reporteContraste', reporteService.contraste.bind(reporteService));
}

async function reporteCalidad(req, res, next) {
  return executeReport(req, res, next, 'reporteCalidad', reporteService.calidad.bind(reporteService));
}

async function reporteCalidadProveedor(req, res, next) {
  return executeReport(req, res, next, 'reporteCalidadProveedor', reporteService.calidadProveedor.bind(reporteService));
}

async function executeReport(req, res, next, name, operation) {
  const trace = req.layerTrace || ['routes'];
  trace.push('controller');
  try {
    const data = await operation(trace);
    return successResponse(res, { name, items: data, layerTrace: trace }, 'Reporte generado');
  } catch (error) {
    return next(error);
  }
}

module.exports = { reporteContraste, reporteCalidad, reporteCalidadProveedor };
