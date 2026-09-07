const entregaRepository = require('../../repositories/entrega.repository');
const { toDTO } = require('../../dtos/entrega.dto');

class EntregaService {
  async create(data, trace = []) {
    trace.push('service');
    const record = await entregaRepository.create(data, trace);
    return toDTO(record);
  }

  async list(trace = []) {
    trace.push('service');
    const records = await entregaRepository.findAll({}, trace);
    return records.map(toDTO);
  }
}

module.exports = new EntregaService();
