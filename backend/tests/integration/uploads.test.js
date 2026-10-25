const fs = require('fs/promises');
const path = require('path');
const { app, request, tokenForRole, auth, cleanupTestUsers, closeDatabase } = require('../helpers/auth');
const { Planta, Producto } = require('../../src/entities');
const { UPLOADS_ROOT, rutaEnDisco } = require('../../src/config/upload.config');

const sufijo = `img${Date.now().toString(36)}`;

/** PNG 1x1 válido. */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

let tokenAdmin;
let tokenAcopiador;
let planta;
let productoId;

const archivo = (buffer, nombre, tipo) => ({ archivo: buffer, nombre, tipo });

beforeAll(async () => {
  planta = await Planta.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  tokenAdmin = await tokenForRole('admin', sufijo);
  tokenAcopiador = await tokenForRole('acopiador', sufijo);

  const producto = await Producto.create({
    nombre: `Producto ${sufijo}`,
    precioVenta: 12.5,
    plantaId: planta.id,
    activo: true,
  });
  productoId = producto.id;
});

afterAll(async () => {
  const producto = await Producto.findByPk(productoId);
  if (producto) await producto.destroy();
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

describe('GET /uploads/api', () => {
  test('expone la configuración de imágenes', async () => {
    const r = await request(app).get('/uploads/api').set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.urlBase).toBe('/uploads');
    expect(r.body.data.recurso || r.body.data.recursos).toBeTruthy();
    expect(r.body.data.limiteBytes).toBeGreaterThan(0);
    expect(r.body.data.patron).toContain('uploads');
  });

  test('exige token', async () => {
    const r = await request(app).get('/uploads/api');
    expect(r.statusCode).toBe(401);
  });
});

describe('POST /uploads/api', () => {
  test('guarda el archivo y devuelve la ruta relativa', async () => {
    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto');

    expect(r.statusCode).toBe(201);
    const { imagen, bytes } = r.body.data;
    expect(imagen).toMatch(new RegExp(`^/uploads/${planta.id}/producto/[\\w-]+\\.png$`));
    expect(bytes).toBe(PNG.length);

    // El archivo existe en disco, dentro de uploads/ de la raíz del proyecto.
    const enDisco = rutaEnDisco(imagen);
    expect(enDisco).toBeTruthy();
    expect(enDisco.startsWith(path.resolve(UPLOADS_ROOT))).toBe(true);
    const stat = await fs.stat(enDisco);
    expect(stat.size).toBe(PNG.length);

    await fs.unlink(enDisco);
  });

  test('sirve la imagen desde el mismo origen', async () => {
    const subida = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto');
    const ruta = subida.body.data.imagen;

    const servido = await request(app).get(ruta);
    expect(servido.statusCode).toBe(200);
    expect(servido.headers['content-type']).toMatch(/image\/png/);
    expect(servido.body).toEqual(PNG);
    // No debe servirse como algo ejecutable.
    expect(servido.headers['x-content-type-options']).toBe('nosniff');

    await fs.unlink(rutaEnDisco(ruta));
  });

  test('con id, adjunta la imagen al registro y la guarda en la base', async () => {
    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto')
      .field('id', String(productoId));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.id).toBe(productoId);

    const enBase = await Producto.findByPk(productoId);
    expect(enBase.imagen).toBe(r.body.data.imagen);
    expect(enBase.imagen).toMatch(/^\/uploads\//);

    await fs.unlink(rutaEnDisco(enBase.imagen));
  });

  test('acepta jpeg, webp y gif', async () => {
    for (const [tipo, extension] of [
      ['image/jpeg', '.jpg'], ['image/webp', '.webp'], ['image/gif', '.gif'],
    ]) {
      const r = await request(app)
        .post('/uploads/api')
        .set(auth(tokenAdmin))
        .attach('archivo', PNG, { filename: `foto${extension}`, contentType: tipo })
        .field('recurso', 'producto');

      expect(r.statusCode).toBe(201);
      expect(r.body.data.imagen.endsWith(extension)).toBe(true);
      await fs.unlink(rutaEnDisco(r.body.data.imagen));
    }
  });

  test('rechaza un tipo de archivo no permitido', async () => {
    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', Buffer.from('contenido'), { filename: 'nota.txt', contentType: 'text/plain' })
      .field('recurso', 'producto');

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/no permitido/);
  });

  test('rechaza un recurso desconocido', async () => {
    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'inventario');

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/inv/i);
  });

  test('rechaza una petición sin archivo', async () => {
    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .field('recurso', 'producto');

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/archivo/i);
  });

  test('404 si el registro no existe, y no deja el archivo huérfano', async () => {
    const carpeta = path.join(UPLOADS_ROOT, String(planta.id), 'producto');
    const antes = (await fs.readdir(carpeta).catch(() => [])).sort();

    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto')
      .field('id', '99999999');

    expect(r.statusCode).toBe(404);

    // No se compares con una lista vacía: la carpeta puede tener imágenes de
    // otros usos. Lo que importa es que este intento no añadió ningún archivo.
    const despues = (await fs.readdir(carpeta).catch(() => [])).sort();
    expect(despues).toEqual(antes);
  });

  test('no adjunta a un registro de otra planta', async () => {
    const otra = await Planta.create({
      nombre: `Ajena ${sufijo}`, codigo: `I-${sufijo}`, activo: true,
    });
    const suyo = await Producto.create({
      nombre: `Suyo ${sufijo}`, precioVenta: 1, plantaId: otra.id, activo: true,
    });

    const r = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto')
      .field('id', String(suyo.id));

    expect(r.statusCode).toBe(404);
    const intacto = await Producto.findByPk(suyo.id);
    expect(intacto.imagen).toBeNull();

    await suyo.destroy();
    await otra.destroy();
  });
});

