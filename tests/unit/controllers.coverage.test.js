const mockAuthService = { register: jest.fn(), login: jest.fn() };
const mockProveedorService = { create: jest.fn() };
const mockServices = {
  unidad: { list: jest.fn(), create: jest.fn() },
  zona: { list: jest.fn(), create: jest.fn() },
  entrega: { list: jest.fn(), create: jest.fn() },
  calidad: { list: jest.fn(), create: jest.fn() },
  notificacion: { list: jest.fn(), create: jest.fn(), send: jest.fn() },
  asistencia: { list: jest.fn(), create: jest.fn() },
  reporte: { contraste: jest.fn(), calidad: jest.fn(), calidadProveedor: jest.fn() },
};

jest.mock('../../src/services/impl/auth.service', () => mockAuthService);
jest.mock('../../src/services/impl/proveedor.service', () => mockProveedorService);
jest.mock('../../src/services/impl/unidad.service', () => mockServices.unidad);
jest.mock('../../src/services/impl/zona.service', () => mockServices.zona);
jest.mock('../../src/services/impl/entrega.service', () => mockServices.entrega);
jest.mock('../../src/services/impl/calidad.service', () => mockServices.calidad);
jest.mock('../../src/services/impl/notificacion.service', () => mockServices.notificacion);
jest.mock('../../src/services/impl/asistencia.service', () => mockServices.asistencia);
jest.mock('../../src/services/impl/reporte.service', () => mockServices.reporte);

const authController = require('../../src/controllers/auth.controller');
const proveedorController = require('../../src/controllers/proveedor.controller');
const controllers = [
  require('../../src/controllers/unidad.controller'),
  require('../../src/controllers/zona.controller'),
  require('../../src/controllers/entrega.controller'),
  require('../../src/controllers/calidad.controller'),
  require('../../src/controllers/notificacion.controller'),
  require('../../src/controllers/asistencia.controller'),
];
const reporteController = require('../../src/controllers/reporte.controller');

function responseMock() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

describe('Controllers', () => {
  beforeEach(() => {
    Object.values(mockServices).forEach((service) => Object.values(service).forEach((method) => method.mockResolvedValue([])));
    mockAuthService.register.mockResolvedValue({ id: 1 });
    mockAuthService.login.mockResolvedValue({ token: 'token' });
    mockProveedorService.create.mockResolvedValue({ id: 1 });
  });

  test('auth y proveedor orquestan sus services', async () => {
    await authController.register({ body: {} }, responseMock(), jest.fn());
    await authController.login({ body: {} }, responseMock(), jest.fn());
    await proveedorController.create({ body: {}, layerTrace: ['routes'] }, responseMock(), jest.fn());
    expect(mockAuthService.register).toHaveBeenCalled();
    expect(mockAuthService.login).toHaveBeenCalled();
    expect(mockProveedorService.create).toHaveBeenCalled();
  });

  test.each(controllers)('controller CRUD %p orquesta list y create', async (controller) => {
    const req = { body: {}, layerTrace: ['routes'] };
    await controller.list(req, responseMock(), jest.fn());
    await controller.create(req, responseMock(), jest.fn());
    expect(controller.service.list).toHaveBeenCalled();
    expect(controller.service.create).toHaveBeenCalled();
  });

  test('reportes orquestan sus tres operaciones', async () => {
    const req = { layerTrace: ['routes'] };
    await reporteController.reporteContraste(req, responseMock(), jest.fn());
    await reporteController.reporteCalidad(req, responseMock(), jest.fn());
    await reporteController.reporteCalidadProveedor(req, responseMock(), jest.fn());
    expect(mockServices.reporte.contraste).toHaveBeenCalled();
    expect(mockServices.reporte.calidad).toHaveBeenCalled();
    expect(mockServices.reporte.calidadProveedor).toHaveBeenCalled();
  });
});
