const request = require('supertest');
const { DataTypes } = require('sequelize');
const app = require('../../src/app');
const { sequelize } = require('../../src/config/database.config');
const {
  Rol, Planta, Usuario, Unidad, Zona, Proveedor, Producto, Recoleccion, ControlCalidad,
} = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');
const { closeDatabase } = require('../helpers/auth');

const sufijo = `mpa${Date.now().toString(36)}`;
const CRED = 'Test123!';

let plantaA;
let plantaB;
let tokenA;
let tokenB;
let adminAId;
let rolAdminId;
let rolOperadorId;

const correos = [];
let zonaA;
let zonaB;
let unidadA;
let unidadB;
let proveedorA;
let proveedorB;
let recoleccionA;
let productoA;

beforeAll(async () => {
  // Se usan los roles reales del seed: la matriz de permisos compara por
  // nombre exacto, asi que inventar nombres romperia las aserciones de rol.
  const roles = await Rol.bulkCreate([
    { nombre: `admin-extra-${sufijo}`, descripcion: 'x', nivel: 5, activo: true },
  ]);
  rolAdminId = roles[0].id;

  const operador = await Rol.findOne({ where: { nombre: 'operador' } });
  const admin = await Rol.findOne({ where: { nombre: 'admin' } });
  rolOperadorId = operador.id;
  // El token lleva el nombre real del rol para que la matriz aplique.
  rolAdminId = admin.id;

  [plantaA, plantaB] = await Planta.bulkCreate([
    { nombre: `Planta A ${sufijo}`, codigo: `A-${sufijo}`, direccion: 'A', activo: true },
    { nombre: `Planta B ${sufijo}`, codigo: `B-${sufijo}`, direccion: 'B', activo: true },
  ]);

  const adminA = await Usuario.create({
    nombre: 'Admin', apellido: 'A',
    email: `a.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAdminId, plantaId: plantaA.id, activo: true,
  });
  const adminB = await Usuario.create({
    nombre: 'Admin', apellido: 'B',
    email: `b.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAdminId, plantaId: plantaB.id, activo: true,
  });
  const operadorA = await Usuario.create({
    nombre: 'Oper', apellido: 'A',
    email: `op.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolOperadorId, plantaId: plantaA.id, activo: true,
  });

  adminAId = adminA.id;
  correos.push(adminA.email, adminB.email, operadorA.email);

  tokenA = await securityAuthService.signToken({
    sub: adminA.id, email: adminA.email, rol: 'admin', rolId: rolAdminId, plantaId: plantaA.id,
  });
  tokenB = await securityAuthService.signToken({
    sub: adminB.id, email: adminB.email, rol: 'admin', rolId: rolAdminId, plantaId: plantaB.id,
  });

  // Datos operativos de cada planta.
  [unidadA, unidadB] = await Unidad.bulkCreate([
    { nombre: `Unidad A ${sufijo}`, tipo: 'furgon', capacidad: 100, plantaId: plantaA.id, activo: true },
    { nombre: `Unidad B ${sufijo}`, tipo: 'motocarga', capacidad: 200, plantaId: plantaB.id, activo: true },
  ]);
  [zonaA, zonaB] = await Zona.bulkCreate([
    { nombre: `Zona A ${sufijo}`, ruta: 'Ruta A', unidadId: unidadA.id, plantaId: plantaA.id, activo: true },
    { nombre: `Zona B ${sufijo}`, ruta: 'Ruta B', unidadId: unidadB.id, plantaId: plantaB.id, activo: true },
  ]);
  [proveedorA, proveedorB] = await Proveedor.bulkCreate([
    { nombre: 'Prov', apellido: 'A', dni: `A${sufijo}`, codigo: `PA-${sufijo}`, zonaId: zonaA.id, plantaId: plantaA.id, activo: true },
    { nombre: 'Prov', apellido: 'B', dni: `B${sufijo}`, codigo: `PB-${sufijo}`, zonaId: zonaB.id, plantaId: plantaB.id, activo: true },
  ]);
  recoleccionA = await Recoleccion.create({
    plantaId: plantaA.id, proveedorId: proveedorA.id, zonaId: zonaA.id, unidadId: unidadA.id,
    usuarioId: adminA.id, cantidad: 25, fecha: '2026-09-01', registradoEn: 'campo',
  });
  await ControlCalidad.create({
    plantaId: plantaA.id, recoleccionId: recoleccionA.id, usuarioId: adminA.id, grasa: 3.4, ph: 6.7,
  });
  productoA = await Producto.create({
    plantaId: plantaA.id, nombre: `Producto A ${sufijo}`, unidadMedida: 'kg', precioVenta: 20, activo: true,
  });
});

afterAll(async () => {
  await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');
  for (const tabla of [
    'control_calidad', 'recoleccion', 'producto',
    'asistencia', 'notificacion', 'proveedor', 'zona', 'unidad', 'usuario',
  ]) {
    await sequelize.query(`DELETE FROM ${tabla} WHERE planta_id IN (SELECT id FROM planta WHERE codigo LIKE :sfx)`, {
      replacements: { sfx: `%-${sufijo}` },
    });
  }
  await sequelize.query('DELETE FROM planta WHERE codigo LIKE :sfx', { replacements: { sfx: `%-${sufijo}` } });
  await Rol.destroy({ where: { nombre: `admin-extra-${sufijo}` } });
  await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');
  await closeDatabase();
});

const auth = (token) => ({ Authorization: `Bearer ${token}` });

describe('Tabla planta', () => {
  test('existe con codigo unico y direccion opcional', async () => {
    const [indices] = await sequelize.query(
      'SHOW INDEX FROM planta WHERE Column_name = ?',
      { replacements: ['codigo'] }
    );

    // Non_unique = 0 significa indice unico.
    expect(indices.length).toBeGreaterThan(0);
    for (const indice of indices) {
      expect(Number(indice.Non_unique)).toBe(0);
    }

    const columnas = await sequelize.getQueryInterface().describeTable('planta');
    expect(columnas.direccion.allowNull).toBe(true);
    expect(columnas.imagen.allowNull).toBe(true);
  });

  test('el token incluye plantaId', async () => {
    const payload = await securityAuthService.verifyToken(tokenA);

    expect(payload.plantaId).toBe(plantaA.id);
  });

  test('GET /plantas lista las plantas existentes', async () => {
    const response = await request(app).get('/plantas').set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.length).toBeGreaterThanOrEqual(2);
  });

  test('GET /plantas exige token', async () => {
    const response = await request(app).get('/plantas');
    expect(response.statusCode).toBe(401);
  });

  test('GET /plantas/codigo/:codigo encuentra una planta', async () => {
    const response = await request(app).get(`/plantas/codigo/A-${sufijo}`).set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.id).toBe(plantaA.id);
  });
});

describe('El usuario ve solo su planta', () => {
  test('GET /proveedores no lista proveedores de otra planta', async () => {
    const response = await request(app).get('/proveedores').set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    const dnis = response.body.data.items.map((p) => p.dni);
    expect(dnis).toContain(`A${sufijo}`);
    expect(dnis).not.toContain(`B${sufijo}`);
  });

  test('cada planta ve un conjunto distinto de proveedores', async () => {
    const [a, b] = await Promise.all([
      request(app).get('/proveedores').set(auth(tokenA)),
      request(app).get('/proveedores').set(auth(tokenB)),
    ]);

    expect(a.body.data.items.every((p) => p.plantaId === plantaA.id)).toBe(true);
    expect(b.body.data.items.every((p) => p.plantaId === plantaB.id)).toBe(true);
    expect(a.body.data.items).toHaveLength(1);
    expect(b.body.data.items).toHaveLength(1);
  });

  test('un id de otra planta responde 404, no 403', async () => {
    const response = await request(app).get(`/proveedores/${proveedorB.id}`).set(auth(tokenA));

    expect(response.statusCode).toBe(404);
  });

  test('PUT y DELETE sobre datos de otra planta no los tocan', async () => {
    const antes = await Proveedor.findByPk(proveedorB.id);

    const put = await request(app).put(`/proveedores/${proveedorB.id}`).set(auth(tokenA)).send({ nombre: 'Intruso' });
    const del = await request(app).delete(`/proveedores/${proveedorB.id}`).set(auth(tokenA));

    expect(put.statusCode).toBe(404);
    expect(del.statusCode).toBe(404);

    const despues = await Proveedor.findByPk(proveedorB.id);
    expect(despues).toBeTruthy();
    expect(despues.nombre).toBe(antes.nombre);
  });

  test('las unidades y zonas también están aisladas', async () => {
    const [unidades, zonas] = await Promise.all([
      request(app).get('/unidades').set(auth(tokenA)),
      request(app).get('/zonas').set(auth(tokenA)),
    ]);

    expect(unidades.body.data.items.every((u) => u.plantaId === plantaA.id)).toBe(true);
    expect(zonas.body.data.items.every((z) => z.plantaId === plantaA.id)).toBe(true);
    expect(unidades.body.data.items.some((u) => u.nombre === `Unidad B ${sufijo}`)).toBe(false);
  });
});

describe('No se puede escribir en otra planta', () => {
  test('un plantaId en el cuerpo se ignora y gana el de la sesión', async () => {
    const response = await request(app).post('/proveedores').set(auth(tokenA)).send({
      nombre: 'Intento',
      apellido: 'Invasor',
      dni: `X${sufijo}`,
      codigo: `XX-${sufijo}`,
      plantaId: plantaB.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.item.plantaId).toBe(plantaA.id);

    await Proveedor.destroy({ where: { dni: `X${sufijo}` } });
  });

  test('un plantaId en un PUT no mueve el registro a otra planta', async () => {
    const response = await request(app)
      .put(`/proveedores/${proveedorA.id}`)
      .set(auth(tokenA))
      .send({ telefono: '111', plantaId: plantaB.id });

    expect(response.statusCode).toBe(200);

    const enBase = await Proveedor.findByPk(proveedorA.id);
    expect(enBase.plantaId).toBe(plantaA.id);
  });

  test('crear con un id de planta ajeno en el cuerpo no cuela el dato', async () => {
    const response = await request(app).post('/zonas').set(auth(tokenA)).send({
      nombre: `Zona nueva ${sufijo}`,
      ruta: 'R',
      plantaId: plantaB.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.item.plantaId).toBe(plantaA.id);

    await Zona.destroy({ where: { id: response.body.data.item.id } });
  });
});

describe('Filtros no cruzan plantas', () => {
  test('filtrar recolecciones por proveedor devuelve solo las propias', async () => {
    const response = await request(app)
      .get(`/recolecciones/proveedor/${proveedorA.id}`)
      .set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].plantaId).toBe(plantaA.id);
  });

  test('filtrar por un proveedor ajeno devuelve vacío, no sus datos', async () => {
    const response = await request(app)
      .get(`/recolecciones/proveedor/${proveedorB.id}`)
      .set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items).toHaveLength(0);
  });

  test('filtrar proveedores por una zona ajena devuelve vacío', async () => {
    const response = await request(app).get(`/proveedores/zona/${zonaB.id}`).set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items).toHaveLength(0);
  });

  test('buscar proveedor por dni ajeno no lo revela', async () => {
    const response = await request(app).get(`/proveedores/dni/B${sufijo}`).set(auth(tokenA));

    expect(response.statusCode).toBe(404);
  });
});

describe('Los reportes no cruzan plantas', () => {
  test('el contraste solo usa recolecciones de la planta', async () => {
    const response = await request(app).get('/reportes/contraste').set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    const proveedores = response.body.data.items.map((i) => i.proveedorId);
    expect(proveedores).toContain(proveedorA.id);
    expect(proveedores).not.toContain(proveedorB.id);
  });

  test('el reporte por proveedor ajeno devuelve cero muestras', async () => {
    const response = await request(app)
      .get(`/reportes/calidad/proveedor/${proveedorB.id}`)
      .set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items[0].muestras).toBe(0);
  });

  test('el reporte de calidad por proveedor incluye la planta', async () => {
    const response = await request(app).get('/reportes/calidad-proveedor').set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.plantaId).toBe(plantaA.id);
    const reporte = response.body.data.items.find((i) => i.proveedorId === proveedorA.id);
    expect(reporte.muestras).toBe(1);
  });
});

describe('Imagen: null en vez de undefined', () => {
  test('usuario creado sin imagen expone imagen null', async () => {
    const usuario = await Usuario.findByPk(adminAId);

    expect(usuario.imagen).toBeNull();
  });

  test('proveedor sin imagen expone imagen null', async () => {
    const proveedor = await Proveedor.findByPk(proveedorA.id);

    expect(proveedor.imagen).toBeNull();
  });

  test('producto sin imagen expone imagen null', async () => {
    const producto = await Producto.findByPk(productoA.id);

    expect(producto.imagen).toBeNull();
  });

  test('la API devuelve imagen null en el perfil', async () => {
    const response = await request(app).get('/auth/perfil').set(auth(tokenA));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user).toHaveProperty('imagen', null);
  });

  test('la API devuelve imagen null al listar proveedores', async () => {
    const response = await request(app).get('/proveedores').set(auth(tokenA));

    for (const proveedor of response.body.data.items) {
      expect(proveedor).toHaveProperty('imagen');
      expect(proveedor.imagen).not.toBeUndefined();
    }
  });

  test('al guardar una imagen y volver a leerla conserva el valor', async () => {
    const url = 'https://cdn.milkdata.com/proveedores/a.png';

    await request(app).put(`/proveedores/${proveedorA.id}/imagen`).set(auth(tokenA)).send({ imagen: url });

    const recargado = await Proveedor.findByPk(proveedorA.id);
    expect(recargado.imagen).toBe(url);

    await Proveedor.update({ imagen: null }, { where: { id: proveedorA.id } });
  });
});

describe('Registro exige plantaId', () => {
  test('sin plantaId responde 400', async () => {
    const response = await request(app).post('/auth/register').send({
      nombre: 'X', apellido: 'Y', email: `sin.planta.${sufijo}@test.com`,
      password: CRED, rolId: 1,
    });

    expect(response.statusCode).toBe(400);
  });

  test('con plantaId ajena al admin se rechaza con 403', async () => {
    const response = await request(app).post('/auth/register').set(auth(tokenA)).send({
      nombre: 'X', apellido: 'Y', email: `ajeno.${sufijo}@test.com`,
      password: CRED, rolId: 1, plantaId: plantaB.id,
    });

    expect(response.statusCode).toBe(403);
  });

  test('un admin puede levantar una planta nueva creando su primer admin', async () => {
    // Una planta recien creada no tiene admin, asi que el admin de A puede
    // fundarla. Sin esta regla no habria forma de crear la segunda planta.
    const nueva = await Planta.create({
      nombre: `Planta C ${sufijo}`, codigo: `C-${sufijo}`, activo: true,
    });
    const email = `fundador.${sufijo}@test.com`;

    const response = await request(app).post('/auth/register').set(auth(tokenA)).send({
      nombre: 'Fundador', apellido: 'C', email, password: CRED,
      rolId: rolAdminId, plantaId: nueva.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.user.plantaId).toBe(nueva.id);
  });

  test('una planta ya operada no admite admins de otra planta', async () => {
    // A diferencia del caso anterior, B ya tiene admin: solo su propio admin
    // puede seguir registrándole usuarios.
    const response = await request(app).post('/auth/register').set(auth(tokenA)).send({
      nombre: 'Intruso', apellido: 'A', email: `intruso.${sufijo}@test.com`,
      password: CRED, rolId: rolAdminId, plantaId: plantaB.id,
    });

    expect(response.statusCode).toBe(403);
  });

  test('un admin no puede registrar usuarios de otro rol en una planta sin admin', async () => {
    const nueva = await Planta.create({
      nombre: `Planta D ${sufijo}`, codigo: `D-${sufijo}`, activo: true,
    });

    const response = await request(app).post('/auth/register').set(auth(tokenA)).send({
      nombre: 'Supervisor', apellido: 'Huerfano', email: `huerfano.${sufijo}@test.com`,
      password: CRED, rolId: rolOperadorId, plantaId: nueva.id,
    });

    expect(response.statusCode).toBe(403);
  });

  test('un admin puede registrar en su propia planta', async () => {
    const email = `propio.${sufijo}@test.com`;

    const response = await request(app).post('/auth/register').set(auth(tokenA)).send({
      nombre: 'Nuevo', apellido: 'Usuario', email, password: CRED,
      rolId: rolAdminId, plantaId: plantaA.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.user.plantaId).toBe(plantaA.id);

    const creado = await Usuario.findOne({ where: { email } });
    correos.push(email);
    await Usuario.destroy({ where: { id: creado.id } });
  });
});

describe('Login valida la planta', () => {
  test('cada admin entra con su propia planta', async () => {
    const [a, b] = await Promise.all([
      request(app).post('/auth/login').send({ email: `a.${sufijo}@test.com`, password: CRED }),
      request(app).post('/auth/login').send({ email: `b.${sufijo}@test.com`, password: CRED }),
    ]);

    const payloadA = await securityAuthService.verifyToken(a.body.data.token);
    const payloadB = await securityAuthService.verifyToken(b.body.data.token);

    expect(payloadA.plantaId).toBe(plantaA.id);
    expect(payloadB.plantaId).toBe(plantaB.id);
  });

  test('el perfil muestra la planta del usuario', async () => {
    const response = await request(app).get('/auth/perfil').set(auth(tokenB));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.plantaId).toBe(plantaB.id);
    expect(response.body.data.user.planta.codigo).toBe(`B-${sufijo}`);
  });
});
