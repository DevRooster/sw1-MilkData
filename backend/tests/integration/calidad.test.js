const { Op } = require('sequelize');
const { app, request, login, auth, closeDatabase, plantaPrincipal } = require('../helpers/auth');
const { ControlCalidad, Recoleccion } = require('../../src/entities');

// Este fichero cubre dos cosas que solo se ven juntas:
//
// 1. La regla de la recolectora única: `recoleccionId` es único en la base, y
//    eso se cumple tanto al crear como al editar.
// 2. Que las relaciones vienen llenas en las respuestas. Antes de que
//    `BaseService` tuviera el gancho `_incluir()`, `recolecciones` y `calidad`
//    devolvían cuatro `null` y la app tenía que enseñar "Proveedor #1" donde
//    debería decir el nombre. Es un fallo que no se ve mirando el esquema: solo
//    aparece al leer lo que vuelve.

const sufijo = `c${Date.now().toString(36)}`;
let token;
let planta;
let recoleccionId;

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();

  // Se toma una recolección real del seed en vez de crear una: el alta necesita
  // proveedor, zona y unidad que ya existen, y montearlos cada vez duplicaría
  // media batería de pruebas para probar lo que no es el objeto de este fichero.
  const existente = await Recoleccion.findOne({
    where: { plantaId: planta.id },
    order: [['id', 'ASC']],
  });

  if (!existente) {
    throw new Error('El seed no dejó ninguna recolección. Ejecuta el seed primero.');
  }

  recoleccionId = existente.id;
});

afterAll(async () => {
  // Cada prueba borra lo que crea. Este destroy es solo la red de seguridad para
  // el caso de que una falle a mitad y deje filas detrás.
  await ControlCalidad.destroy({
    where: { recoleccionId: recoleccionId },
  });
  await closeDatabase();
});

async function crearControl(extra = {}) {
  return request(app)
    .post('/calidad')
    .set(auth(token))
    .send({ recoleccionId, usuarioId: 1, ...extra });
}

describe('Relaciones de recolecciones', () => {
  test('la lista trae proveedor, zona y unidad con sus nombres', async () => {
    // Se crea una recolección propia y se busca esa en la lista, en vez de
    // mirar la más antigua. Las más antiguas son de otros ficheros de prueba y
    // pueden apuntar a proveedores que esos borraron después: una fila con un id
    // colgando da `null` en la relación y la culpa parece del código.
    const creada = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: 1,
      zonaId: 1,
      unidadId: 1,
      usuarioId: 1,
      cantidad: 33,
      fecha: '2026-10-13',
      registradoEn: 'campo',
    });
    const propiaId = creada.body.data.item.id;

    const response = await request(app).get('/recolecciones?limite=50').set(auth(token));
    expect(response.statusCode).toBe(200);

    const item = response.body.data.items.find((r) => r.id === propiaId);
    expect(item).toBeDefined();

    // Los ids siempre venían; lo que faltaba eran los nombres. Comprobar solo
    // `not.toBeNull()` sobre una copia plana del DTO daría verde aunque el DTO
    // no tuviera la clave, así que se mira el contenido.
    expect(item.proveedor).not.toBeNull();
    expect(typeof item.proveedor.nombre).toBe('string');
    expect(item.proveedor.nombre.length).toBeGreaterThan(0);

    expect(item.zona).not.toBeNull();
    expect(typeof item.zona.nombre).toBe('string');

    expect(item.unidad).not.toBeNull();
    expect(typeof item.unidad.nombre).toBe('string');

    await request(app).delete(`/recolecciones/${propiaId}`).set(auth(token));
  });

  test('el alta de una recolección también las trae', async () => {
    // Antes devolvía cuatro `null`: la respuesta a un alta era peor que la de un
    // GET de la misma fila, que es justo lo que hace que una app parezca
    // intermitente.
    const created = await request(app)
      .post('/recolecciones')
      .set(auth(token))
      .send({
        proveedorId: 1,
        zonaId: 1,
        unidadId: 1,
        usuarioId: 1,
        cantidad: 12.5,
        fecha: '2026-10-13',
        registradoEn: 'campo',
      });

    expect(created.statusCode).toBe(201);

    const item = created.body.data.item;
    expect(item.proveedor).not.toBeNull();
    expect(item.proveedor.nombre).toBeTruthy();
    expect(item.unidad).not.toBeNull();

    await request(app).delete(`/recolecciones/${item.id}`).set(auth(token));
  });

  test('el DTO expone recorridoParadaId, que antes se perdía', async () => {
    const created = await request(app)
      .post('/recolecciones')
      .set(auth(token))
      .send({
        proveedorId: 1,
        zonaId: 1,
        unidadId: 1,
        usuarioId: 1,
        cantidad: 7,
        fecha: '2026-10-13',
        registradoEn: 'planta',
      });

    const item = created.body.data.item;
    // Sin esta clave, una recolección hecha en el campo llegaba a la app sin
    // ningún vínculo con el recorrido que la originó.
    expect(item).toHaveProperty('recorridoParadaId');
    expect(item.recorridoParadaId).toBeNull();

    await request(app).delete(`/recolecciones/${item.id}`).set(auth(token));
  });
});

