const reporteService = require('../../src/services/impl/reporte.service');

jest.mock('../../src/repositories/recoleccion.repository', () => ({ findAll: jest.fn() }));
jest.mock('../../src/repositories/controlCalidad.repository', () => ({ findAll: jest.fn() }));
jest.mock('../../src/repositories/proveedor.repository', () => ({ findAll: jest.fn() }));

const recoleccionRepository = require('../../src/repositories/recoleccion.repository');
const calidadRepository = require('../../src/repositories/controlCalidad.repository');
const proveedorRepository = require('../../src/repositories/proveedor.repository');

const CTX = { plantaId: 1 };

const RECOLECCION = (id, proveedorId, cantidad, registradoEn) => ({
  id, proveedorId, fecha: '2026-09-07', cantidad, registradoEn,
});

const CONTROL = (recoleccionId, valores) => ({ recoleccionId, ...valores });

beforeEach(() => {
  jest.clearAllMocks();
});

describe('Aislamiento en los reportes', () => {
  test('contraste consulta siempre con where', async () => {
    recoleccionRepository.findAll.mockResolvedValue([]);

    await reporteService.contraste(CTX, []);

    const [opciones] = recoleccionRepository.findAll.mock.calls[0];
    expect(opciones.where).toEqual({ plantaId: 1 });
  });

  test('calidad global consulta con where', async () => {
    calidadRepository.findAll.mockResolvedValue([]);

    await reporteService.calidad(CTX, []);

    const [opciones] = calidadRepository.findAll.mock.calls[0];
    expect(opciones.where).toEqual({ plantaId: 1 });
  });

  test('calidad por proveedor acota con proveedorId y plantaId', async () => {
    recoleccionRepository.findAll.mockResolvedValue([{ id: 7 }]);
    calidadRepository.findAll.mockResolvedValue([]);

    await reporteService.calidad(CTX, [], 3);

    const [opRec] = recoleccionRepository.findAll.mock.calls[0];
    const [opCal] = calidadRepository.findAll.mock.calls[0];
    expect(opRec.where).toEqual({ proveedorId: 3, plantaId: 1 });
    expect(opCal.where).toEqual({ recoleccionId: [7], plantaId: 1 });
  });

  test('un proveedor sin recolecciones no consulta controles', async () => {
    recoleccionRepository.findAll.mockResolvedValue([]);

    const [reporte] = await reporteService.calidad(CTX, [], 99);

    expect(calidadRepository.findAll).not.toHaveBeenCalled();
    expect(reporte.muestras).toBe(0);
  });

  test('calidadProveedor consulta las tres tablas con where', async () => {
    proveedorRepository.findAll.mockResolvedValue([]);
    recoleccionRepository.findAll.mockResolvedValue([]);
    calidadRepository.findAll.mockResolvedValue([]);

    await reporteService.calidadProveedor(CTX, []);

    for (const repository of [proveedorRepository, calidadRepository, recoleccionRepository]) {
      const [opciones] = repository.findAll.mock.calls[0];
      expect(opciones.where).toEqual({ plantaId: 1 });
    }
  });

  test('sin plantaId en el contexto lanza un error explicito', async () => {
    await expect(reporteService.contraste({})).rejects.toThrow(/plantaId/i);
    await expect(reporteService.calidad({})).rejects.toThrow(/plantaId/i);
    await expect(reporteService.calidadProveedor({})).rejects.toThrow(/plantaId/i);
  });
});

describe('ReporteService.contraste', () => {
  test('compara campo contra planta', async () => {
    recoleccionRepository.findAll.mockResolvedValue([
      RECOLECCION(1, 1, 10, 'campo'),
      RECOLECCION(2, 1, 8, 'planta'),
    ]);

    const [reporte] = await reporteService.contraste(CTX, []);

    expect(reporte).toMatchObject({
      proveedorId: 1,
      cantidadCampo: 10,
      cantidadPlanta: 8,
      diferencia: -2,
      porcentajeDiferencia: -20,
    });
  });

  test('omite el porcentaje cuando no hay registros en campo', async () => {
    recoleccionRepository.findAll.mockResolvedValue([RECOLECCION(1, 2, 5, 'planta')]);

    const [reporte] = await reporteService.contraste(CTX, []);

    expect(reporte.cantidadCampo).toBe(0);
    expect(reporte.porcentajeDiferencia).toBe(0);
  });

  test('separa los grupos por proveedor y fecha', async () => {
    recoleccionRepository.findAll.mockResolvedValue([
      RECOLECCION(1, 1, 10, 'campo'),
      RECOLECCION(2, 2, 4, 'campo'),
    ]);

    expect(await reporteService.contraste(CTX, [])).toHaveLength(2);
  });
});

