const BaseRepository = require('../../src/repositories/base.repository');

function modelMock(registro = {}) {
  const instancia = {
    ...registro,
    update: jest.fn().mockResolvedValue(registro),
    destroy: jest.fn(),
  };
  return {
    instancia,
    findAll: jest.fn().mockResolvedValue([instancia]),
    findByPk: jest.fn().mockResolvedValue(instancia),
    findOne: jest.fn().mockResolvedValue(instancia),
    create: jest.fn().mockResolvedValue(instancia),
  };
}

describe('BaseRepository', () => {
  test('findAll propaga las opciones y registra la capa', async () => {
    const model = modelMock({ id: 1 });
    const repository = new BaseRepository(model);
    const trace = [];

    await repository.findAll({ where: { plantaId: 3 } }, trace);

    expect(model.findAll).toHaveBeenCalledWith({ where: { plantaId: 3 } });
    expect(trace).toEqual(['repository']);
  });

  test('findById consulta por primary key', async () => {
    const model = modelMock({ id: 7 });
    const repository = new BaseRepository(model);

    await expect(repository.findById(7)).resolves.toMatchObject({ id: 7 });
    expect(model.findByPk).toHaveBeenCalledWith(7, {});
  });

  test('findOne propaga el where', async () => {
    const model = modelMock({ id: 1 });
    const repository = new BaseRepository(model);
    const trace = [];

    await repository.findOne({ where: { id: 1, plantaId: 2 } }, trace);

    expect(model.findOne).toHaveBeenCalledWith({ where: { id: 1, plantaId: 2 } });
    expect(trace).toEqual(['repository']);
  });

  test('create delega en el modelo', async () => {
    const model = modelMock({ id: 1 });
    const repository = new BaseRepository(model);
    const trace = [];

    await repository.create({ nombre: 'x' }, trace);

    expect(model.create).toHaveBeenCalledWith({ nombre: 'x' });
    expect(trace).toEqual(['repository']);
  });

  test('findByField respeta el where existente del llamador', async () => {
    const model = modelMock();
    const repository = new BaseRepository(model);

    await repository.findByField('dni', '123', { where: { plantaId: 9 } });

    expect(model.findOne).toHaveBeenCalledWith({ where: { plantaId: 9, dni: '123' } });
  });

  test('findAllByField respeta el where existente del llamador', async () => {
    const model = modelMock();
    const repository = new BaseRepository(model);

    await repository.findAllByField('proveedorId', 5, { where: { plantaId: 9 } });

    expect(model.findAll).toHaveBeenCalledWith({ where: { plantaId: 9, proveedorId: 5 } });
  });

  test('findByField y findAllByField funcionan sin where previo', async () => {
    const model = modelMock();
    const repository = new BaseRepository(model);

    await repository.findByField('dni', '123');
    await repository.findAllByField('proveedorId', 5);

    expect(model.findOne).toHaveBeenCalledWith({ where: { dni: '123' } });
    expect(model.findAll).toHaveBeenCalledWith({ where: { proveedorId: 5 } });
  });
});
