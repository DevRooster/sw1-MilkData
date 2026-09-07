const asistenciaRepository = require('../../repositories/asistencia.repository');
const { toDTO } = require('../../dtos/asistencia.dto');

class AsistenciaService {
  async create(data, trace = []) {
    trace.push('service');
    const record = await asistenciaRepository.create(data, trace);
    return toDTO(record);
  }

  async list(trace = []) {
    trace.push('service');
    const records = await asistenciaRepository.findAll({}, trace);
    return records.map(toDTO);
  }
}

module.exports = new AsistenciaService();
