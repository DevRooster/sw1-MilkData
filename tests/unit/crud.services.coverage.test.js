const mockRepositories = {
  unidad: { findAll: jest.fn(), create: jest.fn() },
  zona: { findAll: jest.fn(), create: jest.fn() },
  entrega: { findAll: jest.fn(), create: jest.fn() },
  calidad: { findAll: jest.fn(), create: jest.fn() },
  notificacion: { findAll: jest.fn(), create: jest.fn() },
  asistencia: { findAll: jest.fn(), create: jest.fn() },
};

jest.mock('../../src/repositories/unidad.repository', () => mockRepositories.unidad);
jest.mock('../../src/repositories/zona.repository', () => mockRepositories.zona);
jest.mock('../../src/repositories/entrega.repository', () => mockRepositories.entrega);
jest.mock('../../src/repositories/controlCalidad.repository', () => mockRepositories.calidad);
jest.mock('../../src/repositories/notificacion.repository', () => mockRepositories.notificacion);
jest.mock('../../src/repositories/asistencia.repository', () => mockRepositories.asistencia);

const services = [
  ['unidad', require('../../src/services/impl/unidad.service')],
  ['zona', require('../../src/services/impl/zona.service')],
  ['entrega', require('../../src/services/impl/entrega.service')],
  ['calidad', require('../../src/services/impl/calidad.service')],
  ['notificacion', require('../../src/services/impl/notificacion.service')],
  ['asistencia', require('../../src/services/impl/asistencia.service')],
];

function record(values = {}) {
  return { ...values, toJSON: () => ({ ...values }) };
}

describe('Services CRUD', () => {
  beforeEach(() => {
    Object.values(mockRepositories).forEach((repository) => {
      repository.findAll.mockResolvedValue([record({ id: 1 })]);
      repository.create.mockResolvedValue(record({ id: 1 }));
    });
  });

  test.each(services)('%s lista y crea mediante repository', async (name, service) => {
    const trace = [];
    const listed = await service.list(trace);
    const created = await service.create({ nombre: 'test' }, trace);
    expect(listed).toHaveLength(1);
    expect(created.id).toBe(1);
    expect(trace).toContain('service');
    expect(mockRepositories[name].findAll).toHaveBeenCalled();
    expect(mockRepositories[name].create).toHaveBeenCalled();
  });
});
