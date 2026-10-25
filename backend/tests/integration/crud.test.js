const {
  app, request, login, auth, tokenForRole, cleanupTestUsers, closeDatabase, plantaPrincipal,
} = require('../helpers/auth');
const { Unidad, Zona, Proveedor } = require('../../src/entities');

const sufijo = `c${Date.now().toString(36)}`;
let token;
let planta;
const correos = [];

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();
});

/** Ids de las filas creadas por la API, para borrarlas al terminar. */
const ids = {
  recoleccion: [],
  control_calidad: [],
  notificacion: [],
  asistencia: [],
};

/**
 * Tablas cuya columna de texto identifica las filas creadas por esta suite.
 * Las paradas de una ruta se van solas: `ruta_parada.ruta_id` es ON DELETE CASCADE.
 */
const LIMPIEZA = [
  ['notificacion', 'titulo'],
  ['asistencia', 'evento'],
  ['proveedor', 'codigo'],
  ['ruta', 'codigo'],
  ['zona', 'nombre'],
  ['unidad', 'nombre'],
];

afterAll(async () => {
  const { sequelize } = require('../../src/config/database.config');

  await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');

  // Las recolecciones se borran por id porque las crea el admin, cuyo email
  // no lleva el sufijo y no sirve como marca.
  for (const [tabla, registros] of Object.entries(ids)) {
    if (registros.length) {
      await sequelize.query(`DELETE FROM ${tabla} WHERE id IN (${registros.join(',')})`);
    }
  }

  for (const [tabla, columna] of LIMPIEZA) {
    await sequelize.query(`DELETE FROM ${tabla} WHERE ${columna} LIKE :s`, {
      replacements: { s: `%${sufijo}%` },
    });
  }

  await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

const marca = () => `${sufijo}${Math.random().toString(36).slice(2, 6)}`;

async function crearUnidad(extra = {}) {
  const nombre = `Unidad ${sufijo} ${marca()}`;
  const response = await request(app).post('/unidades').set(auth(token)).send({
    nombre, tipo: 'furgon', capacidad: 500, ...extra,
  });
  return response;
}

describe('CRUD de unidades', () => {
  test('POST crea y devuelve 201 con el trace de capas', async () => {
    const response = await crearUnidad();

    expect(response.statusCode).toBe(201);
    expect(response.body.data.item.nombre).toContain(sufijo);
    expect(response.body.data.item.plantaId).toBe(planta.id);
    expect(response.body.data.layerTrace).toEqual(['routes', 'controller', 'service', 'repository']);
  });

  test('GET lista devuelve los registros creados', async () => {
    await crearUnidad();
    const response = await request(app).get('/unidades').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.items.some((u) => u.nombre.includes(sufijo))).toBe(true);
  });

  test('GET por id devuelve el registro', async () => {
    const creado = await crearUnidad();
    const response = await request(app).get(`/unidades/${creado.body.data.item.id}`).set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.id).toBe(creado.body.data.item.id);
  });

  test('PUT actualiza el registro', async () => {
    const creado = await crearUnidad();
    const response = await request(app)
      .put(`/unidades/${creado.body.data.item.id}`)
      .set(auth(token))
      .send({ capacidad: 999 });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.capacidad).toBe(999);
  });

  test('DELETE elimina y luego responde 404', async () => {
    const creado = await crearUnidad();
    const id = creado.body.data.item.id;

    expect((await request(app).delete(`/unidades/${id}`).set(auth(token))).statusCode).toBe(200);
    expect((await request(app).get(`/unidades/${id}`).set(auth(token))).statusCode).toBe(404);
  });

  test('los id inexistentes responden 404 en GET, PUT y DELETE', async () => {
    expect((await request(app).get('/unidades/99999999').set(auth(token))).statusCode).toBe(404);
    expect((await request(app).put('/unidades/99999999').set(auth(token)).send({})).statusCode).toBe(404);
    expect((await request(app).delete('/unidades/99999999').set(auth(token))).statusCode).toBe(404);
  });

  test('GET por tipo filtra las unidades', async () => {
    await crearUnidad({ tipo: 'motocarga' });

    const response = await request(app).get('/unidades/tipo/motocarga').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.filtro).toEqual({ campo: 'tipo', valor: 'motocarga' });
    expect(response.body.data.items.every((u) => u.tipo === 'motocarga')).toBe(true);
  });

  test('GET por nombre devuelve un unico item', async () => {
    const creado = await crearUnidad();
    const nombre = creado.body.data.item.nombre;

    const response = await request(app).get(`/unidades/nombre/${encodeURIComponent(nombre)}`).set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.nombre).toBe(nombre);
  });

  test('POST con referencia inexistente responde 400', async () => {
    const response = await request(app).post('/zonas').set(auth(token)).send({
      nombre: `Zona ${sufijo} mala`, unidadId: 99999999,
    });

    expect(response.statusCode).toBe(400);
  });

  test('POST con valor unico duplicado responde 400', async () => {
    const dni = `D${sufijo}`;
    const cuerpo = { nombre: 'Dup', apellido: 'Test', dni, codigo: `DUP-${dni}` };

    const primero = await request(app).post('/proveedores').set(auth(token)).send(cuerpo);
    expect(primero.statusCode).toBe(201);

    const duplicado = await request(app).post('/proveedores').set(auth(token)).send(cuerpo);
    expect(duplicado.statusCode).toBe(400);
    expect(duplicado.body.errors).toEqual(['Valor duplicado']);

    await request(app).delete(`/proveedores/${primero.body.data.item.id}`).set(auth(token));
  });
});

