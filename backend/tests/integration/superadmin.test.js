/**
 * Superadmin: control sobre todas las plantas.
 *
 * El superadmin no tiene excepciones al aislamiento: opera en una sola planta
 * a la vez, la que lleva en el token. Lo que puede hacer es pedir otro token
 * para otra planta con `POST /auth/planta`.
 */
const {
  app, request, login, auth, cleanupTestUsers, closeDatabase,
  CREDENCIALES_ADMIN_HUATA,
} = require('../helpers/auth');
const { Rol, Planta, Usuario } = require('../../src/entities');
const securityAuth = require('../../src/security/auth.service');
const { crearProveedor, limpiar, Planta: PlantaEntity } = require('../helpers/rutas');

const sufijo = `sup${Date.now().toString(36)}`;
const CRED = 'SuperTest123!';

let planta;
let otra;
let tokenSuper;
let tokenAdmin;
let tokenSuperEnOtra;
let tokenAdminEnOtra;

/** Crea un usuario con el rol indicado en una planta. */
async function crearUsuario(email, rol, en) {
  return Usuario.create({
    nombre: 'Super', apellido: 'Prueba',
    email,
    password: await securityAuth.hashPassword(CRED),
    rolId: rol.id, plantaId: en.id, activo: true,
  });
}

beforeAll(async () => {
  planta = await PlantaEntity.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  otra = await Planta.create({
    nombre: `Segunda ${sufijo}`, codigo: `S-${sufijo}`, activo: true,
  });

  const rolSuper = await Rol.findOne({ where: { nombre: 'superadmin' } });
  const rolAdmin = await Rol.findOne({ where: { nombre: 'admin' } });

  // El superadmin tiene una planta propia, su "casa", y desde ahí salta a otras.
  await crearUsuario(`super.${sufijo}@test.com`, rolSuper, planta);
  await crearUsuario(`super2.${sufijo}@test.com`, rolSuper, otra);
  await crearUsuario(`admin2.${sufijo}@test.com`, rolAdmin, otra);

  tokenSuper = await login(`super.${sufijo}@test.com`, CRED);
  tokenSuperEnOtra = await login(`super2.${sufijo}@test.com`, CRED);
  tokenAdminEnOtra = await login(`admin2.${sufijo}@test.com`, CRED);
  // Esta suite compara superadmin contra admin de planta, asi que `tokenAdmin`
// debe ser de una planta y no la cuenta de arranque: `admin@milkdata.com` es el
// superadmin desde que el seed lo creo asi.
tokenAdmin = await login(CREDENCIALES_ADMIN_HUATA.email, CREDENCIALES_ADMIN_HUATA.password);
});

afterAll(async () => {
  await limpiar({ plantaId: otra.id, sufijo });
  await Planta.destroy({ where: { id: otra.id } });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

describe('GET /auth/plantas', () => {
  test('el superadmin ve todas las plantas y cuantas hay', async () => {
    const r = await request(app).get('/auth/plantas').set(auth(tokenSuper));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.alcance).toBe('TODAS');
    expect(r.body.data.total).toBeGreaterThanOrEqual(2);
    expect(r.body.data.total).toBe(r.body.data.plantas.length);

    const codigos = r.body.data.plantas.map((p) => p.codigo);
    expect(codigos).toContain(planta.codigo);
    expect(codigos).toContain(otra.codigo);
  });

  test('un admin solo ve su propia planta', async () => {
    const r = await request(app).get('/auth/plantas').set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.alcance).toBe('PROPIA');
    expect(r.body.data.total).toBe(1);
    expect(r.body.data.plantas[0].codigo).toBe(planta.codigo);
  });

  test('exige token', async () => {
    const r = await request(app).get('/auth/plantas').set(auth('no-es-un-token'));
    expect(r.statusCode).toBe(401);
  });
});