describe('DELETE /uploads/api', () => {
  test('desvincula y borra el archivo', async () => {
    const subida = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAdmin))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto')
      .field('id', String(productoId));
    const imagen = subida.body.data.imagen;

    const r = await request(app)
      .delete('/uploads/api')
      .set(auth(tokenAdmin))
      .send({ imagen, recurso: 'producto', id: String(productoId) });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.eliminado).toBe(true);
    expect(r.body.data.desvinculado).toBe(true);

    const enBase = await Producto.findByPk(productoId);
    expect(enBase.imagen).toBeNull();

    await expect(fs.stat(rutaEnDisco(imagen))).rejects.toThrow();
  });

  test('no toca imágenes que la API no almacenó', async () => {
    const r = await request(app)
      .delete('/uploads/api')
      .set(auth(tokenAdmin))
      .send({ imagen: 'https://ejemplo.com/foto.png' });

    expect(r.statusCode).toBe(400);
    expect(r.body.data).toBeNull();
  });

  test('exige el campo imagen', async () => {
    const r = await request(app).delete('/uploads/api').set(auth(tokenAdmin)).send({});

    expect(r.statusCode).toBe(400);
  });
});

describe('Rutas de archivo maliciosas', () => {
  test('no permite escapar de la carpeta uploads', () => {
    expect(rutaEnDisco('/uploads/../../package.json')).toBeNull();
    expect(rutaEnDisco('/uploads/1/producto/../../../.env')).toBeNull();
    expect(rutaEnDisco('')).toBeNull();
    expect(rutaEnDisco(null)).toBeNull();
  });

  test('no trata una URL externa como archivo local', () => {
    // Sin esto, `path.resolve` construiría <uploads>/https:/... y la API
    // aceptaría borrar o servir algo que no le pertenece.
    expect(rutaEnDisco('https://ejemplo.com/foto.png')).toBeNull();
    expect(rutaEnDisco('http://ejemplo.com/foto.png')).toBeNull();
    expect(rutaEnDisco('file:///etc/passwd')).toBeNull();
    expect(rutaEnDisco('//servidor/compartido/foto.png')).toBeNull();
  });

  test('resuelve una ruta guardada dentro de la carpeta', () => {
    const resuelta = rutaEnDisco('/uploads/1/producto/foto.png');
    expect(resuelta).toBe(path.join(path.resolve(UPLOADS_ROOT), '1', 'producto', 'foto.png'));
  });
});

describe('Permisos', () => {
  test('el acopiador puede subir pero no borrar', async () => {
    const subida = await request(app)
      .post('/uploads/api')
      .set(auth(tokenAcopiador))
      .attach('archivo', PNG, { filename: 'foto.png', contentType: 'image/png' })
      .field('recurso', 'producto');
    expect(subida.statusCode).toBe(201);

    const borrar = await request(app)
      .delete('/uploads/api')
      .set(auth(tokenAcopiador))
      .send({ imagen: subida.body.data.imagen });
    expect(borrar.statusCode).toBe(403);

    await fs.unlink(rutaEnDisco(subida.body.data.imagen));
  });
});