describe('CRUD de zonas', () => {
  // La zona ya no lleva el texto `ruta`: apunta a la entidad `ruta`, que es la
  // que tiene las paradas ordenadas.
  async function crearRuta(nombre) {
    const r = await request(app).post('/rutas').set(auth(token)).send({
      nombre,
      codigo: nombre.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 20),
    });
    return r.body.data.item;
  }

  async function crearZona(extra = {}) {
    const nombre = `Zona ${sufijo} ${marca()}`;
    const ruta = await crearRuta(`Ruta ${nombre}`);
    const response = await request(app)
      .post('/zonas')
      .set(auth(token))
      .send({ nombre, rutaId: ruta.id, ...extra });
    return response;
  }

  test('POST, PUT y DELETE funcionan de punta a punta', async () => {
    const creado = await crearZona();
    expect(creado.statusCode).toBe(201);
    const id = creado.body.data.item.id;
    expect(creado.body.data.item.rutaId).toBeTruthy();

    const otraRuta = await crearRuta(`Nueva ${sufijo} ${marca()}`);
    const actualizado = await request(app).put(`/zonas/${id}`).set(auth(token)).send({ rutaId: otraRuta.id });
    expect(actualizado.statusCode).toBe(200);
    expect(actualizado.body.data.item.rutaId).toBe(otraRuta.id);

    expect((await request(app).delete(`/zonas/${id}`).set(auth(token))).statusCode).toBe(200);
    await request(app).delete(`/rutas/${otraRuta.id}`).set(auth(token));
  });

  test('los filtros por nombre y por unidad funcionan', async () => {
    const unidad = await crearUnidad();
    const nombreZona = `Zona Filtro ${sufijo} ${marca()}`;
    const ruta = await crearRuta(`Ruta filtro ${sufijo} ${marca()}`);
    const zona = await request(app).post('/zonas').set(auth(token)).send({
      nombre: nombreZona, rutaId: ruta.id, unidadId: unidad.body.data.item.id,
    });
    expect(zona.statusCode).toBe(201);

    const porNombre = await request(app).get(`/zonas/nombre/${encodeURIComponent(nombreZona)}`).set(auth(token));
    expect(porNombre.statusCode).toBe(200);
    expect(porNombre.body.data.item.nombre).toBe(nombreZona);

    const porUnidad = await request(app).get(`/zonas/unidad/${unidad.body.data.item.id}`).set(auth(token));
    expect(porUnidad.statusCode).toBe(200);
    expect(porUnidad.body.data.items.some((z) => z.id === zona.body.data.item.id)).toBe(true);

    await request(app).delete(`/zonas/${zona.body.data.item.id}`).set(auth(token));
    await request(app).delete(`/rutas/${ruta.id}`).set(auth(token));
  });
});

