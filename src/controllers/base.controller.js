const { successResponse } = require('../utils/response');

class BaseController {
  async update(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const record = await this.service.update(req.params.id, req.body, trace);
      if (!record) {
        const error = new Error('Registro no encontrado.');
        error.statusCode = 404;
        throw error;
      }
      return successResponse(res, { item: record, layerTrace: trace }, 'Registro actualizado');
    } catch (error) {
      return next(error);
    }
  }

  async delete(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const deleted = await this.service.delete(req.params.id, trace);
      if (!deleted) {
        const error = new Error('Registro no encontrado.');
        error.statusCode = 404;
        throw error;
      }
      return successResponse(res, { deleted: true, layerTrace: trace }, 'Registro eliminado');
    } catch (error) {
      return next(error);
    }
  }

  async create(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const record = await this.service.create(req.body, trace);
      return successResponse(res, { item: record, layerTrace: trace }, 'Registro creado', 201);
    } catch (error) {
      return next(error);
    }
  }

  async list(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const records = await this.service.list(trace);
      return successResponse(res, { items: records, layerTrace: trace }, 'Consulta exitosa');
    } catch (error) {
      return next(error);
    }
  }
}

module.exports = BaseController;
