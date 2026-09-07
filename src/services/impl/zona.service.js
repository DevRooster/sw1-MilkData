const zonaRepository = require('../../repositories/zona.repository');

class ZonaService {
  async create(data, trace = []) {
    trace.push('service');
    const record = await zonaRepository.create(data, trace);
    return record.toJSON();
  }

  async list(trace = []) {
    trace.push('service');
    const records = await zonaRepository.findAll({}, trace);
    return records.map((record) => record.toJSON());
  }
}

module.exports = new ZonaService();
