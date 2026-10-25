const { app, request, tokenForRole, auth, cleanupTestUsers, closeDatabase } = require('../helpers/auth');
const { Rol, Planta, Usuario, Recorrido, RecorridoParada, Recoleccion } = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');
const {
  crearEscenario, crearProveedor, crearUnidad, limpiar, Planta: PlantaEntity,
} = require('../helpers/rutas');

const sufijo = `rec${Date.now().toString(36)}`;
const CRED = 'Test123!';

let planta;
let ruta;
let zona;
let proveedores;
let unidad;
let acopiador;
let tokenAcopiador;
let tokenAdmin;
let tokenOtroAcopiador;
let otroAcopiador;

/** Crea un recorrido PLANIFICADO y devuelve su id. */
async function planificar(extra = {}) {
  const r = await request(app)
    .post('/recorridos')
    .set(auth(tokenAcopiador))
    .send({ rutaId: ruta.id, unidadId: unidad.id, ...extra });
  return r;
}

/** Arranca un recorrido y devuelve el id de sus paradas por proveedor. */
async function arrancar({ kmInicio } = {}) {
  const crear = await planificar();
  const id = crear.body.data.item.id;
  const iniciar = await request(app)
    .post(`/recorridos/${id}/iniciar`)
    .set(auth(tokenAcopiador))
    .send(kmInicio === undefined ? {} : { kilometrajeInicio: kmInicio });
  const paradas = iniciar.body.data.item.paradas;
  const porProveedor = new Map(paradas.map((p) => [p.proveedorId, p]));
  return { id, paradas: porProveedor, respuesta: iniciar };
}

/**
 * Cierra los recorridos que un test anterior dejó EN RUTA.
 *
 * `/recorridos/actual` devuelve el primero que encuentra, así que sin esto el
 * resultado dependería del orden de ejecución.
 *
 * Se recorre paginando: si se pidiera solo la primera página quedarían abiertos
 * los que caigan en la segunda.
 */
async function cerrarAbiertos() {
  for (let pagina = 1; pagina <= 50; pagina += 1) {
    const lista = await request(app)
      .get(`/recorridos?estado=EN_RUTA&pagina=${pagina}&limite=50`)
      .set(auth(tokenAcopiador));

    const items = lista.body.data.items || [];
    if (!items.length) return;

    for (const item of items) {
      await request(app).post(`/recorridos/${item.id}/finalizar`).set(auth(tokenAcopiador)).send({});
    }
  }
}

beforeAll(async () => {
  planta = await PlantaEntity.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  const rolAcopiador = await Rol.findOne({ where: { nombre: 'acopiador' } });
  tokenAdmin = await tokenForRole('admin', sufijo);

  acopiador = await Usuario.create({
    nombre: 'Chof', apellido: 'Uno',
    email: `acopiador.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAcopiador.id, plantaId: planta.id, activo: true,
  });
  tokenAcopiador = await securityAuthService.signToken({
    sub: acopiador.id, email: acopiador.email, rol: 'acopiador',
    rolId: rolAcopiador.id, plantaId: planta.id,
  });

  otroAcopiador = await Usuario.create({
    nombre: 'Chof', apellido: 'Dos',
    email: `otro.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAcopiador.id, plantaId: planta.id, activo: true,
  });
  tokenOtroAcopiador = await securityAuthService.signToken({
    sub: otroAcopiador.id, email: otroAcopiador.email, rol: 'acopiador',
    rolId: rolAcopiador.id, plantaId: planta.id,
  });

  ({ ruta, zona, proveedores } = await crearEscenario({ planta, sufijo, paradas: 3 }));
  unidad = await crearUnidad({ planta, acopiador, sufijo });
});

beforeEach(async () => {
  await cerrarAbiertos();
});

afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

