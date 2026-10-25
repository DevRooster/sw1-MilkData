const { Op } = require('sequelize');
const { app, request, login, auth, tokenForRole, cleanupTestUsers, closeDatabase, plantaPrincipal } = require('../helpers/auth');
const { Producto } = require('../../src/entities');

const sufijo = `p${Date.now().toString(36)}`;
let token;
let planta;
const creados = [];

beforeAll(async () => {
  token = await login();
  planta = await plantaPrincipal();
});

afterAll(async () => {
  await Producto.destroy({ where: { id: creados } });
  // Los productos creados con `nombre: Operador <sufijo>` se borran por nombre.
  await Producto.destroy({ where: { nombre: { [Op.like]: `%${sufijo}%` } } });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

async function crearProducto(extra = {}) {
  const nombre = `Producto ${sufijo} ${Math.random().toString(36).slice(2, 7)}`;
  const response = await request(app).post('/productos').set(auth(token)).send({
    nombre, unidadMedida: 'kg', precioVenta: 18.5, ...extra,
  });
  if (response.body.data && response.body.data.item) {
    creados.push(response.body.data.item.id);
  }
  return response;
}

describe('Tabla producto', () => {
  test('existe con las columnas esperadas', async () => {
    const { sequelize } = require('../../src/config/database.config');
    const columnas = await sequelize.getQueryInterface().describeTable('producto');

    for (const columna of ['id', 'planta_id', 'nombre', 'descripcion', 'unidad_medida', 'precio_venta', 'imagen', 'estado']) {
      expect(columnas[columna]).toBeTruthy();
    }
    expect(columnas.planta_id.allowNull).toBe(false);
  });
});

describe('CRUD de productos', () => {
  test('POST crea y devuelve 201 con plantaId', async () => {
    const response = await crearProducto();

    expect(response.statusCode).toBe(201);
    expect(response.body.data.item.precioVenta).toBe(18.5);
    expect(response.body.data.item.plantaId).toBe(planta.id);
  });

  test('imagen es opcional y se guarda como URL', async () => {
    const conImagen = await crearProducto({ imagen: 'https://cdn.milkdata.com/productos/queso.png' });
    expect(conImagen.body.data.item.imagen).toBe('https://cdn.milkdata.com/productos/queso.png');

    const sinImagen = await crearProducto();
    expect(sinImagen.body.data.item.imagen).toBeNull();
  });

  test('precioVenta se devuelve como numero, no como string decimal', async () => {
    const response = await crearProducto({ precioVenta: 12.75 });
    expect(typeof response.body.data.item.precioVenta).toBe('number');
  });

  test('precioVenta negativo se rechaza con 400', async () => {
    const response = await request(app).post('/productos').set(auth(token)).send({
      nombre: `Negativo ${sufijo}`, precioVenta: -5,
    });

    expect(response.statusCode).toBe(400);
  });

  test('nombre vacío se rechaza con 400', async () => {
    const response = await request(app).post('/productos').set(auth(token)).send({ nombre: '', precioVenta: 10 });

    expect(response.statusCode).toBe(400);
  });

  test('GET lista, GET por id, PUT y DELETE funcionan', async () => {
    const creado = await crearProducto();
    const id = creado.body.data.item.id;

    expect((await request(app).get('/productos').set(auth(token))).statusCode).toBe(200);
    expect((await request(app).get(`/productos/${id}`).set(auth(token))).body.data.item.id).toBe(id);

    const actualizado = await request(app).put(`/productos/${id}`).set(auth(token)).send({
      nombre: 'Renombrado', precioVenta: 25, imagen: 'https://cdn.milkdata.com/nuevo.jpg',
    });
    expect(actualizado.body.data.item.precioVenta).toBe(25);
    expect(actualizado.body.data.item.imagen).toBe('https://cdn.milkdata.com/nuevo.jpg');

    expect((await request(app).delete(`/productos/${id}`).set(auth(token))).statusCode).toBe(200);
    expect((await request(app).get(`/productos/${id}`).set(auth(token))).statusCode).toBe(404);
  });

  test('los id inexistentes responden 404', async () => {
    expect((await request(app).get('/productos/99999999').set(auth(token))).statusCode).toBe(404);
    expect((await request(app).put('/productos/99999999').set(auth(token)).send({})).statusCode).toBe(404);
    expect((await request(app).delete('/productos/99999999').set(auth(token))).statusCode).toBe(404);
  });

  test('PUT /:id/imagen asigna, quita y valida', async () => {
    const creado = await crearProducto();
    const id = creado.body.data.item.id;

    const asignar = await request(app).put(`/productos/${id}/imagen`).set(auth(token))
      .send({ imagen: 'https://cdn.milkdata.com/productos/queso-fresco.png' });
    expect(asignar.body.data.item.imagen).toBe('https://cdn.milkdata.com/productos/queso-fresco.png');

    const quitar = await request(app).put(`/productos/${id}/imagen`).set(auth(token)).send({ imagen: null });
    expect(quitar.body.data.item.imagen).toBeNull();

    expect((await request(app).put(`/productos/${id}/imagen`).set(auth(token)).send({})).statusCode).toBe(400);
  });

  test('GET por nombre filtra el producto', async () => {
    const nombre = `Filtro ${sufijo}`;
    await crearProducto({ nombre });

    const response = await request(app).get(`/productos/nombre/${encodeURIComponent(nombre)}`).set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.item.nombre).toBe(nombre);
  });
});

describe('Permisos sobre productos', () => {
  test('exige token', async () => {
    expect((await request(app).get('/productos')).statusCode).toBe(401);
  });

  test('operador puede escribir', async () => {
    const tokenOperador = await tokenForRole('operador', sufijo);
    const nombre = `Operador ${sufijo}`;

    const response = await request(app).post('/productos').set(auth(tokenOperador)).send({
      nombre, precioVenta: 5,
    });

    expect(response.statusCode).toBe(201);
    await Producto.destroy({ where: { nombre } });
  });

  test('laboratorio lee pero no escribe', async () => {
    const tokenLab = await tokenForRole('laboratorio', sufijo);

    expect((await request(app).get('/productos').set(auth(tokenLab))).statusCode).toBe(200);
    const escritura = await request(app).post('/productos').set(auth(tokenLab)).send({
      nombre: `Bloqueado ${sufijo}`, precioVenta: 5,
    });
    expect(escritura.statusCode).toBe(403);
  });

  test('proveedor lee pero no escribe', async () => {
    const tokenProv = await tokenForRole('proveedor', sufijo);

    expect((await request(app).get('/productos').set(auth(tokenProv))).statusCode).toBe(200);
    expect((await request(app).post('/productos').set(auth(tokenProv)).send({
      nombre: `Prohibido ${sufijo}`, precioVenta: 5,
    })).statusCode).toBe(403);
  });
});
