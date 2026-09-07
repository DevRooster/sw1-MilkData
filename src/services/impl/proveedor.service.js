const proveedorRepository = require('../../repositories/proveedor.repository');
const { toDTO } = require('../../dtos/proveedor.dto');

class ProveedorService {
  async update(id, data, trace = []) {
    trace.push('service');
    const proveedor = await proveedorRepository.update(id, data, trace);
    return toDTO(proveedor);
  }

  async delete(id, trace = []) {
    trace.push('service');
    return proveedorRepository.delete(id, trace);
  }

  async create(data, trace = []) {
    trace.push('service');
    const proveedor = await proveedorRepository.create(data, trace);
    return toDTO(proveedor);
  }
}

module.exports = new ProveedorService();