describe('POST /recorridos (planificación)', () => {
  test('nace PLANIFICADO y sin paradas selladas', async () => {
    const r = await planificar();

    expect(r.statusCode).toBe(201);
    const item = r.body.data.item;
    expect(item.estado).toBe('PLANIFICADO');
    expect(item.rutaId).toBe(ruta.id);
    expect(item.unidadId).toBe(unidad.id);
    // El acopiador por defecto es quien authenticated.
    expect(item.acopiadorId).toBe(acopiador.id);
    expect(item.horaInicio).toBeNull();
    expect(item.paradas).toEqual([]);
    expect(item.ruta.nombre).toBe(ruta.nombre);
  });

  test('acepta el ayudante externo con sus datos', async () => {
    const r = await planificar({
      ayudanteNombre: 'Pedro', ayudanteApellido: 'Ayuda',
      ayudanteDni: '70999999', ayudanteCelular: '987654321',
    });

    expect(r.statusCode).toBe(201);
    const item = r.body.data.item;
    expect(item.ayudanteNombre).toBe('Pedro');
    expect(item.ayudanteApellido).toBe('Ayuda');
    expect(item.ayudanteDni).toBe('70999999');
    expect(item.ayudanteCelular).toBe('987654321');
    expect(item.ayudanteUsuarioId).toBeNull();
  });

  test('el ayudante interno se busca por id de usuario', async () => {
    const r = await planificar({ ayudanteUsuarioId: otroAcopiador.id });

    expect(r.statusCode).toBe(201);
    const item = r.body.data.item;
    expect(item.ayudanteUsuarioId).toBe(otroAcopiador.id);
    // Los datos sueltos sobran cuando el ayudante es interno.
    expect(item.ayudanteNombre).toBeNull();
    expect(item.ayudanteDni).toBeNull();
  });

  test('rechaza un ayudante externo incompleto', async () => {
    const r = await planificar({ ayudanteNombre: 'Solo' });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/apellido, dni/);
  });

  test('rechaza un ayudante interno de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `A-${sufijo}`, activo: true,
    });
    const suyo = await Usuario.create({
      nombre: 'De', apellido: 'Alla',
      email: `allá.${sufijo}@test.com`.replace('á', 'a'),
      password: await securityAuthService.hashPassword(CRED),
      rolId: (await Rol.findOne({ where: { nombre: 'operador' } })).id,
      plantaId: otra.id, activo: true,
    });

    const r = await planificar({ ayudanteUsuarioId: suyo.id });
    expect(r.statusCode).toBe(404);

    await limpiar({ plantaId: otra.id, sufijo });
    await Planta.destroy({ where: { id: otra.id } });
  });

  test('rechaza una ruta o unidad de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `B-${sufijo}`, activo: true,
    });
    const suyo = await crearProveedor({ planta: otra, sufijo, orden: 4 });

    const sinRuta = await request(app)
      .post('/recorridos')
      .set(auth(tokenAcopiador))
      .send({ rutaId: suyo.id, unidadId: unidad.id });
    expect(sinRuta.statusCode).toBe(404);

    await limpiar({ plantaId: otra.id, sufijo });
    await Planta.destroy({ where: { id: otra.id } });
  });
});