describe('CRUD de proveedores', () => {
  async function crearProveedor(extra = {}) {
    const dni = `T${marca()}`;
    const response = await request(app).post('/proveedores').set(auth(token)).send({
      nombre: 'Ana', apellido: 'García', dni, codigo: `COD-${dni}`, ...extra,
    });
    return response;
  }

  test('GET /proveedores responde 200 con la lista', async () => {
    const response = await request(app).get('/proveedores').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(Array.isArray(response.body.data.items)).toBe(true);
  });

  test('POST, GET por id, PUT y DELETE funcionan', async () => {
    const creado = await crearProveedor();
    expect(creado.statusCode).toBe(201);
    const id = creado.body.data.item.id;

    expect((await request(app).get(`/proveedores/${id}`).set(auth(token))).statusCode).toBe(200);

    const actualizado = await request(app).put(`/proveedores/${id}`).set(auth(token)).send({ telefono: '999888777' });
    expect(actualizado.statusCode).toBe(200);
    expect(actualizado.body.data.item.telefono).toBe('999888777');

    expect((await request(app).delete(`/proveedores/${id}`).set(auth(token))).statusCode).toBe(200);
  });

  test('los filtros por dni, codigo y zona funcionan', async () => {
    const creado = await crearProveedor();
    const { dni, codigo } = creado.body.data.item;

    const porDni = await request(app).get(`/proveedores/dni/${dni}`).set(auth(token));
    expect(porDni.statusCode).toBe(200);
    expect(porDni.body.data.item.dni).toBe(dni);

    const porCodigo = await request(app).get(`/proveedores/codigo/${codigo}`).set(auth(token));
    expect(porCodigo.statusCode).toBe(200);
    expect(porCodigo.body.data.item.codigo).toBe(codigo);

    const porZonaAjena = await request(app).get('/proveedores/zona/99999999').set(auth(token));
    expect(porZonaAjena.statusCode).toBe(200);
    expect(porZonaAjena.body.data.items).toHaveLength(0);
  });

  test('PUT /:id/imagen asigna, quita y valida la imagen', async () => {
    const creado = await crearProveedor();
    const id = creado.body.data.item.id;

    const asignar = await request(app)
      .put(`/proveedores/${id}/imagen`).set(auth(token))
      .send({ imagen: 'https://cdn.milkdata.com/proveedores/luis.jpg' });
    expect(asignar.statusCode).toBe(200);
    expect(asignar.body.data.item.imagen).toBe('https://cdn.milkdata.com/proveedores/luis.jpg');

    const quitar = await request(app)
      .put(`/proveedores/${id}/imagen`).set(auth(token))
      .send({ imagen: null });
    expect(quitar.body.data.item.imagen).toBeNull();

    const sinCampo = await request(app).put(`/proveedores/${id}/imagen`).set(auth(token)).send({});
    expect(sinCampo.statusCode).toBe(400);
  });
});

