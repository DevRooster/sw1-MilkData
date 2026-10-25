/**
 * CRUD de usuarios de la planta.
 *
 * Cada suite crea sus propias filas con un sufijo único en el correo y las
 * borra al terminar. No se toca ninguna fila del seed: una prueba que limpia de
 * más se lleva por delante los datos de las demás.
 */
const {
  app, request, login, auth, closeDatabase, plantaPrincipal, cleanupTestUsers,
  CREDENCIALES_ADMIN_HUATA,
} = require('../helpers/auth');
const securityAuthService = require('../../src/security/auth.service');
const { Usuario, Rol, Planta } = require('../../src/entities');

const sufijo = `usr${Date.now().toString(36)}`;
const CRED = 'Test123!';

let planta;
let tokenSuperadmin;

beforeAll(async () => {
  planta = await plantaPrincipal();
  tokenSuperadmin = await login();
});

afterAll(async () => {
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

/** Crea un usuario de prueba dentro de la planta. */
async function crear({
  nombre = 'Prueba',
  apellido = 'Usuario',
  rol = 'operador',
  activo = true,
} = {}) {
  const rolId = (await Rol.findOne({ where: { nombre: rol } })).id;
  const email = `${nombre.toLowerCase()}.${sufijo}@test.com`;

  return Usuario.create({
    nombre,
    apellido,
    email,
    password: await securityAuthService.hashPassword(CRED),
    rolId,
    plantaId: planta.id,
    activo,
  });
}

describe('GET /usuarios', () => {
  test('lista usuarios de la planta y nunca la contraseña', async () => {
    const creado = await crear({ nombre: 'Listado' });

    const response = await request(app)
      .get('/usuarios')
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);

    const mio = response.body.data.items.find((u) => u.id === creado.id);
    expect(mio).toBeTruthy();
    expect(mio.email).toBe(creado.email);
    // La contraseña no puede viajar ni en el listado ni en el detalle: es un
    // hash, pero un hash que sale de la base ya no está protegido por el
    // Keystore ni por nada.
    expect(mio.password).toBeUndefined();
  });

  test('trae rol y planta de cada usuario', async () => {
    const creado = await crear({ nombre: 'Completo', rol: 'supervisor' });

    const response = await request(app)
      .get(`/usuarios/${creado.id}`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.rol.nombre).toBe('supervisor');
    expect(response.body.data.item.plantaId).toBe(planta.id);
    expect(response.body.data.item.password).toBeUndefined();
  });

  test('pagina y devuelve el estado', async () => {
    const response = await request(app)
      .get('/usuarios?pagina=1&limite=2')
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.length).toBeLessThanOrEqual(2);
    expect(response.body.data.paginacion.limite).toBe(2);
    expect(response.body.data.paginacion.pagina).toBe(1);
    expect(response.body.data.paginacion.total).toBeGreaterThan(0);
  });

  test('un limite invalido responde 400 y no una pagina de 10', async () => {
    // Si se ignorara, quien pide 0 recibiria 10 filas sin enterarse.
    const response = await request(app)
      .get('/usuarios?limite=0')
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(400);
  });

  test('filtra por rol', async () => {
    const creado = await crear({ nombre: 'FiltroRol', rol: 'laboratorio' });
    const rolId = (await Rol.findOne({ where: { nombre: 'laboratorio' } })).id;

    const response = await request(app)
      .get(`/usuarios?rolId=${rolId}&limite=100`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.every((u) => u.rolId === rolId)).toBe(true);
    expect(response.body.data.items.some((u) => u.id === creado.id)).toBe(true);
  });

  test('filtra por texto en nombre, apellido o correo', async () => {
    await crear({ nombre: 'Buscable', apellido: 'Unico' });

    const response = await request(app)
      .get(`/usuarios?busqueda=Buscable&limite=100`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].nombre).toBe('Buscable');
  });

  test('filtra por activo', async () => {
    await crear({ nombre: 'Inactivo', activo: false });

    const response = await request(app)
      .get('/usuarios?activo=false&limite=100')
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.every((u) => u.activo === false)).toBe(true);
  });

  test('no lista usuarios de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `A-${sufijo}`, activo: true,
    });
    const rolId = (await Rol.findOne({ where: { nombre: 'operador' } })).id;
    const email = `ajeno.${sufijo}@test.com`;

    await Usuario.create({
      nombre: 'Ajeno', apellido: 'Test', email,
      password: await securityAuthService.hashPassword(CRED),
      rolId, plantaId: otra.id, activo: true,
    });

    const response = await request(app)
      .get('/usuarios?limite=100')
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.some((u) => u.email === email)).toBe(false);

    await Planta.destroy({ where: { id: otra.id } });
  });

  test('exige token', async () => {
    expect((await request(app).get('/usuarios')).statusCode).toBe(401);
  });
});