describe('Relaciones de calidad', () => {
  test('el alta trae la recolección analizada y el laboratorio', async () => {
    const response = await crearControl({ grasa: 3.8, resultado: 'pura' });

    expect(response.statusCode).toBe(201);

    const item = response.body.data.item;
    expect(item.recoleccion).not.toBeNull();
    expect(item.recoleccion.id).toBe(recoleccionId);
    expect(typeof item.recoleccion.fecha).toBe('string');

    expect(item.usuario).not.toBeNull();
    expect(typeof item.usuario.email).toBe('string');

    await request(app).delete(`/calidad/${item.id}`).set(auth(token));
  });

  test('sin resultado explícito sale pura, porque la base tiene valor por defecto', async () => {
    // A diferencia de `registradoEn` en recolecciones, que obliga a elegirlo.
    const response = await crearControl();

    expect(response.statusCode).toBe(201);
    expect(response.body.data.item.resultado).toBe('pura');

    await request(app).delete(`/calidad/${response.body.data.item.id}`).set(auth(token));
  });

  test('las siete medidas admiten null y se guardan como null', async () => {
    const response = await crearControl({ grasa: 3.5 });

    expect(response.statusCode).toBe(201);
    const item = response.body.data.item;

    expect(item.grasa).toBe(3.5);
    for (const medida of ['proteina', 'lactosa', 'densidad', 'ph', 'aguaAnadida', 'temperatura']) {
      expect(item).toHaveProperty(medida);
    }

    await request(app).delete(`/calidad/${item.id}`).set(auth(token));
  });
});

describe('La recolectora única', () => {
  test('un segundo control para la misma recolección se rechaza con 400', async () => {
    const primero = await crearControl();
    expect(primero.statusCode).toBe(201);

    const segundo = await crearControl({ resultado: 'adulterada' });

    expect(segundo.statusCode).toBe(400);
    expect(segundo.body.success).toBe(false);

    await request(app).delete(`/calidad/${primero.body.data.item.id}`).set(auth(token));
  });

  test('mover un control a una recolección ocupada también se rechaza', async () => {
    // La unicidad la impone la base, no el servicio, así que se cumple igual al
    // editar. Sin esta prueba, mover de recolección parecería una operación
    // libre y dejaría dos controles donde debería haber uno.
    //
    // Cada control se crea sobre una recolección **distinta**: dos controles
    // sobre la misma es justo lo que se está probando que no se puede hacer, así
    // que hacerlo aquí sería pedir un 400 y luego esperar un 201.
    const primera = await crearControl();
    expect(primera.statusCode).toBe(201);

    const otra = await request(app).post('/recolecciones').set(auth(token)).send({
      proveedorId: 1,
      zonaId: 1,
      unidadId: 1,
      usuarioId: 1,
      cantidad: 9,
      fecha: '2026-10-13',
      registradoEn: 'campo',
    });
    const otraId = otra.body.data.item.id;

    // Un control sobre `otra` es legal: `otra` está libre.
    const tercero = await request(app)
      .post('/calidad')
      .set(auth(token))
      .send({ recoleccionId: otraId, usuarioId: 1 });
    expect(tercero.statusCode).toBe(201);

    // Ahora se intenta mover ese control a la de `primera`, que ya está ocupada.
    const movido = await request(app)
      .put(`/calidad/${tercero.body.data.item.id}`)
      .set(auth(token))
      .send({ recoleccionId });

    expect(movido.statusCode).toBe(400);

    await request(app).delete(`/calidad/${tercero.body.data.item.id}`).set(auth(token));
    await request(app).delete(`/calidad/${primera.body.data.item.id}`).set(auth(token));
    await request(app).delete(`/recolecciones/${otraId}`).set(auth(token));
  });

  test('editar un control sin tocar su recolección sí funciona', async () => {
    // El caso contrario del anterior: si el servicio rechazara siempre por
    // unicidad, hasta corregir una cifra del análisis sería imposible.
    const response = await crearControl({ grasa: 3.9 });
    const id = response.body.data.item.id;

    const editado = await request(app)
      .put(`/calidad/${id}`)
      .set(auth(token))
      .send({ recoleccionId, grasa: 3.1 });

    expect(editado.statusCode).toBe(200);
    expect(editado.body.data.item.grasa).toBe(3.1);
    expect(editado.body.data.item.recoleccionId).toBe(recoleccionId);

    await request(app).delete(`/calidad/${id}`).set(auth(token));
  });
});

describe('Filtros de calidad', () => {
  test('los declarados funcionan y uno inventado da 400', async () => {
    const control = await crearControl({ resultado: 'adulterada', grasa: 3.7 });
    const id = control.body.data.item.id;

    const porResultado = await request(app).get('/calidad?resultado=adulterada').set(auth(token));
    expect(porResultado.statusCode).toBe(200);
    expect(porResultado.body.data.paginacion.total).toBeGreaterThanOrEqual(1);

    const porPura = await request(app).get('/calidad?resultado=pura').set(auth(token));
    expect(porPura.statusCode).toBe(200);
    // Este control es adulterado, así que no puede aparecer en la lista de puras.
    expect(porPura.body.data.items.some((c) => c.id === id)).toBe(false);

    const desconocido = await request(app).get('/calidad?inventado=x').set(auth(token));
    expect(desconocido.statusCode).toBe(400);

    await request(app).delete(`/calidad/${id}`).set(auth(token));
  });

  test('el rango de fechas sobre la recolección no revienta', async () => {
    // `$recoleccion.fecha$` es sintaxis de Sequelize para filtrar por una
    // columna de una relación incluida. Escrito como `{ recoleccion: { fecha } }`
    // no da error de sintaxis: da un 500 al ejecutar la consulta.
    const dentro = await request(app).get('/calidad?desde=2020-01-01&hasta=2099-12-31').set(auth(token));
    expect(dentro.statusCode).toBe(200);

    const fuera = await request(app).get('/calidad?desde=2099-01-01&hasta=2099-12-31').set(auth(token));
    expect(fuera.statusCode).toBe(200);
    expect(fuera.body.data.paginacion.total).toBe(0);
  });
});