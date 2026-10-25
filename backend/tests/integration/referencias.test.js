/**
 * Validación de referencias cruzadas.
 *
 * Una clave foránea solo garantiza que el id exista. Estas pruebas fijan que un
 * registro de una planta no pueda apuntar a zona, unidad, ruta, proveedor,
 * usuario ni recorrido de otra.
 */
const { app, request, tokenForRole, auth, cleanupTestUsers, closeDatabase } = require('../helpers/auth');
const {
  Rol, Planta, Unidad, Zona, Usuario, Proveedor, Ruta, RutaParada, Recoleccion,
} = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');
const { crearEscenario, crearProveedor, crearUnidad, limpiar, Planta: PlantaEntity } = require('../helpers/rutas');
const { REFERENCIAS, REFERENCIAS_GLOBALES } = require('../../src/config/referencias.config');

const sufijo = `ref${Date.now().toString(36)}`;
const CRED = 'Test123!';

let planta;
let plantaAjena;
let token;
let tokenAjeno;

let zona;
let unidad;
let ruta;
let proveedores;

// Lo que hay en la planta principal.
let ajenaZona;
let ajenaUnidad;
let ajenaRuta;
let ajenaProveedor;
let ajenaUsuario;

beforeAll(async () => {
  planta = await PlantaEntity.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  token = await tokenForRole('admin', sufijo);

  plantaAjena = await Planta.create({
    nombre: `Ajena ${sufijo}`, codigo: `R-${sufijo}`, activo: true,
  });
  tokenAjeno = await tokenForRole('admin', sufijo, plantaAjena.id);

  // Escenario propio: una zona, una unidad, una ruta con paradas y proveedores.
  ({ zona, ruta, proveedores } = await crearEscenario({ planta, sufijo, paradas: 1 }));
  unidad = await crearUnidad({ planta, acopiador: null, sufijo });

  // Y lo equivalente en la otra planta, que es lo que no se debe poder usar.
  ajenaZona = await Zona.create({
    nombre: `Ajena ${sufijo}`, ruta: 'x', plantaId: plantaAjena.id, activo: true,
  });
  ajenaUnidad = await Unidad.create({
    nombre: `Ajena ${sufijo}`, tipo: 'furgon', capacidad: 100,
    plantaId: plantaAjena.id, activo: true,
  });
  ajenaRuta = await Ruta.create({
    plantaId: plantaAjena.id,
    nombre: `Ajena ${sufijo}`,
    codigo: `RA${sufijo}`.toUpperCase().slice(0, 20),
    activa: true,
  });
  ajenaProveedor = await crearProveedor({ planta: plantaAjena, sufijo, orden: 1 });
  ajenaUsuario = await Usuario.create({
    nombre: 'De', apellido: 'Alla',
    email: `alla.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: (await Rol.findOne({ where: { nombre: 'operador' } })).id,
    plantaId: plantaAjena.id, activo: true,
  });
});

/** Cierra cualquier conexion pendiente al terminar la suite. */
afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await limpiar({ plantaId: plantaAjena.id, sufijo });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

describe('Referencias de otra planta en la creación', () => {
  test('una recolección no acepta la zona de otra planta', async () => {
    const usuario = await Usuario.create({
      nombre: 'Ope', apellido: 'Local',
      email: `ope.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId: (await Rol.findOne({ where: { nombre: 'operador' } })).id,
      plantaId: planta.id, activo: true,
    });
    const propio = await crearProveedor({ planta, zona, sufijo, orden: 50 });

    const r = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: propio.id,
      zonaId: ajenaZona.id,
      unidadId: unidad.id,
      usuarioId: usuario.id,
      cantidad: 10,
      fecha: '2026-10-03',
      registradoEn: 'campo',
    });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/zona/i);
    // El mensaje no revela que la zona existe en otra planta.
    expect(r.body.message).not.toMatch(/otra planta|no pertenece a esta planta/i);
  });

  test('una recolección no acepta la unidad de otra planta', async () => {
    const usuario = await Usuario.create({
      nombre: 'Ope', apellido: 'Local2',
      email: `ope2.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId: (await Rol.findOne({ where: { nombre: 'operador' } })).id,
      plantaId: planta.id, activo: true,
    });
    const propio = await crearProveedor({ planta, zona, sufijo, orden: 51 });

    const r = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: propio.id,
      zonaId: zona.id,
      unidadId: ajenaUnidad.id,
      usuarioId: usuario.id,
      cantidad: 10,
      fecha: '2026-10-03',
      registradoEn: 'campo',
    });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/unidad/i);
  });

  test('una zona no acepta la ruta de otra planta', async () => {
    const r = await request(app).post('/zonas').set(auth(token)).send({
      nombre: `Zona ${sufijo} colada`,
      rutaId: ajenaRuta.id,
    });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/ruta/i);
  });

  test('un proveedor no acepta el usuario de otra planta', async () => {
    const r = await request(app).post('/proveedores').set(auth(token)).send({
      nombre: 'Colado', apellido: 'X',
      dni: `${sufijo}X`.toUpperCase().slice(0, 20),
      codigo: `X${sufijo}`,
      usuarioId: ajenaUsuario.id,
    });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/usuario/i);
  });

  test('un recorrido no acepta el ayudante de otra planta', async () => {
    const acopiador = await Usuario.create({
      nombre: 'Cho', apellido: 'Fer',
      email: `cho.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId: (await Rol.findOne({ where: { nombre: 'acopiador' } })).id,
      plantaId: planta.id, activo: true,
    });

    const r = await request(app).post('/recorridos').set(auth(token)).send({
      rutaId: ruta.id,
      unidadId: unidad.id,
      acopiadorId: acopiador.id,
      ayudanteUsuarioId: ajenaUsuario.id,
    });

    expect(r.statusCode).toBe(404);
  });

  test('una parada de ruta no acepta el proveedor de otra planta', async () => {
    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(token))
      .send({ proveedorId: ajenaProveedor.id });

    expect(r.statusCode).toBe(404);
  });
});

