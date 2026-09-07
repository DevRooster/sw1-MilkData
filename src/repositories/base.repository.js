class BaseRepository {
  constructor(model) {
    this.model = model;
  }

  async findAll(options = {}, trace = []) {
    trace.push('repository');
    return this.model.findAll(options);
  }

  async findById(id, options = {}) {
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
    const record = await this.findById(id);
    if (!record) {
      return null;
    }
    return record.update(data);
  }

  async delete(id, trace = []) {
    trace.push('repository');
    const record = await this.findById(id);
    if (!record) {
      return null;
    }
    await record.destroy();
    return true;
  }

  async findByField(field, value, options = {}) {
    return this.model.findOne({
      ...options,
      where: {
        [field]: value,
      },
    });
  }

  async findAllByField(field, value, options = {}) {
    return this.model.findAll({
      ...options,
      where: {
        [field]: value,
      },
    });
  }
}

module.exports = BaseRepository;
