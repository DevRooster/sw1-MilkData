const { app, request, tokenForRole, auth, cleanupTestUsers, closeDatabase } = require('../helpers/auth');
const { Rol, Planta, Usuario, Proveedor } = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');
const { crearEscenario, crearProveedor, crearUnidad, limpiar, Planta: PlantaEntity } = require('../helpers/rutas');

const sufijo = `rut${Date.now().toString(36)}`;

let planta;
let ruta;
let zona;
let proveedores;
let paradas;
let unidad;
let tokenAdmin;
let tokenAcopiador;
let rolAcopiador;

beforeAll(async () => {
  planta = await PlantaEntity.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  tokenAdmin = await tokenForRole('admin', sufijo);

  rolAcopiador = await Rol.findOne({ where: { nombre: 'acopiador' } });
  const acopiador = await Usuario.create({
    nombre: 'Chof', apellido: 'Prueba',
    email: `acopiador.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword('Test123!'),
    rolId: rolAcopiador.id, plantaId: planta.id, activo: true,
  });
  tokenAcopiador = await securityAuthService.signToken({
    sub: acopiador.id, email: acopiador.email, rol: 'acopiador',
    rolId: rolAcopiador.id, plantaId: planta.id,
  });

  ({ ruta, zona, proveedores, paradas } = await crearEscenario({ planta, sufijo, paradas: 3 }));
  unidad = await crearUnidad({ planta, acopiador, sufijo });
});

afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

describe('GET /rutas', () => {
  test('lista las rutas de la planta con el conteo de paradas', async () => {
    const r = await request(app).get('/rutas').set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.success).toBe(true);
    expect(Array.isArray(r.body.data.items)).toBe(true);

    const propia = r.body.data.items.find((x) => x.id === ruta.id);
    expect(propia).toBeTruthy();
    expect(propia.paradas).toBe(3);
    expect(propia.nombre).toBe(ruta.nombre);
  });

  test('busca por codigo', async () => {
    const r = await request(app).get(`/rutas/codigo/${ruta.codigo}`).set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.id).toBe(ruta.id);
  });

  test('exige token', async () => {
    const r = await request(app).get('/rutas');
    expect(r.statusCode).toBe(401);
  });
});

describe('GET /rutas/:id', () => {
  test('devuelve las paradas ordenadas con su proveedor', async () => {
    const r = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    const { paradas: devueltas } = r.body.data.item;
    expect(devueltas).toHaveLength(3);
    expect(devueltas.map((p) => p.orden)).toEqual([1, 2, 3]);
    expect(devueltas[0].proveedor.dni).toBe(proveedores[0].dni);
    // El acopiador necesita la dirección para llegar.
    expect(devueltas[0].proveedor.direccion).toBe('Calle 1 123');
    expect(devueltas[0].proveedor.telefono).toBe('900000000');
    expect(devueltas[0].proveedor.imagen).toBeNull();
  });

  test('incluye las zonas que pertenecen a la ruta', async () => {
    const r = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));

    expect(r.body.data.item.zonas.map((z) => z.id)).toContain(zona.id);
  });

  test('404 si la ruta no existe', async () => {
    const r = await request(app).get('/rutas/999999').set(auth(tokenAdmin));
    expect(r.statusCode).toBe(404);
  });
});

describe('GET /rutas/:id/recomendada', () => {
  test('sin recorrido, todas las paradas quedan PENDIENTE', async () => {
    const r = await request(app).get(`/rutas/${ruta.id}/recomendada`).set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    const devueltas = r.body.data.ruta.paradas;
    expect(devueltas).toHaveLength(3);
    expect(devueltas.every((p) => p.estado === 'PENDIENTE')).toBe(true);
    expect(devueltas.map((p) => p.orden)).toEqual([1, 2, 3]);
  });

  test('el acopiador puede leerla', async () => {
    const r = await request(app).get(`/rutas/${ruta.id}/recomendada`).set(auth(tokenAcopiador));
    expect(r.statusCode).toBe(200);
  });
});

describe('Paradas de la ruta', () => {
  let nuevoProveedor;

  beforeEach(async () => {
    nuevoProveedor = await crearProveedor({ planta, zona, sufijo, orden: 9 });
  });

  afterEach(async () => {
    const p = await Proveedor.findByPk(nuevoProveedor.id);
    if (p) await p.destroy();
  });

  test('el acopiador no puede agregar paradas', async () => {
    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAcopiador))
      .send({ proveedorId: nuevoProveedor.id });

    expect(r.statusCode).toBe(403);
  });

  test('la planta sí puede, y el proveedor queda en esa ruta', async () => {
    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAdmin))
      .send({ proveedorId: nuevoProveedor.id, horaEstimada: '10:00:00' });

    expect(r.statusCode).toBe(201);
    expect(r.body.data.item.proveedorId).toBe(nuevoProveedor.id);

    const despues = await nuevoProveedor.reload();
    expect(despues.rutaId).toBe(ruta.id);

    await request(app)
      .delete(`/rutas/${ruta.id}/paradas/${r.body.data.item.id}`)
      .set(auth(tokenAdmin));
  });

  test('la columna ruta_id no se puede escribir por su cuenta', async () => {
    // Todo ocurre en una ruta propia de esta prueba. La ruta que comparte el
    // resto de la suite no se toca: añadirle una parada deja el orden
    // renumerado y las pruebas de reordenar y compactar empiezan a fallar sin
    // que su propio código haya cambiado.
    const propia = await crearEscenario({ planta, sufijo: `${sufijo}-propia`, paradas: 2 });
    const [movible] = propia.proveedores;

    // El proveedor ya está en su ruta por la vía buena: `crearEscenario` le deja
    // la parada creada y la columna apuntando a la ruta.
    const antes = await movible.reload();
    expect(antes.rutaId).toBe(propia.ruta.id);

    // Se intenta mover a la otra ruta escribiendo solo la columna, sin tocar la
    // parada. Antes esto se aceptaba y dejaba al proveedor diciendo que estaba
    // en una ruta con su parada en otra: las dos cosas no pueden ser verdad a
    // la vez, y ninguna se enteraba.
    const intento = await request(app)
      .put(`/proveedores/${movible.id}`)
      .set(auth(tokenAdmin))
      .send({ rutaId: ruta.id });

    expect(intento.statusCode).toBe(400);
    expect(intento.body.message).toMatch(/paradas/i);

    // Ni la columna se movió, ni la parada.
    const despues = await movible.reload();
    expect(despues.rutaId).toBe(propia.ruta.id);

    const detalle = await request(app).get(`/rutas/${propia.ruta.id}`).set(auth(tokenAdmin));
    expect(detalle.body.data.item.paradas.some((p) => p.proveedorId === movible.id)).toBe(true);

    const enLaOtra = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));
    expect(enLaOtra.body.data.item.paradas.some((p) => p.proveedorId === movible.id)).toBe(false);
  });

  test('un alta con rutaId se rechaza: el proveedor nace sin ruta', async () => {
    const r = await request(app)
      .post('/proveedores')
      .set(auth(tokenAdmin))
      .send({
        nombre: 'Con', apellido: 'Ruta', dni: `X${sufijo}`,
        codigo: `XR-${sufijo}`, zonaId: zona.id, rutaId: ruta.id,
      });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/paradas/i);

    const creado = await Proveedor.findOne({ where: { dni: `X${sufijo}` } });
    expect(creado).toBeNull();
  });

  test('no admite al mismo proveedor dos veces', async () => {
    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAdmin))
      .send({ proveedorId: proveedores[0].id });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/ya está en esta ruta/);
  });

  test('rechaza un proveedor de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Otra ${sufijo}`, codigo: `O-${sufijo}`, activo: true,
    });
    const suyo = await crearProveedor({ planta: otra, sufijo, orden: 7 });

    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAdmin))
      .send({ proveedorId: suyo.id });

    expect(r.statusCode).toBe(404);
    await limpiar({ plantaId: otra.id, sufijo });
    await Planta.destroy({ where: { id: otra.id } });
  });

  test('reordenar deja la secuencia 1..N sin huecos', async () => {
    const detalle = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));
    const actuales = detalle.body.data.item.paradas;
    const invertido = [...actuales].reverse().map((p, i) => ({ idParada: p.id, orden: i + 1 }));

    const r = await request(app)
      .put(`/rutas/${ruta.id}/paradas/orden`)
      .set(auth(tokenAdmin))
      .send({ ordenes: invertido });

    expect(r.statusCode).toBe(200);
    const ordenes = r.body.data.ruta.paradas.map((p) => p.orden);
    expect(ordenes).toEqual([1, 2, 3]);
    expect(r.body.data.ruta.paradas.map((p) => p.id)).toEqual(
      [...actuales].reverse().map((p) => p.id)
    );

    // se restaura
    await request(app)
      .put(`/rutas/${ruta.id}/paradas/orden`)
      .set(auth(tokenAdmin))
      .send({ ordenes: actuales.map((p, i) => ({ idParada: p.id, orden: i + 1 })) });
  });

  test('no acepta reordenar una parada ajena a la ruta', async () => {
    const otra = await crearEscenario({ planta, sufijo: `${sufijo}x`, paradas: 1 });
    const r = await request(app)
      .put(`/rutas/${ruta.id}/paradas/orden`)
      .set(auth(tokenAdmin))
      .send({ ordenes: [{ idParada: otra.paradas[0].id, orden: 1 }] });

    expect(r.statusCode).toBe(404);
    await limpiar({ plantaId: planta.id, sufijo: `${sufijo}x` });
  });

  test('quitar una parada compacta el orden y libera al proveedor', async () => {
    const alta = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAdmin))
      .send({ proveedorId: nuevoProveedor.id });
    const paradaId = alta.body.data.item.id;

    const antes = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));
    expect(antes.body.data.item.paradas.map((p) => p.orden)).toEqual([1, 2, 3, 4]);

    const r = await request(app)
      .delete(`/rutas/${ruta.id}/paradas/${paradaId}`)
      .set(auth(tokenAdmin));
    expect(r.statusCode).toBe(200);
    expect(r.body.data.quitada).toBe(true);

    const despues = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAdmin));
    expect(despues.body.data.item.paradas.map((p) => p.orden)).toEqual([1, 2, 3]);

    const libre = await nuevoProveedor.reload();
    expect(libre.rutaId).toBeNull();
  });
});