describe('Referencias inválidas al actualizar', () => {
  test('actualizar una recolección con una zona ajena se rechaza', async () => {
    const usuario = await Usuario.create({
      nombre: 'Ope', apellido: 'Upd',
      email: `upd.${sufijo}@test.com`,
      password: await securityAuthService.hashPassword(CRED),
      rolId: (await Rol.findOne({ where: { nombre: 'operador' } })).id,
      plantaId: planta.id, activo: true,
    });
    const propio = await crearProveedor({ planta, zona, sufijo, orden: 60 });

    const creada = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: propio.id,
      zonaId: zona.id,
      unidadId: unidad.id,
      usuarioId: usuario.id,
      cantidad: 5,
      fecha: '2026-10-03',
      registradoEn: 'campo',
    });
    expect(creada.statusCode).toBe(201);
    const id = creada.body.data.item.id;

    const r = await request(app).put(`/recolecciones/${id}`).set(auth(token)).send({ zonaId: ajenaZona.id });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/zona/i);

    // Y el registro quedó intacto.
    const intacta = await Recoleccion.findByPk(id);
    expect(intacta.zonaId).toBe(zona.id);
  });

  test('un update que no toca referencias se guarda igual', async () => {
    const propio = await crearProveedor({ planta, zona, sufijo, orden: 61 });
    const r = await request(app).put(`/proveedores/${propio.id}`).set(auth(token)).send({ telefono: '911' });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.telefono).toBe('911');
  });
});

