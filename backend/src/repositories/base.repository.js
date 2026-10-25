class BaseRepository {
  constructor(model) {
    this.model = model;
  }

  async findAll(options = {}, trace = []) {
    trace.push('repository');
    return this.model.findAll(options);
  }

  /**
   * Registros y total de una consulta, para listados paginados.
   *
   * Sale de una sola llamada para que el `total` y las filas siempre
   * correspondan a la misma foto de la tabla.
   */
  async findAndCountAll(options = {}, trace = []) {
    trace.push('repository');
    return this.model.findAndCountAll(options);
  }

  async findById(id, options = {}, trace = []) {
    trace.push('repository');
    return this.model.findByPk(id, options);
  }

  async findOne(options = {}, trace = []) {
    trace.push('repository');
    return this.model.findOne(options);
  }

  async create(data, trace = []) {
    trace.push('repository');
    return this.model.create(data);
  }

  async update(id, data, trace = []) {
    trace.push('repository');
    const record = await this.model.findByPk(id);
    if (!record) {
      return null;
    }
    return record.update(data);
  }

  async delete(id, trace = []) {
    trace.push('repository');
    const record = await this.model.findByPk(id);
    if (!record) {
      return null;
    }
    await record.destroy();
    return true;
  }

  async findByField(field, value, options = {}) {
    return this.model.findOne({
      ...options,
      where: { ...options.where, [field]: value },
    });
  }

  async findAllByField(field, value, options = {}) {
    return this.model.findAll({
      ...options,
      where: { ...options.where, [field]: value },
    });
  }
}

module.exports = BaseRepository;