describe('GET /rutas/proveedores/:id/sugerencia', () => {
  test('sugiere la ruta que ya atiende la zona del proveedor', async () => {
    const sinRuta = await crearProveedor({ planta, zona, sufijo, orden: 5 });
    await sinRuta.update({ rutaId: null });

    const r = await request(app)
      .get(`/rutas/proveedores/${sinRuta.id}/sugerencia`)
      .set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.sugerencia).toBe('SUGERIDA');
    expect(r.body.data.rutaId).toBe(ruta.id);
    expect(r.body.data.zonaId).toBe(zona.id);
    expect(Array.isArray(r.body.data.candidatas)).toBe(true);

    await sinRuta.destroy();
  });

  test('avisa cuando el proveedor ya está en una ruta', async () => {
    const r = await request(app)
      .get(`/rutas/proveedores/${proveedores[0].id}/sugerencia`)
      .set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.sugerencia).toBe('YA_ESTA_EN_RUTA');
    expect(r.body.data.rutaId).toBe(ruta.id);
  });

  test('avisa cuando la planta no tiene rutas', async () => {
    const vacia = await Planta.create({
      nombre: `Vacia ${sufijo}`, codigo: `V-${sufijo}`, activo: true,
    });
    const suyo = await crearProveedor({ planta: vacia, sufijo, orden: 3 });
    const token = await securityAuthService.signToken({
      sub: 1, email: 'v@t.com', rol: 'admin',
      rolId: (await Rol.findOne({ where: { nombre: 'admin' } })).id, plantaId: vacia.id,
    });

    const r = await request(app)
      .get(`/rutas/proveedores/${suyo.id}/sugerencia`)
      .set(auth(token));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.sugerencia).toBe('SIN_RUTAS');
    expect(r.body.data.rutaId).toBeNull();

    await limpiar({ plantaId: vacia.id, sufijo });
    await Planta.destroy({ where: { id: vacia.id } });
  });
});