describe('ReporteService.calidad', () => {
  test('promedia todos los parametros presentes', async () => {
    calidadRepository.findAll.mockResolvedValue([
      CONTROL(1, { grasa: 3, proteina: 3, lactosa: 4, densidad: 1, temperatura: 4, aguaAnadida: 0, ph: 6 }),
      CONTROL(2, { grasa: 5, proteina: 5, lactosa: 6, densidad: 1.1, temperatura: 6, aguaAnadida: 2, ph: 8 }),
    ]);

    const [reporte] = await reporteService.calidad(CTX, []);

    expect(reporte.muestras).toBe(2);
    expect(reporte.promedios).toEqual({
      grasa: 4, proteina: 4, lactosa: 5, densidad: 1.05,
      temperatura: 5, aguaAnadida: 1, ph: 7,
    });
  });

  test('los valores ausentes se excluyen en vez de contarse como cero', async () => {
    calidadRepository.findAll.mockResolvedValue([
      CONTROL(1, { grasa: 4, proteina: null }),
      CONTROL(2, { grasa: 6, proteina: undefined }),
    ]);

    const [reporte] = await reporteService.calidad(CTX, []);

    // Promediar null como 0 daria 0; lo correcto es 5 entre los dos valores de grasa.
    expect(reporte.promedios.grasa).toBe(5);
    expect(reporte.promedios.proteina).toBeNull();
  });

  test('sin datos devuelve cero muestras y null en los promedios', async () => {
    calidadRepository.findAll.mockResolvedValue([]);

    const [reporte] = await reporteService.calidad(CTX, []);

    expect(reporte.muestras).toBe(0);
    expect(reporte.promedios.grasa).toBeNull();
  });

  test('el reporte por proveedor incluye su id', async () => {
    recoleccionRepository.findAll.mockResolvedValue([{ id: 7 }]);
    calidadRepository.findAll.mockResolvedValue([
      CONTROL(7, { grasa: 4, proteina: 4, lactosa: 5, densidad: 1, temperatura: 5, aguaAnadida: 0, ph: 7 }),
    ]);

    const [reporte] = await reporteService.calidad(CTX, [], 3);

    expect(reporte.proveedorId).toBe(3);
    expect(reporte.muestras).toBe(1);
  });
});

describe('ReporteService.calidadProveedor', () => {
  test('agrupa los controles por proveedor y agrega sus datos', async () => {
    proveedorRepository.findAll.mockResolvedValue([
      { id: 1, nombre: 'Juan', apellido: 'Pérez', codigo: 'PROV-001' },
      { id: 2, nombre: 'María', apellido: 'Quispe', codigo: 'PROV-002' },
    ]);
    recoleccionRepository.findAll.mockResolvedValue([
      RECOLECCION(1, 1, 10, 'campo'),
      RECOLECCION(2, 2, 5, 'campo'),
    ]);
    calidadRepository.findAll.mockResolvedValue([
      CONTROL(1, { grasa: 3, ph: 6 }),
      CONTROL(2, { grasa: 5, ph: 8 }),
    ]);

    const reportes = await reporteService.calidadProveedor(CTX, []);

    expect(reportes).toHaveLength(2);
    const juan = reportes.find((r) => r.proveedorId === 1);
    expect(juan.muestras).toBe(1);
    expect(juan.promedios.grasa).toBe(3);
    expect(juan.proveedor.codigo).toBe('PROV-001');
  });

  test('omite proveedores sin controles', async () => {
    proveedorRepository.findAll.mockResolvedValue([{ id: 1 }, { id: 2 }]);
    recoleccionRepository.findAll.mockResolvedValue([RECOLECCION(1, 1, 10, 'campo')]);
    calidadRepository.findAll.mockResolvedValue([CONTROL(1, { grasa: 3 })]);

    const reportes = await reporteService.calidadProveedor(CTX, []);

    expect(reportes.map((r) => r.proveedorId)).toEqual([1]);
  });
});