describe('POST /recorridos/:id/iniciar (EN RUTA)', () => {
  test('sella las paradas de la ruta y registra la hora de salida', async () => {
    const { respuesta } = await arrancar({ kmInicio: 1200 });

    expect(respuesta.statusCode).toBe(200);
    const item = respuesta.body.data.item;
    expect(item.estado).toBe('EN_RUTA');
    expect(item.horaInicio).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    expect(item.fechaInicio).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(item.kilometrajeInicio).toBe(1200);
    expect(item.paradas).toHaveLength(3);
    expect(item.paradas.every((p) => p.estado === 'PENDIENTE')).toBe(true);
    expect(item.paradas.map((p) => p.orden)).toEqual([1, 2, 3]);
    // Cada parada trae los datos del proveedor para no tener que pedirlos.
    expect(item.paradas[0].proveedor.dni).toBeTruthy();
  });

  test('no deja recolectar antes de EN RUTA', async () => {
    const crear = await planificar();
    const id = crear.body.data.item.id;

    // La parada todavía no existe en el recorrido: las paradas se sellan al
    // arrancar. La respuesta debe ser por el estado, no por la parada.
    const r = await request(app)
      .post(`/recorridos/${id}/paradas/1/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 20 });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/no est/);
  });

  test('otro acopiador no arranca un recorrido ajeno', async () => {
    const crear = await planificar();
    const r = await request(app)
      .post(`/recorridos/${crear.body.data.item.id}/iniciar`)
      .set(auth(tokenOtroAcopiador))
      .send({});

    expect(r.statusCode).toBe(403);
    expect(r.body.message).toMatch(/Solo el acopiador/);
  });

  test('no se puede arrancar dos veces', async () => {
    const { id } = await arrancar();
    const r = await request(app)
      .post(`/recorridos/${id}/iniciar`)
      .set(auth(tokenAcopiador))
      .send({});

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/ya est/);
  });

  test('el supervisor sí puede arrancar en nombre del acopiador', async () => {
    const tokenSupervisor = await tokenForRole('supervisor', sufijo);
    const crear = await request(app)
      .post('/recorridos')
      .set(auth(tokenSupervisor))
      .send({ rutaId: ruta.id, unidadId: unidad.id, acopiadorId: acopiador.id });

    expect(crear.statusCode).toBe(201);
    const r = await request(app)
      .post(`/recorridos/${crear.body.data.item.id}/iniciar`)
      .set(auth(tokenSupervisor))
      .send({});

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.estado).toBe('EN_RUTA');
  });
});

describe('Recolección en una parada', () => {
  test('crea la recolección y la enlaza a la parada', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    const paradaId = porProveedor.get(proveedores[0].id).id;

    const r = await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 35.5, temperatura: 6.2 });

    expect(r.statusCode).toBe(201);
    const item = r.body.data.item;
    const atendida = item.paradas.find((p) => p.id === paradaId);
    expect(atendida.estado).toBe('ATENDIDA');
    expect(atendida.litros).toBe(35.5);
    expect(atendida.recoleccionId).toBeTruthy();
    expect(atendida.horaLlegada).toBeTruthy();
    expect(atendida.horaSalida).toBeTruthy();

    const recoleccion = await Recoleccion.findByPk(atendida.recoleccionId);
    expect(recoleccion.recorridoParadaId).toBe(paradaId);
    expect(recoleccion.cantidad).toBe(35.5);
    expect(recoleccion.proveedorId).toBe(proveedores[0].id);
    // Hereda la zona del proveedor.
    expect(recoleccion.zonaId).toBe(zona.id);
    expect(recoleccion.unidadId).toBe(unidad.id);
  });

  test('no admite dos recolecciones en la misma parada', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    const paradaId = porProveedor.get(proveedores[0].id).id;

    await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 10 });

    const r = await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 20 });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/ya tiene una recolecci/);
  });

  test('rechaza una parada de otro recorrido', async () => {
    const uno = await arrancar();
    const dos = await arrancar();

    const r = await request(app)
      .post(`/recorridos/${dos.id}/paradas/${uno.paradas.get(proveedores[0].id).id}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 10 });

    expect(r.statusCode).toBe(404);
  });

  test('el proveedor necesita zona para poder registrar la recolección', async () => {
    const sinZona = await crearProveedor({ planta, zona: null, sufijo, orden: 8 });
    const r = await request(app)
      .post('/recorridos')
      .set(auth(tokenAcopiador))
      .send({ rutaId: ruta.id, unidadId: unidad.id });
    const id = r.body.data.item.id;
    await request(app).post(`/recorridos/${id}/iniciar`).set(auth(tokenAcopiador)).send({});

    // La parada del escenario no es la de este proveedor, así que se agrega.
    const detalle = await request(app).get(`/recorridos/${id}`).set(auth(tokenAcopiador));
    const paradaId = detalle.body.data.item.paradas[0].id;

    const r2 = await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/atender`)
      .set(auth(tokenAcopiador))
      .send({ litros: 5 });

    expect(r2.statusCode).toBe(200);
    await sinZona.destroy();
  });
});

describe('Marcar una parada sin recolectar', () => {
  test('se puede omitir con motivo', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    const paradaId = porProveedor.get(proveedores[1].id).id;

    const r = await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/atender`)
      .set(auth(tokenAcopiador))
      .send({ estado: 'OMITIDA', observaciones: 'Proveedor ausente' });

    expect(r.statusCode).toBe(200);
    const omitida = r.body.data.item.paradas.find((p) => p.id === paradaId);
    expect(omitida.estado).toBe('OMITIDA');
    expect(omitida.observaciones).toBe('Proveedor ausente');
    expect(omitida.recoleccionId).toBeNull();
  });

  test('por defecto la parada queda ATENDIDA', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    const paradaId = porProveedor.get(proveedores[0].id).id;

    const r = await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/atender`)
      .set(auth(tokenAcopiador))
      .send({ litros: 12 });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.paradas.find((p) => p.id === paradaId).estado).toBe('ATENDIDA');
  });
});

describe('GET /rutas/:id/recomendada con recorrido', () => {
  test('refleja lo ya recolectado y lo que falta', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    await request(app)
      .post(`/recorridos/${id}/paradas/${porProveedor.get(proveedores[0].id).id}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 18 });
    await request(app)
      .post(`/recorridos/${id}/paradas/${porProveedor.get(proveedores[1].id).id}/atender`)
      .set(auth(tokenAcopiador))
      .send({ estado: 'OMITIDA' });

    const r = await request(app)
      .get(`/rutas/${ruta.id}/recomendada?recorridoId=${id}`)
      .set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    const lista = r.body.data.ruta.paradas;
    expect(lista.map((p) => p.estado)).toEqual(['ATENDIDA', 'OMITIDA', 'PENDIENTE']);
    expect(lista[0].litros).toBe(18);
    expect(lista[0].recoleccionId).toBeTruthy();
    // La fila de la parada existe desde que arrancó el recorrido, así que
    // tiene id; lo que sigue vacío es lo que aún no se registró.
    expect(typeof lista[2].recorridoParadaId).toBe('number');
    expect(lista[2].litros).toBeNull();
    expect(lista[2].recoleccionId).toBeNull();
  });
});