describe('PUT /usuarios/:id', () => {
  test('edita nombre y apellido', async () => {
    const creado = await crear({ nombre: 'Antes' });

    const response = await request(app)
      .put(`/usuarios/${creado.id}`)
      .set(auth(tokenSuperadmin))
      .send({ nombre: 'Despues', apellido: 'Cambiado' });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.nombre).toBe('Despues');
    expect(response.body.data.item.apellido).toBe('Cambiado');

    const enBase = await Usuario.findByPk(creado.id);
    expect(enBase.nombre).toBe('Despues');
  });

  test('no cambia el rol por el PUT de perfil', async () => {
    // Subir de rol por aquí sería un escalón de permisos accidental: quien edita un
    // nombre acabaría también ascendiendo a superadmin sin querer.
    const creado = await crear({ nombre: 'SinEscalada', rol: 'operador' });
    const rolAdmin = (await Rol.findOne({ where: { nombre: 'admin' } })).id;

    const response = await request(app)
      .put(`/usuarios/${creado.id}`)
      .set(auth(tokenSuperadmin))
      .send({ rolId: rolAdmin });

    expect(response.statusCode).toBe(400);
    expect(response.body.message).toContain('rol');

    const enBase = await Usuario.findByPk(creado.id);
    expect(enBase.rolId).not.toBe(rolAdmin);
  });

  test('no mueve el usuario a otra planta', async () => {
    const creado = await crear({ nombre: 'SinMover' });

    const response = await request(app)
      .put(`/usuarios/${creado.id}`)
      .set(auth(tokenSuperadmin))
      .send({ plantaId: 999999 });

    expect(response.statusCode).toBe(400);

    const enBase = await Usuario.findByPk(creado.id);
    expect(enBase.plantaId).toBe(planta.id);
  });

  test('responde 404 con un usuario de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena2 ${sufijo}`, codigo: `B-${sufijo}`, activo: true,
    });
    const rolId = (await Rol.findOne({ where: { nombre: 'operador' } })).id;

    const ajeno = await Usuario.create({
      nombre: 'Ajeno2', apellido: 'Test', email: `ajeno2.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId, plantaId: otra.id, activo: true,
    });

    const response = await request(app)
      .put(`/usuarios/${ajeno.id}`)
      .set(auth(tokenSuperadmin))
      .send({ nombre: 'Intruso' });

    expect(response.statusCode).toBe(404);

    await Planta.destroy({ where: { id: otra.id } });
  });
});

describe('PUT /usuarios/:id/rol', () => {
  test('cambia el rol', async () => {
    const creado = await crear({ nombre: 'CambioRol', rol: 'operador' });
    const rolSupervisor = (await Rol.findOne({ where: { nombre: 'supervisor' } })).id;

    const response = await request(app)
      .put(`/usuarios/${creado.id}/rol`)
      .set(auth(tokenSuperadmin))
      .send({ rolId: rolSupervisor });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.rol.nombre).toBe('supervisor');
  });

  test('un admin de planta NO puede crear un superadmin', async () => {
    // La escalada de privilegios: si un admin pudiera dar el rol superadmin,
    // saltaria el filtro que ya protege el registro de usuarios nuevos.
    const creado = await crear({ nombre: 'Escalada', rol: 'operador' });
    const rolSuper = (await Rol.findOne({ where: { nombre: 'superadmin' } })).id;
    const tokenAdmin = await login(
      CREDENCIALES_ADMIN_HUATA.email,
      CREDENCIALES_ADMIN_HUATA.password
    );

    const response = await request(app)
      .put(`/usuarios/${creado.id}/rol`)
      .set(auth(tokenAdmin))
      .send({ rolId: rolSuper });

    expect(response.statusCode).toBe(403);

    const enBase = await Usuario.findByPk(creado.id);
    expect(enBase.rolId).not.toBe(rolSuper);
  });

  test('exige rolId', async () => {
    const creado = await crear({ nombre: 'SinRol' });

    const response = await request(app)
      .put(`/usuarios/${creado.id}/rol`)
      .set(auth(tokenSuperadmin))
      .send({});

    expect(response.statusCode).toBe(400);
  });

  test('un rol inexistente responde 400', async () => {
    const creado = await crear({ nombre: 'RolFantasma' });

    const response = await request(app)
      .put(`/usuarios/${creado.id}/rol`)
      .set(auth(tokenSuperadmin))
      .send({ rolId: 999999 });

    expect(response.statusCode).toBe(400);
  });
});

describe('PUT /usuarios/:id/activo', () => {
  test('desactiva y reactiva', async () => {
    const creado = await crear({ nombre: 'Interruptor' });

    const off = await request(app)
      .put(`/usuarios/${creado.id}/activo`)
      .set(auth(tokenSuperadmin))
      .send({ activo: false });

    expect(off.statusCode).toBe(200);
    expect(off.body.data.item.activo).toBe(false);

    const on = await request(app)
      .put(`/usuarios/${creado.id}/activo`)
      .set(auth(tokenSuperadmin))
      .send({ activo: true });

    expect(on.body.data.item.activo).toBe(true);
  });

  test('exige el campo activo', async () => {
    const creado = await crear({ nombre: 'SinActivo' });

    const response = await request(app)
      .put(`/usuarios/${creado.id}/activo`)
      .set(auth(tokenSuperadmin))
      .send({});

    expect(response.statusCode).toBe(400);
  });
});

describe('DELETE /usuarios/:id', () => {
  test('borra un usuario normal', async () => {
    const creado = await crear({ nombre: 'Borrable' });

    const response = await request(app)
      .delete(`/usuarios/${creado.id}`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.deleted).toBe(true);
    expect(await Usuario.findByPk(creado.id)).toBeNull();
  });

  test('no deja borrar la propia cuenta', async () => {
    // Se usa un admin nuevo, no la cuenta de arranque: el superadmin ya está
    // protegido por otra regla, así que con él la prueba passaría sin llegar a
    // comprobar lo que dice comprobar. Y es un admin más, para que al intentar
    // borrarse quede otro al mando: si no, saltaría antes el aviso de "no dejes
    // la planta sin administradores".
    const segundo = await crear({ nombre: 'AutoBorrado', rol: 'admin' });
    const tokenSegundo = await request(app)
      .post('/auth/login')
      .send({ email: segundo.email, password: CRED })
      .then((r) => r.body.data.token);

    const response = await request(app)
      .delete(`/usuarios/${segundo.id}`)
      .set(auth(tokenSegundo));

    // Borrarse dejaría la sesión sin dueño: el token seguiría valiendo pero el
    // usuario ya no existiría.
    expect(response.statusCode).toBe(400);
    expect(await Usuario.findByPk(segundo.id)).toBeTruthy();

    // Este admin de más no puede quedarse activo. Mientras exista, la planta
    // tiene dos administradores y la regla de "no dejes la planta sin admins"
    // deja de dispararse: la prueba siguiente, que borra al único admin real,
    // pasaría sin comprobar nada. Es el fallo clásico de un test que deja
    // estado para los que van detrás.
    //
    // Se desactiva en vez de borrarse porque borrarlo es justo lo que esta
    // prueba acaba de comprobar que no se puede.
    await segundo.update({ activo: false });
  });

  test('no deja quedarse sin ningun admin activo', async () => {
    const adminHuata = await Usuario.findOne({
      where: { email: CREDENCIALES_ADMIN_HUATA.email },
    });

    const response = await request(app)
      .delete(`/usuarios/${adminHuata.id}`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(400);
    expect(response.body.message).toMatch(/administrador/i);
    expect(await Usuario.findByPk(adminHuata.id)).toBeTruthy();
  });

  test('no borra a un superadmin', async () => {
    const superusuario = await Usuario.findOne({ where: { rolId: 1, plantaId: planta.id } });

    const response = await request(app)
      .delete(`/usuarios/${superusuario.id}`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(400);
    expect(await Usuario.findByPk(superusuario.id)).toBeTruthy();
  });

  test('responde 404 con un usuario de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena3 ${sufijo}`, codigo: `C-${sufijo}`, activo: true,
    });
    const rolId = (await Rol.findOne({ where: { nombre: 'operador' } })).id;

    const ajeno = await Usuario.create({
      nombre: 'Ajeno3', apellido: 'Test', email: `ajeno3.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId, plantaId: otra.id, activo: true,
    });

    const response = await request(app)
      .delete(`/usuarios/${ajeno.id}`)
      .set(auth(tokenSuperadmin));

    expect(response.statusCode).toBe(404);
    expect(await Usuario.findByPk(ajeno.id)).toBeTruthy();

    await Planta.destroy({ where: { id: otra.id } });
  });

  test('exige permiso de escritura', async () => {
    const creado = await crear({ nombre: 'SoloLectura' });
    const tokenOperador = await request(app)
      .post('/auth/login')
      .send({ email: 'acopiador@milkdata.com', password: 'Acopiador123!' })
      .then((r) => r.body.data.token);

    const response = await request(app)
      .delete(`/usuarios/${creado.id}`)
      .set(auth(tokenOperador));

    expect(response.statusCode).toBe(403);
    expect(await Usuario.findByPk(creado.id)).toBeTruthy();
  });
});