const request = require('supertest');
const app = require('../../app');
const { sequelize } = require('../../src/config/database.config');
const { Usuario, Proveedor, Unidad, Zona, Entrega, ControlCalidad } = require('../../src/entities');

const suffix = Date.now().toString();
let proveedor;
let unidad;
let zona;
let usuario;
let entregas = [];
let controles = [];

beforeAll(async () => {
  usuario = await Usuario.findOne({ where: { email: 'admin@milkdata.com' } });
  unidad = await Unidad.create({ nombre: `Reporte Unidad ${suffix}`, tipo: 'furgon', capacidad: 1000, cerrado: false, activo: true });
  zona = await Zona.create({ nombre: `Reporte Zona ${suffix}`, ruta: 'Ruta Reporte', unidadId: unidad.id, activo: true });
  proveedor = await Proveedor.create({ nombre: 'Reporte', apellido: 'Proveedor', dni: `R${suffix}`, codigo: `REPORTE-${suffix}`, zonaId: zona.id, activo: true });

  entregas = await Promise.all([
    Entrega.create({ proveedorId: proveedor.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: usuario.id, cantidad: 10, fecha: '2026-09-07', registradoEn: 'campo', sincronizado: false }),
    Entrega.create({ proveedorId: proveedor.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: usuario.id, cantidad: 8, fecha: '2026-09-07', registradoEn: 'planta', sincronizado: false }),
  ]);

  controles = await Promise.all([
    ControlCalidad.create({ entregaId: entregas[0].id, usuarioId: usuario.id, grasa: 3, proteina: 3, lactosa: 4, densidad: 1, temperatura: 4, aguaAnadida: 0, ph: 6 }),
    ControlCalidad.create({ entregaId: entregas[1].id, usuarioId: usuario.id, grasa: 5, proteina: 5, lactosa: 6, densidad: 1.1, temperatura: 6, aguaAnadida: 2, ph: 8 }),
  ]);
});

afterAll(async () => {
  await ControlCalidad.destroy({ where: { id: controles.map((control) => control.id) } });
  await Entrega.destroy({ where: { id: entregas.map((entrega) => entrega.id) } });
  await Proveedor.destroy({ where: { id: proveedor.id } });
  await Zona.destroy({ where: { id: zona.id } });
  await Unidad.destroy({ where: { id: unidad.id } });
  await sequelize.close();
});

describe('Reportes con datos reales', () => {
  test('contraste campo versus planta calcula diferencia y porcentaje', async () => {
    const response = await request(app).get('/reportes/contraste');
    const report = response.body.data.items.find((item) => item.proveedorId === proveedor.id);

    expect(response.statusCode).toBe(200);
    expect(report.cantidadCampo).toBe(10);
    expect(report.cantidadPlanta).toBe(8);
    expect(report.diferencia).toBe(-2);
    expect(report.porcentajeDiferencia).toBe(-20);
    expect(response.body.data.layerTrace).toEqual(['routes', 'controller', 'service', 'repository']);
  });

  test('calidad calcula promedios de todos los parámetros', async () => {
    const response = await request(app).get('/reportes/calidad');
    const report = response.body.data.items[0];

    expect(response.statusCode).toBe(200);
    expect(report.muestras).toBe(2);
    expect(report.promedios.grasa).toBe(4);
    expect(report.promedios.proteina).toBe(4);
    expect(report.promedios.lactosa).toBe(5);
    expect(report.promedios.densidad).toBeCloseTo(1.05);
    expect(report.promedios.temperatura).toBe(5);
    expect(report.promedios.aguaAnadida).toBe(1);
    expect(report.promedios.ph).toBe(7);
  });

  test('calidad por proveedor calcula sus promedios', async () => {
    const response = await request(app).get('/reportes/calidad-proveedor');
    const report = response.body.data.items.find((item) => item.proveedorId === proveedor.id);

    expect(response.statusCode).toBe(200);
    expect(report.muestras).toBe(2);
    expect(report.promedios.grasa).toBe(4);
    expect(report.promedios.ph).toBe(7);
  });
});