describe('POST /recorridos/:id/finalizar', () => {
  test('cierra las paradas pendientes como OMITIDA', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    await request(app)
      .post(`/recorridos/${id}/paradas/${porProveedor.get(proveedores[0].id).id}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 20 });

    const r = await request(app)
      .post(`/recorridos/${id}/finalizar`)
      .set(auth(tokenAcopiador))
      .send({ kilometrajeFin: 1265, observaciones: 'Vuelta completa' });

    expect(r.statusCode).toBe(200);
    const item = r.body.data.item;
    expect(item.estado).toBe('FINALIZADO');
    expect(item.horaFin).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    expect(item.kilometrajeFin).toBe(1265);
    expect(item.observaciones).toBe('Vuelta completa');
    expect(item.paradas.map((p) => p.estado)).toEqual(['ATENDIDA', 'OMITIDA', 'OMITIDA']);
  });

  test('no se puede finalizar algo que no arrancó', async () => {
    const crear = await planificar();
    const r = await request(app)
      .post(`/recorridos/${crear.body.data.item.id}/finalizar`)
      .set(auth(tokenAcopiador))
      .send({});

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/Solo un recorrido EN RUTA/);
  });

  test('no se puede volver a iniciar un recorrido finalizado', async () => {
    const { id } = await arrancar();
    await request(app).post(`/recorridos/${id}/finalizar`).set(auth(tokenAcopiador)).send({});

    const r = await request(app).post(`/recorridos/${id}/iniciar`).set(auth(tokenAcopiador)).send({});
    expect(r.statusCode).toBe(400);
  });
});

describe('POST /recorridos/:id/cancelar', () => {
  test('cancela un recorrido que no llegó a arrancar', async () => {
    const crear = await planificar();
    const r = await request(app)
      .post(`/recorridos/${crear.body.data.item.id}/cancelar`)
      .set(auth(tokenAcopiador))
      .send({ observaciones: 'Unidad en reparación' });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.estado).toBe('CANCELADO');
  });

  test('no se cancela un recorrido ya finalizado', async () => {
    const { id } = await arrancar();
    await request(app).post(`/recorridos/${id}/finalizar`).set(auth(tokenAcopiador)).send({});

    const r = await request(app).post(`/recorridos/${id}/cancelar`).set(auth(tokenAcopiador)).send({});
    expect(r.statusCode).toBe(400);
  });
});

describe('GET /recorridos', () => {
  test('filtra por estado, fecha y unidad', async () => {
    const { id } = await arrancar();

    const porEstado = await request(app).get('/recorridos?estado=EN_RUTA').set(auth(tokenAcopiador));
    expect(porEstado.statusCode).toBe(200);
    expect(porEstado.body.data.items.map((x) => x.id)).toContain(id);

    const porUnidad = await request(app)
      .get(`/recorridos?unidadId=${unidad.id}`)
      .set(auth(tokenAcopiador));
    expect(porUnidad.body.data.items.every((x) => x.unidadId === unidad.id)).toBe(true);

    const porFecha = await request(app)
      .get(`/recorridos?fecha=${new Date().toISOString().slice(0, 10)}`)
      .set(auth(tokenAcopiador));
    expect(porFecha.statusCode).toBe(200);
  });

  test('los listados vienen paginados', async () => {
    const r = await request(app).get('/recorridos').set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    expect(Array.isArray(r.body.data.items)).toBe(true);
    expect(r.body.data.paginacion).toMatchObject({ pagina: 1, limite: 10 });
    expect(r.body.data.items.length).toBeLessThanOrEqual(10);
    expect(typeof r.body.data.paginacion.total).toBe('number');
  });

  test('GET /recorridos/actual devuelve el recorrido en curso', async () => {
    const { id } = await arrancar();

    const r = await request(app).get('/recorridos/actual').set(auth(tokenAcopiador));
    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.id).toBe(id);

    await request(app).post(`/recorridos/${id}/finalizar`).set(auth(tokenAcopiador)).send({});

    const despues = await request(app).get('/recorridos/actual').set(auth(tokenAcopiador));
    expect(despues.body.data.item).toBeNull();
  });

  test('el acopiador no ve el recorrido en curso de otro', async () => {
    await arrancar();
    const r = await request(app).get('/recorridos/actual').set(auth(tokenOtroAcopiador));
    expect(r.body.data.item).toBeNull();
  });
});

describe('Aislamiento por planta en recorridos', () => {
  test('otra planta no ve el recorrido', async () => {
    const { id } = await arrancar();

    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `C-${sufijo}`, activo: true,
    });
    const tokenAjeno = await securityAuthService.signToken({
      sub: acopiador.id, email: acopiador.email, rol: 'acopiador',
      rolId: (await Rol.findOne({ where: { nombre: 'acopiador' } })).id, plantaId: otra.id,
    });

    const ver = await request(app).get(`/recorridos/${id}`).set(auth(tokenAjeno));
    expect(ver.statusCode).toBe(404);

    const lista = await request(app).get('/recorridos').set(auth(tokenAjeno));
    expect(lista.body.data.items).toEqual([]);

    await Planta.destroy({ where: { id: otra.id } });
  });
});

describe('Permisos de recorridos', () => {
  test('el acopiador escribe pero un proveedor no', async () => {
    const propio = await request(app).get('/recorridos').set(auth(tokenAcopiador));
    expect(propio.statusCode).toBe(200);

    const tokenProv = await tokenForRole('proveedor', sufijo);
    const r = await request(app).get('/recorridos').set(auth(tokenProv));
    expect(r.statusCode).toBe(403);
  });

  test('el operador solo lee', async () => {
    const tokenOperador = await tokenForRole('operador', sufijo);
    const leer = await request(app).get('/recorridos').set(auth(tokenOperador));
    expect(leer.statusCode).toBe(200);

    const crear = await request(app)
      .post('/recorridos')
      .set(auth(tokenOperador))
      .send({ rutaId: ruta.id, unidadId: unidad.id });
    expect(crear.statusCode).toBe(403);
  });

  test('sin token responde 401', async () => {
    const r = await request(app).get('/recorridos');
    expect(r.statusCode).toBe(401);
  });
});

describe('Persistencia', () => {
  test('el estado del recorrido sobrevive en la base', async () => {
    const { id, paradas: porProveedor } = await arrancar();
    const paradaId = porProveedor.get(proveedores[0].id).id;
    await request(app)
      .post(`/recorridos/${id}/paradas/${paradaId}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 22 });

    const fila = await Recorrido.findByPk(id);
    expect(fila.estado).toBe('EN_RUTA');

    const parada = await RecorridoParada.findByPk(paradaId);
    expect(parada.estado).toBe('ATENDIDA');
    expect(parada.litros).toBe(22);
    expect(parada.recoleccionId).toBeTruthy();
  });
});