describe('Aislamiento por planta en rutas', () => {
  test('otra planta no ve la ruta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `J-${sufijo}`, activo: true,
    });
    const adminRol = await Rol.findOne({ where: { nombre: 'admin' } });
    const tokenAjeno = await securityAuthService.signToken({
      sub: 1, email: 'j@t.com', rol: 'admin', rolId: adminRol.id, plantaId: otra.id,
    });

    const ver = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAjeno));
    expect(ver.statusCode).toBe(404);

    const lista = await request(app).get('/rutas').set(auth(tokenAjeno));
    expect(lista.statusCode).toBe(200);
    expect(lista.body.data.items).toEqual([]);

    await Planta.destroy({ where: { id: otra.id } });
  });
});

describe('Permisos de rutas', () => {
  test('el acopiador lee pero no escribe', async () => {
    const leer = await request(app).get('/rutas').set(auth(tokenAcopiador));
    expect(leer.statusCode).toBe(200);

    const crear = await request(app)
      .post('/rutas')
      .set(auth(tokenAcopiador))
      .send({ nombre: 'X', codigo: `X${sufijo}` });
    expect(crear.statusCode).toBe(403);
  });

  test('un rol sin permiso de rutas recibe 403', async () => {
    const tokenProv = await tokenForRole('proveedor', sufijo);
    const r = await request(app).get('/rutas').set(auth(tokenProv));
    expect(r.statusCode).toBe(403);
  });
});
