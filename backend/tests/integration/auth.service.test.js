const {
  app, request, login, auth, setAdminPassword, closeDatabase, plantaPrincipal,
  tokenForRole, cleanupTestUsers,
  CREDENCIALES_INICIO, CREDENCIALES_ADMIN_HUATA,
} = require('../helpers/auth');
const authService = require('../../src/services/impl/auth.service');
const securityAuthService = require('../../src/security/auth.service');
const { Usuario, Rol } = require('../../src/entities');

let token;
let planta;

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();
});

afterAll(closeDatabase);

describe('AuthService.register', () => {
  test('rechaza emails ya registrados con 409', async () => {
    await expect(authService.register({
      nombre: 'Duplicado', apellido: 'Test', email: 'admin@milkdata.com',
      password: 'Test123!', rolId: 1, plantaId: planta.id,
    })).rejects.toMatchObject({ statusCode: 409 });
  });

  test('rechaza roles inexistentes con 400', async () => {
    await expect(authService.register({
      nombre: 'Ana', apellido: 'Test', email: `sin.rol.${Date.now()}@test.com`,
      password: 'Test123!', rolId: 999999, plantaId: planta.id,
    })).rejects.toMatchObject({ statusCode: 400, message: 'El rol especificado no existe.' });
  });

  test('rechaza plantas inexistentes con 400', async () => {
    await expect(authService.register({
      nombre: 'Ana', apellido: 'Test', email: `sin.planta.${Date.now()}@test.com`,
      password: 'Test123!', rolId: 1, plantaId: 999999,
    })).rejects.toMatchObject({ statusCode: 400, message: 'La planta especificada no existe.' });
  });

  test('crea el usuario con el password cifrado y sin exponerlo', async () => {
    const email = `nuevo.${Date.now()}@test.com`;
    const usuario = await authService.register({
      nombre: 'Nuevo', apellido: 'Usuario', email, password: 'Test123!',
      rolId: 1, plantaId: planta.id,
    });

    expect(usuario.email).toBe(email);
    expect(usuario.password).toBeUndefined();
    expect(usuario.plantaId).toBe(planta.id);

    const enBase = await Usuario.findOne({ where: { email } });
    expect(enBase.password).toMatch(/^\$2[aby]\$/);
    expect(enBase.password).not.toBe('Test123!');

    await Usuario.destroy({ where: { id: enBase.id } });
  });
});

describe('AuthService.login', () => {
  test('acepta la contraseña vigente del admin', async () => {
    const nueva = 'ClaveRotada@2026';
    await setAdminPassword(nueva);

    const { token: emitido } = await authService.login({
      email: CREDENCIALES_INICIO.email, password: nueva,
    });
    expect(emitido).toBeTruthy();

    await setAdminPassword(CREDENCIALES_INICIO.password);
  });

  test('rechaza usuarios inactivos con 401', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'operador' } });
    const email = `inactivo.${Date.now()}@test.com`;
    const usuario = await Usuario.create({
      nombre: 'Inactivo', apellido: 'Test', email,
      password: await securityAuthService.hashPassword('Test123!'),
      rolId: rol.id, plantaId: planta.id, activo: false,
    });

    await expect(authService.login({ email, password: 'Test123!' })).rejects.toMatchObject({ statusCode: 401 });
    await Usuario.destroy({ where: { id: usuario.id } });
  });

  test('un usuario sin planta no puede existir: la columna es NOT NULL', async () => {
    // El aislamiento depende de que todo usuario tenga planta, así que el
    // modelo y la base lo impiden por diseño en vez de dejarlo nullable.
    await expect(Usuario.create({
      nombre: 'Huerfano', apellido: 'Test', email: `huerfano.${Date.now()}@test.com`,
      password: 'x', rolId: 1, plantaId: null, activo: true,
    })).rejects.toThrow(/plantaId/);
  });

  test('actualiza ultimoAcceso tras un login exitoso', async () => {
    const antes = await Usuario.findOne({ where: { email: 'admin@milkdata.com' } });
    const previo = antes.ultimoAcceso;

    await new Promise((resolve) => setTimeout(resolve, 1100));
    await authService.login({
      email: CREDENCIALES_INICIO.email,
      password: CREDENCIALES_INICIO.password,
    });

    const despues = await Usuario.findOne({ where: { id: antes.id } });
    expect(String(despues.ultimoAcceso)).not.toBe(String(previo));
  });
});

describe('AuthService.refreshToken y logout', () => {
  test('refresh conserva sub, email, rol y planta', async () => {
    const payload = await authService.verifyToken(token);
    const { token: nuevo } = await authService.refreshToken(token);
    const verificado = await authService.verifyToken(nuevo);

    expect(verificado.sub).toBe(payload.sub);
    expect(verificado.rol).toBe(payload.rol);
    expect(verificado.plantaId).toBe(payload.plantaId);
  });

  test('refresh con token invalido falla con 401', async () => {
    await expect(authService.refreshToken('token-falso')).rejects.toMatchObject({ statusCode: 401 });
  });

  test('verifyToken sin token falla con 401', async () => {
    await expect(authService.verifyToken()).rejects.toMatchObject({ statusCode: 401 });
  });

  test('logout responde sin invalidar el token', async () => {
    await expect(authService.logout()).resolves.toEqual({
      success: true,
      message: 'Sesión cerrada correctamente.',
    });
    await expect(authService.verifyToken(token)).resolves.toBeTruthy();
  });
});

