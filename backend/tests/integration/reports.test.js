const {
  app, request, login, auth, closeDatabase, plantaPrincipal,
} = require('../helpers/auth');
const { sequelize } = require('../../src/config/database.config');
const { Usuario, Proveedor, Unidad, Zona, Recoleccion, ControlCalidad } = require('../../src/entities');

const sufijo = `r${Date.now().toString(36)}`;
let token;
let planta;
let proveedor;
let unidad;
let zona;
let usuario;
let recolecciones = [];
let controles = [];

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();
  usuario = await Usuario.findOne({ where: { email: 'admin@milkdata.com' } });

  unidad = await Unidad.create({
    nombre: `Unidad ${sufijo}`, tipo: 'furgon', capacidad: 1000, plantaId: planta.id, activo: true,
  });
  zona = await Zona.create({
    nombre: `Zona ${sufijo}`, ruta: 'Ruta', unidadId: unidad.id, plantaId: planta.id, activo: true,
  });
  proveedor = await Proveedor.create({
    nombre: 'Reporte', apellido: 'Proveedor', dni: `R${sufijo}`,
    codigo: `R-${sufijo}`, zonaId: zona.id, plantaId: planta.id, activo: true,
  });

  recolecciones = await Recoleccion.bulkCreate([
    { plantaId: planta.id, proveedorId: proveedor.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: usuario.id, cantidad: 10, fecha: '2026-09-07', registradoEn: 'campo' },
    { plantaId: planta.id, proveedorId: proveedor.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: usuario.id, cantidad: 8, fecha: '2026-09-07', registradoEn: 'planta' },
  ]);

  controles = await ControlCalidad.bulkCreate([
    { plantaId: planta.id, recoleccionId: recolecciones[0].id, usuarioId: usuario.id, grasa: 3, proteina: 3, lactosa: 4, densidad: 1, temperatura: 4, aguaAnadida: 0, ph: 6 },
    { plantaId: planta.id, recoleccionId: recolecciones[1].id, usuarioId: usuario.id, grasa: 5, proteina: 5, lactosa: 6, densidad: 1.1, temperatura: 6, aguaAnadida: 2, ph: 8 },
  ]);
});

afterAll(async () => {
  await ControlCalidad.destroy({ where: { id: controles.map((c) => c.id) } });
  await Recoleccion.destroy({ where: { id: recolecciones.map((r) => r.id) } });
  await Proveedor.destroy({ where: { id: proveedor.id } });
  await Zona.destroy({ where: { id: zona.id } });
  await Unidad.destroy({ where: { id: unidad.id } });
  await closeDatabase();
});

describe('GET /reportes/contraste', () => {
  test('compara campo contra planta y devuelve el trace de capas', async () => {
    const response = await request(app).get('/reportes/contraste').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.plantaId).toBe(planta.id);

    const reporte = response.body.data.items.find((item) => item.proveedorId === proveedor.id);
    expect(reporte).toMatchObject({
      cantidadCampo: 10,
      cantidadPlanta: 8,
      diferencia: -2,
      porcentajeDiferencia: -20,
    });
    expect(response.body.data.layerTrace).toEqual(['routes', 'controller', 'service', 'repository']);
  });
});

describe('GET /reportes/calidad', () => {
  test('devuelve promedios no nulos con datos reales', async () => {
    const response = await request(app).get('/reportes/calidad').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items[0].muestras).toBeGreaterThan(0);
    expect(response.body.data.items[0].promedios.grasa).not.toBeNull();
  });
});

describe('GET /reportes/calidad-proveedor', () => {
  test('agrupa los promedios por proveedor y agrega sus datos', async () => {
    const response = await request(app).get('/reportes/calidad-proveedor').set(auth(token));

    expect(response.statusCode).toBe(200);
    const reporte = response.body.data.items.find((item) => item.proveedorId === proveedor.id);
    expect(reporte.muestras).toBe(2);
    expect(reporte.promedios.grasa).toBe(4);
    expect(reporte.proveedor.codigo).toBe(`R-${sufijo}`);
  });
});

describe('GET /reportes/calidad/proveedor/:proveedorId', () => {
  test('acota el reporte al proveedor solicitado', async () => {
    const response = await request(app)
      .get(`/reportes/calidad/proveedor/${proveedor.id}`)
      .set(auth(token));

    expect(response.statusCode).toBe(200);
    const [reporte] = response.body.data.items;

    expect(reporte.proveedorId).toBe(proveedor.id);
    expect(reporte.muestras).toBe(2);
    expect(reporte.promedios).toEqual({
      grasa: 4,
      proteina: 4,
      lactosa: 5,
      densidad: 1.05,
      temperatura: 5,
      aguaAnadida: 1,
      ph: 7,
    });
  });

  test('un proveedor sin controles devuelve cero muestras', async () => {
    const otro = await Proveedor.create({
      nombre: 'Sin', apellido: 'Controles', dni: `S${sufijo}`,
      codigo: `S-${sufijo}`, plantaId: planta.id, activo: true,
    });

    const response = await request(app)
      .get(`/reportes/calidad/proveedor/${otro.id}`)
      .set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items[0].muestras).toBe(0);

    await Proveedor.destroy({ where: { id: otro.id } });
  });
});
