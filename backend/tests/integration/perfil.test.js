const { app, request, login, auth, closeDatabase, plantaPrincipal } = require('../helpers/auth');
const { Usuario } = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');

let token;
let planta;
let contador = 0;
const correos = [];

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();
});

afterAll(async () => {
  for (const correo of correos) {
    await Usuario.destroy({ where: { email: correo } });
  }
  await closeDatabase();
});

/** Usuario descartable dentro de la planta principal. */
async function crearTemporal(rolNombre = 'operador') {
  const { Rol } = require('../../src/entities');
  const rol = await Rol.findOne({ where: { nombre: rolNombre } });
  contador += 1;
  const correo = `pf${contador}.${Date.now().toString(36)}@test.com`;
  const usuario = await Usuario.create({
    nombre: 'Perfil', apellido: 'Temporal', email: correo,
    password: await securityAuthService.hashPassword('Test123!'),
    rolId: rol.id, plantaId: planta.id, activo: true,
  });
  correos.push(correo);

  return securityAuthService.signToken({
    sub: usuario.id, email: usuario.email, rol: rolNombre,
    rolId: rol.id, plantaId: planta.id,
  });
}

describe('GET /auth/perfil', () => {
  test('devuelve el perfil con rol y planta, sin password', async () => {
    // La cuenta de arranque es el superadmin, asi que su rol debe aparecer
    // como tal. El admin de planta se cubre en la suite de superadmin.
    const response = await request(app).get('/auth/perfil').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.email).toBe('admin@milkdata.com');
    expect(response.body.data.user.rol.nombre).toBe('superadmin');
    expect(response.body.data.user.planta.codigo).toBe('HUA');
    expect(response.body.data.user).not.toHaveProperty('password');
  });

  test('expone imagen como null cuando no hay foto', async () => {
    const response = await request(app).get('/auth/perfil').set(auth(token));

    expect(response.body.data.user).toHaveProperty('imagen', null);
  });

  test('exige token', async () => {
    expect((await request(app).get('/auth/perfil')).statusCode).toBe(401);
  });
});

describe('PUT /auth/perfil', () => {
  test('actualiza nombre, apellido e imagen', async () => {
    const response = await request(app).put('/auth/perfil').set(auth(token)).send({
      nombre: 'Nombre Editado',
      apellido: 'Apellido Editado',
      imagen: 'https://cdn.milkdata.com/avatares/admin.png',
    });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.nombre).toBe('Nombre Editado');
    expect(response.body.data.user.imagen).toBe('https://cdn.milkdata.com/avatares/admin.png');
  });

  test('la imagen se puede limpiar enviando null', async () => {
    await request(app).put('/auth/perfil').set(auth(token)).send({ imagen: 'https://cdn.milkdata.com/x.png' });
    const response = await request(app).put('/auth/perfil').set(auth(token)).send({ imagen: null });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.imagen).toBeNull();
  });

  test('no cambia email, password, rol ni planta aunque se envíen', async () => {
    const antes = await require('../../src/entities').Usuario.findOne({
      where: { email: 'admin@milkdata.com' },
    });

    const response = await request(app).put('/auth/perfil').set(auth(token)).send({
      nombre: 'Intento',
      email: 'hack@evil.com',
      password: 'hack123',
      rolId: 5,
      plantaId: 999,
    });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.email).toBe('admin@milkdata.com');
    expect(response.body.data.user.rolId).toBe(antes.rolId);
    expect(response.body.data.user.plantaId).toBe(planta.id);
    expect(response.body.data.user).not.toHaveProperty('password');

    const despues = await require('../../src/entities').Usuario.findOne({
      where: { email: 'admin@milkdata.com' },
    });
    expect(despues.email).toBe('admin@milkdata.com');
    expect(despues.plantaId).toBe(planta.id);
  });

  test('un cuerpo vacío responde 400', async () => {
    const response = await request(app).put('/auth/perfil').set(auth(token)).send({});

    expect(response.statusCode).toBe(400);
    expect(response.body.message).toMatch(/campo actualizable/i);
  });

  test('nombre vacío se rechaza con 400', async () => {
    const response = await request(app).put('/auth/perfil').set(auth(token)).send({ nombre: '' });

    expect(response.statusCode).toBe(400);
  });

  test('exige token', async () => {
    expect((await request(app).put('/auth/perfil').send({ nombre: 'X' })).statusCode).toBe(401);
  });
});

describe('Perfil de otros usuarios', () => {
  test('cada usuario ve su propio perfil con su planta', async () => {
    const tokenTemporal = await crearTemporal();
    const response = await request(app).get('/auth/perfil').set(auth(tokenTemporal));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.plantaId).toBe(planta.id);
    expect(response.body.data.user.rol.nombre).toBe('operador');
  });

  test('un token de un usuario borrado responde 404', async () => {
    const tokenTemporal = await crearTemporal();
    const payload = await securityAuthService.verifyToken(tokenTemporal);
    await Usuario.destroy({ where: { id: payload.sub } });

    const response = await request(app).get('/auth/perfil').set(auth(tokenTemporal));

    expect(response.statusCode).toBe(404);
  });
});
