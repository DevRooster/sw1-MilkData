const unidadRepository = require('../../repositories/unidad.repository');

class UnidadService {
  async update(id, data, trace = []) {
    trace.push('service');
    const record = await unidadRepository.update(id, data, trace);
    return record ? record.toJSON() : null;
  }

  async delete(id, trace = []) {
    trace.push('service');
    return unidadRepository.delete(id, trace);
  }

  async create(data, trace = []) {
    trace.push('service');
    const record = await unidadRepository.create(data, trace);
    return record.toJSON();
  }

  async list(trace = []) {
    trace.push('service');
    const records = await unidadRepository.findAll({}, trace);
    return records.map((record) => record.toJSON());
  }
}

module.exports = new UnidadService();