describe('POST /auth/register con admin autenticado', () => {
  test('un admin puede registrar usuarios en su planta', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'supervisor' } });
    const email = `sup.${Date.now()}@test.com`;

    const response = await request(app).post('/auth/register').set(auth(token)).send({
      nombre: 'Super', apellido: 'Visor', email, password: 'Test123!',
      rolId: rol.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.user.email).toBe(email);

    await Usuario.destroy({ where: { email } });
  });

  test('sin token responde 401 porque ya existe un admin', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'operador' } });

    const response = await request(app).post('/auth/register').send({
      nombre: 'Sin', apellido: 'Token', email: `sin.token.${Date.now()}@test.com`,
      password: 'Test123!', rolId: rol.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(401);
  });

  test('con token de rol no admin responde 403', async () => {
    const rolAdmin = await Rol.findOne({ where: { nombre: 'admin' } });
    const email = `noadmin.${Date.now()}@test.com`;
    const usuario = await Usuario.create({
      nombre: 'No', apellido: 'Admin', email,
      password: await securityAuthService.hashPassword('Test123!'),
      rolId: (await Rol.findOne({ where: { nombre: 'laboratorio' } })).id,
      plantaId: planta.id, activo: true,
    });

    const tokenLab = await securityAuthService.signToken({
      sub: usuario.id, email: usuario.email, rol: 'laboratorio',
      rolId: usuario.rolId, plantaId: planta.id,
    });

    const response = await request(app).post('/auth/register').set(auth(tokenLab)).send({
      nombre: 'Rechazado', apellido: 'Test', email: `rechazado.${Date.now()}@test.com`,
      password: 'Test123!', rolId: rolAdmin.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(403);
    await Usuario.destroy({ where: { id: usuario.id } });
  });

  test('un email duplicado responde 409', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'supervisor' } });

    const response = await request(app).post('/auth/register').set(auth(token)).send({
      nombre: 'Dup', apellido: 'Test', email: 'admin@milkdata.com',
      password: 'Test123!', rolId: rol.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(409);
  });

  test('sin plantaId responde 400 y no crea nada', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'supervisor' } });
    const email = `sin.planta.${Date.now()}@test.com`;

    const response = await request(app).post('/auth/register').set(auth(token)).send({
      nombre: 'Sin', apellido: 'Planta', email, password: 'Test123!', rolId: rol.id,
    });

    expect(response.statusCode).toBe(400);
    expect(response.body.message).toBe('El campo plantaId es obligatorio.');
    expect(await Usuario.count({ where: { email } })).toBe(0);
  });

  // Escalada de privilegios: si un admin de planta pudiera crear un superadmin,
  // ese usuario nuevo administraria TODAS las plantas. El admin de una sola
  // planta escalaba al poder que por diseño es exclusivo del superadmin.
  test('un admin de planta NO puede crear un superadmin', async () => {
    const superadmin = await Rol.findOne({ where: { nombre: 'superadmin' } });
    const email = `escalada.${Date.now()}@test.com`;

    // El token tiene que ser de un admin DE PLANTA. `token` viene del login por
    // defecto, que desde que el seed creo asi es el superadmin: usarlo aca
    // devolveria 201 y la prueba pasaria por el motivo equivocado, vigilando
    // que el superadmin no se autoescale en vez de vigilar al admin.
    const tokenAdminPlanta = await tokenForRole('admin', 'esc', planta.id);

    const response = await request(app).post('/auth/register').set(auth(tokenAdminPlanta)).send({
      nombre: 'Escalado', apellido: 'Test', email, password: 'Test123!',
      rolId: superadmin.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(403);
    expect(response.body.message).toBe('Solo un superadmin puede crear otro superadmin.');
    expect(await Usuario.count({ where: { email } })).toBe(0);

    await cleanupTestUsers('esc');
  });

  test('un superadmin SI puede crear otro superadmin', async () => {
    const superadminRol = await Rol.findOne({ where: { nombre: 'superadmin' } });
    const email = `super.ok.${Date.now()}@test.com`;

    // El token se firma con rol superadmin. No hace falta un usuario real: el
    // middleware solo compara el rol que trae el token.
    const tokenSuperadmin = await securityAuthService.signToken({
      sub: 1, email: 'superadmin@milkdata.com', rol: 'superadmin',
      rolId: superadminRol.id, plantaId: planta.id,
    });

    const response = await request(app).post('/auth/register').set(auth(tokenSuperadmin)).send({
      nombre: 'Super', apellido: 'Nuevo', email, password: 'Test123!',
      rolId: superadminRol.id, plantaId: planta.id,
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.data.user.email).toBe(email);

    await Usuario.destroy({ where: { email } });
  });
});