describe('POST /auth/planta', () => {
  test('el superadmin obtiene un token para otra planta', async () => {
    const r = await request(app)
      .post('/auth/planta')
      .set(auth(tokenSuper))
      .send({ plantaId: otra.id });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.token).toBeTruthy();
    expect(r.body.data.planta.id).toBe(otra.id);
    expect(r.body.data.token).not.toBe(tokenSuper);
  });

  test('admite pedirla por codigo', async () => {
    const r = await request(app)
      .post('/auth/planta')
      .set(auth(tokenSuper))
      .send({ codigo: otra.codigo });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.planta.codigo).toBe(otra.codigo);
  });

  test('con el nuevo token opera en esa planta, no en la suya', async () => {
    const cambio = await request(app)
      .post('/auth/planta')
      .set(auth(tokenSuper))
      .send({ codigo: otra.codigo });
    const nuevo = cambio.body.data.token;

    const creado = await request(app).post('/proveedores').set(auth(nuevo)).send({
      nombre: 'Del', apellido: 'Super',
      dni: `${sufijo}9`.toUpperCase().slice(0, 20),
      codigo: `SP${sufijo}`,
    });
    expect(creado.statusCode).toBe(201);
    const id = creado.body.data.item.id;

    const enOtra = await request(app).get('/proveedores').set(auth(nuevo));
    expect(enOtra.body.data.items.map((p) => p.id)).toContain(id);

    const enPropia = await request(app).get('/proveedores').set(auth(tokenSuper));
    expect(enPropia.body.data.items.map((p) => p.id)).not.toContain(id);
  });

  test('puede escribir con los mismos permisos que el admin de esa planta', async () => {
    const cambio = await request(app)
      .post('/auth/planta')
      .set(auth(tokenSuper))
      .send({ plantaId: otra.id });
    const nuevo = cambio.body.data.token;

    const creado = await request(app).post('/zonas').set(auth(nuevo)).send({
      nombre: `Zona del super ${sufijo}`,
    });
    expect(creado.statusCode).toBe(201);

    const actualizado = await request(app)
      .put(`/zonas/${creado.body.data.item.id}`)
      .set(auth(nuevo))
      .send({ horaInicio: '05:30:00' });
    expect(actualizado.statusCode).toBe(200);
  });

  test('un admin no puede cambiar de planta', async () => {
    const r = await request(app)
      .post('/auth/planta')
      .set(auth(tokenAdmin))
      .send({ plantaId: otra.id });

    expect(r.statusCode).toBe(403);
    expect(r.body.message).toMatch(/superadmin/i);
  });

  test('tampoco el admin de otra planta', async () => {
    const r = await request(app)
      .post('/auth/planta')
      .set(auth(tokenAdminEnOtra))
      .send({ plantaId: planta.id });

    expect(r.statusCode).toBe(403);
  });

  test('sin plantaId ni codigo responde 400', async () => {
    const r = await request(app).post('/auth/planta').set(auth(tokenSuper)).send({});

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/plantaId|codigo/i);
  });

  test('una planta que no existe responde 404', async () => {
    const r = await request(app)
      .post('/auth/planta')
      .set(auth(tokenSuper))
      .send({ plantaId: 99999999 });

    expect(r.statusCode).toBe(404);
  });

  test('exige token', async () => {
    const r = await request(app).post('/auth/planta').send({ plantaId: otra.id });
    expect(r.statusCode).toBe(401);
  });
});

describe('El aislamiento no se relaja para el superadmin', () => {
  test('con su token propio sigue viendo solo su planta', async () => {
    const proveedor = await crearProveedor({ planta: otra, sufijo, orden: 1 });

    const r = await request(app).get(`/proveedores/${proveedor.id}`).set(auth(tokenSuper));
    expect(r.statusCode).toBe(404);
  });

  test('un plantaId en el cuerpo se descarta: manda el del token', async () => {
    const r = await request(app).post('/proveedores').set(auth(tokenSuper)).send({
      nombre: 'Colado', apellido: 'X',
      dni: `${sufijo}8`.toUpperCase().slice(0, 20),
      codigo: `CJ${sufijo}`,
      plantaId: otra.id,
    });

    expect(r.statusCode).toBe(201);
    const id = r.body.data.item.id;

    // Quedó en la planta del token, no en la que se pidió.
    const enPropia = await request(app).get(`/proveedores/${id}`).set(auth(tokenSuper));
    expect(enPropia.statusCode).toBe(200);

    const desdeOtra = await request(app).get(`/proveedores/${id}`).set(auth(tokenSuperEnOtra));
    expect(desdeOtra.statusCode).toBe(404);
  });
});

describe('Creacion y fundacion de plantas', () => {
  test('solo el superadmin puede crear una planta', async () => {
    const conAdmin = await request(app).post('/plantas').set(auth(tokenAdmin)).send({
      nombre: `No debe existir ${sufijo}`,
      codigo: `N-${sufijo}`,
    });
    expect(conAdmin.statusCode).toBe(403);

    const conSuper = await request(app).post('/plantas').set(auth(tokenSuper)).send({
      nombre: `Si puede ${sufijo}`,
      codigo: `Y-${sufijo}`,
    });
    expect(conSuper.statusCode).toBe(201);

    await Planta.destroy({ where: { id: conSuper.body.data.item.id } });
  });

  test('el superadmin puede fundar una planta creando su primer admin', async () => {
    const nueva = await Planta.create({
      nombre: `Fundable ${sufijo}`, codigo: `F-${sufijo}`, activo: true,
    });
    const rolAdmin = await Rol.findOne({ where: { nombre: 'admin' } });

    const r = await request(app).post('/auth/register').set(auth(tokenSuper)).send({
      nombre: 'Fundador', apellido: 'F',
      email: `fundador.${sufijo}@test.com`,
      password: 'Fundador123!',
      rolId: rolAdmin.id,
      plantaId: nueva.id,
    });

    expect(r.statusCode).toBe(201);
    expect(r.body.data.user.plantaId).toBe(nueva.id);

    await Planta.destroy({ where: { id: nueva.id } });
  });

  test('un admin no puede registrar el admin de otra planta ya operada', async () => {
    const rolAdmin = await Rol.findOne({ where: { nombre: 'admin' } });

    const r = await request(app).post('/auth/register').set(auth(tokenAdmin)).send({
      nombre: 'Intruso', apellido: 'A',
      email: `intruso.${sufijo}@test.com`,
      password: 'Intruso123!',
      rolId: rolAdmin.id,
      plantaId: otra.id,
    });

    expect(r.statusCode).toBe(403);
  });
});