describe('CRUD de recolecciones, calidad, notificaciones y asistencias', () => {
  let ctx;

  beforeAll(async () => {
    const unidad = await request(app).post('/unidades').set(auth(token)).send({
      nombre: `Unidad E ${sufijo}`, tipo: 'furgon', capacidad: 100,
    });
    const zona = await request(app).post('/zonas').set(auth(token)).send({
      nombre: `Zona E ${sufijo}`, ruta: 'R', unidadId: unidad.body.data.item.id,
    });
    const proveedor = await request(app).post('/proveedores').set(auth(token)).send({
      nombre: 'Luis', apellido: 'Test', dni: `E${marca()}`, codigo: `E-${sufijo}`,
      zonaId: zona.body.data.item.id,
    });
    const payload = await require('../../src/security/auth.service').verifyToken(token);

    ctx = {
      unidadId: unidad.body.data.item.id,
      zonaId: zona.body.data.item.id,
      proveedorId: proveedor.body.data.item.id,
      usuarioId: payload.sub,
    };
  });

  test('recolecciones: crear, filtrar por proveedor, zona y fecha, actualizar y eliminar', async () => {
    const creado = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: ctx.proveedorId, zonaId: ctx.zonaId, unidadId: ctx.unidadId,
      usuarioId: ctx.usuarioId, cantidad: 12, fecha: '2026-09-08', registradoEn: 'campo',
    });

    expect(creado.statusCode).toBe(201);
    const id = creado.body.data.item.id;
    ids.recoleccion.push(id);
    expect(creado.body.data.item.plantaId).toBe(planta.id);

    for (const ruta of [
      `/recolecciones/proveedor/${ctx.proveedorId}`,
      `/recolecciones/zona/${ctx.zonaId}`,
      '/recolecciones/fecha/2026-09-08',
    ]) {
      const response = await request(app).get(ruta).set(auth(token));
      expect(response.statusCode).toBe(200);
      expect(response.body.data.items.some((r) => r.id === id)).toBe(true);
    }

    const actualizado = await request(app).put(`/recolecciones/${id}`).set(auth(token)).send({ cantidad: 20 });
    expect(actualizado.body.data.item.cantidad).toBe(20);

    expect((await request(app).delete(`/recolecciones/${id}`).set(auth(token))).statusCode).toBe(200);
  });

  test('calidad: crear, leer por recoleccion y eliminar', async () => {
    const recoleccion = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: ctx.proveedorId, zonaId: ctx.zonaId, unidadId: ctx.unidadId,
      usuarioId: ctx.usuarioId, cantidad: 10, fecha: '2026-09-09', registradoEn: 'planta',
    });
    ids.recoleccion.push(recoleccion.body.data.item.id);

    const creado = await request(app).post('/calidad').set(auth(token)).send({
      recoleccionId: recoleccion.body.data.item.id, usuarioId: ctx.usuarioId,
      grasa: 3.5, proteina: 3.2, ph: 6.6, resultado: 'pura',
    });
    expect(creado.statusCode).toBe(201);
    ids.control_calidad.push(creado.body.data.item.id);

    const porRecoleccion = await request(app)
      .get(`/calidad/recoleccion/${recoleccion.body.data.item.id}`).set(auth(token));
    expect(porRecoleccion.statusCode).toBe(200);
    expect(porRecoleccion.body.data.item.grasa).toBe(3.5);

    expect((await request(app).delete(`/calidad/${creado.body.data.item.id}`).set(auth(token))).statusCode).toBe(200);
  });

  test('notificaciones: crear, enviar y filtrar', async () => {
    const creada = await request(app).post('/notificaciones').set(auth(token)).send({
      proveedorId: ctx.proveedorId, usuarioId: ctx.usuarioId,
      tipo: 'reunion', titulo: 'Reunión', mensaje: 'Contenido',
    });
    expect(creada.statusCode).toBe(201);
    expect(creada.body.data.item.plantaId).toBe(planta.id);

    const enviada = await request(app).post('/notificaciones/enviar').set(auth(token)).send({
      proveedorId: ctx.proveedorId, tipo: 'capacitacion', titulo: 'Capacitación', mensaje: 'Contenido',
    });
    expect(enviada.statusCode).toBe(201);
    expect(enviada.body.data.item.enviada).toBe(true);
    ids.notificacion.push(enviada.body.data.item.id);

    expect((await request(app).get(`/notificaciones/proveedor/${ctx.proveedorId}`).set(auth(token))).statusCode).toBe(200);
    expect((await request(app).get('/notificaciones/tipo/reunion').set(auth(token))).statusCode).toBe(200);

    expect((await request(app).delete(`/notificaciones/${creada.body.data.item.id}`).set(auth(token))).statusCode).toBe(200);
  });

  test('asistencias: crear y filtrar por proveedor y evento', async () => {
    const evento = `evento-${sufijo}`;
    const creada = await request(app).post('/asistencias').set(auth(token)).send({
      proveedorId: ctx.proveedorId, usuarioId: ctx.usuarioId,
      evento, fecha: '2026-09-10', registradoPor: 'QR',
    });
    expect(creada.statusCode).toBe(201);
    ids.asistencia.push(creada.body.data.item.id);

    const porProveedor = await request(app).get(`/asistencias/proveedor/${ctx.proveedorId}`).set(auth(token));
    expect(porProveedor.statusCode).toBe(200);

    const porEvento = await request(app).get(`/asistencias/evento/${evento}`).set(auth(token));
    expect(porEvento.body.data.items[0].evento).toBe(evento);

    expect((await request(app).delete(`/asistencias/${creada.body.data.item.id}`).set(auth(token))).statusCode).toBe(200);
  });
});

describe('Autorización por rol', () => {
  const RUTAS = [
    'GET /plantas', 'GET /proveedores', 'GET /unidades', 'GET /zonas',
    'GET /recolecciones', 'GET /calidad', 'GET /notificaciones', 'GET /asistencias',
    'GET /productos', 'GET /reportes/contraste', 'GET /reportes/calidad',
  ];

  test.each(RUTAS)('%s exige token', async (ruta) => {
    const [metodo, path] = ruta.toLowerCase().split(' ');
    const response = await request(app)[metodo](path);

    expect(response.statusCode).toBe(401);
  });

  test('el rol proveedor no puede escribir recolecciones', async () => {
    const tokenProv = await tokenForRole('proveedor', sufijo);

    const response = await request(app).post('/recolecciones').set(auth(tokenProv)).send({ cantidad: 1 });

    expect(response.statusCode).toBe(403);
    expect(response.body.message).toMatch(/permisos/i);
  });

  test('el rol laboratorio no puede listar zonas', async () => {
    const tokenLab = await tokenForRole('laboratorio', sufijo);
    const response = await request(app).get('/zonas').set(auth(tokenLab));

    expect(response.statusCode).toBe(403);
  });

  test('el rol supervisor lee reportes pero no los escribe', async () => {
    const tokenSup = await tokenForRole('supervisor', sufijo);

    expect((await request(app).get('/reportes/contraste').set(auth(tokenSup))).statusCode).toBe(200);
  });

  test('el rol administrador accede a todo', async () => {
    expect((await request(app).get('/reportes/calidad').set(auth(token))).statusCode).toBe(200);
  });
});

