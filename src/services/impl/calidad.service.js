const calidadRepository = require('../../repositories/controlCalidad.repository');
const { toDTO } = require('../../dtos/calidad.dto');

class CalidadService {
  async create(data, trace = []) {
    trace.push('service');
    const record = await calidadRepository.create(data, trace);
    return toDTO(record);
  }

  async list(trace = []) {
    trace.push('service');
    const records = await calidadRepository.findAll({}, trace);
    return records.map(toDTO);
  }
}

module.exports = new CalidadService();