describe('Referencias que sí se permiten', () => {
  test('una referencia a un registro inexistente da 400', async () => {
    const propio = await crearProveedor({ planta, zona, sufijo, orden: 62 });

    const r = await request(app).put(`/proveedores/${propio.id}`).set(auth(token)).send({ zonaId: 99999999 });

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/zona/i);
  });

  test('el rol es global: no se compara contra la planta', async () => {
    // `rol` significa lo mismo en todas las plantas, así que se valida que
    // exista pero no de qué planta es. No hay `PUT /usuarios/:id`: los usuarios
    // se dan de alta por `/auth/register`, y ahí es donde se comprueba.
    expect(REFERENCIAS[Usuario.name].rolId).toBe(Rol);
    expect(REFERENCIAS_GLOBALES.has(Rol)).toBe(true);

    const rolOperador = await Rol.findOne({ where: { nombre: 'operador' } });

    // El mismo rol sirve para un usuario de cualquiera de las dos plantas.
    const enPropia = await request(app).post('/auth/register').set(auth(token)).send({
      nombre: 'Con', apellido: 'Rol',
      email: `conrol.${sufijo}@test.com`,
      password: 'ConRol123!',
      rolId: rolOperador.id,
      plantaId: planta.id,
    });
    expect(enPropia.statusCode).toBe(201);

    const enAjena = await request(app).post('/auth/register').set(auth(tokenAjeno)).send({
      nombre: 'Con', apellido: 'Rol2',
      email: `conrol2.${sufijo}@test.com`,
      password: 'ConRol123!',
      rolId: rolOperador.id,
      plantaId: plantaAjena.id,
    });
    expect(enAjena.statusCode).toBe(201);

    // Y un rol que no existe se rechaza.
    const malo = await request(app).post('/auth/register').set(auth(token)).send({
      nombre: 'Rol', apellido: 'Fantasma',
      email: `fantasma.${sufijo}@test.com`,
      password: 'Fantasma123!',
      rolId: 99999999,
      plantaId: planta.id,
    });
    expect(malo.statusCode).toBe(400);
    expect(malo.body.message).toMatch(/rol/i);
  });

  test('dejar una referencia en null no dispara la validación', async () => {
    const propio = await crearProveedor({ planta, sufijo, orden: 63 });
    const r = await request(app).put(`/proveedores/${propio.id}`).set(auth(token)).send({ zonaId: null });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.zonaId).toBeNull();
  });
});

describe('Cobertura del mapa de referencias', () => {
  test('toda asociacion belongsTo con planta queda declarada', () => {
    const modelos = Object.values(require('../../src/entities'));
    const sinCubrir = [];

    for (const modelo of modelos) {
      for (const [alias, asociacion] of Object.entries(modelo.associations || {})) {
        if (asociacion.associationType !== 'BelongsTo') continue;
        const objetivo = asociacion.target;
        if (REFERENCIAS_GLOBALES.has(objetivo)) continue;
        if (!objetivo.rawAttributes.plantaId) continue;

        // **`foreignKey` y no `${alias}Id`.** El mapa se recorre en
        // `referencias.service` como `datos[clave]`, o sea que la clave es el
        // **nombre del atributo** que manda el cliente. Con `${alias}Id` las dos
        // cosas solo coincidían mientras el alias de la asociación y el nombre de
        // la columna fueran el mismo, y en cuanto difieren la comprobaba una
        // clave que la validación nunca lee: el `belongsTo` quedaba "cubierto"
        // en el papel y sin comprobar en la realidad.
        //
        // Pasó con `asistencia.eventoId`, cuya asociación se llama
        // `eventoRelacion` porque el nombre `evento` ya lo ocupa la columna de
        // texto. Con el criterio viejo esta prueba exigía declarar
        // `eventoRelacionId`, que el cliente no manda nunca.
        const declarados = REFERENCIAS[modelo.name] || {};
        if (!declarados[asociacion.foreignKey]) {
          sinCubrir.push(`${modelo.name}.${asociacion.foreignKey}`);
        }
      }
    }

    // Si esto falla, hay una clave foránea nueva que se escaparía de la
    // validación por planta.
    expect(sinCubrir).toEqual([]);
  });

  test('las referencias declaradas existen como columna en el modelo', () => {
    const entidades = require('../../src/entities');
    const problemas = [];

    for (const [nombreModelo, campos] of Object.entries(REFERENCIAS)) {
      const modelo = Object.values(entidades).find((m) => m.name === nombreModelo);
      if (!modelo) {
        problemas.push(`modelo desconocido: ${nombreModelo}`);
        continue;
      }
      for (const campo of Object.keys(campos)) {
        if (!modelo.rawAttributes[campo]) {
          problemas.push(`${nombreModelo}.${campo} no existe`);
        }
      }
    }

    expect(problemas).toEqual([]);
  });

  test('plantaId nunca se valida como referencia: viene de la sesión', () => {
    for (const campos of Object.values(REFERENCIAS)) {
      expect(campos.plantaId).toBeUndefined();
    }
  });
});
