/**
 * Paginación de los listados.
 *
 * El móvil pide páginas de 10 porque la pantalla es pequeña. Estas pruebas
 * fijan el contrato: qué se devuelve, qué pasa con valores inválidos y que el
 * aislamiento por planta siga aplicando.
 */
const { app, request, tokenForRole, auth, cleanupTestUsers, closeDatabase } = require('../helpers/auth');
const { Planta } = require('../../src/entities');
const { POR_PAGINA, LIMITE_MAXIMO } = require('../../src/config/pagination.config');
const { crearProveedor, limpiar } = require('../helpers/rutas');

const sufijo = `pag${Date.now().toString(36)}`;
const TOTAL = 25;

let planta;
let token;
let tokenAjeno;
let plantaAjena;

beforeAll(async () => {
  planta = await Planta.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  token = await tokenForRole('admin', sufijo);

  plantaAjena = await Planta.create({
    nombre: `Ajena ${sufijo}`, codigo: `P-${sufijo}`, activo: true,
  });
  tokenAjeno = await tokenForRole('admin', sufijo, plantaAjena.id);

  // Los proveedores del seed ocupan las primeras páginas, así que los de esta
  // suite se crean con un orden que los vuelve localizables.
  for (let i = 0; i < TOTAL; i += 1) {
    await crearProveedor({ planta, sufijo, orden: i });
  }
});

afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await limpiar({ plantaId: plantaAjena.id, sufijo });
  await cleanupTestUsers(sufijo);
  await closeDatabase();
});

/** Cuenta cuántos proveedores de la suite hay en cada página. */
async function paginaDeProveedores(numero, limite) {
  const r = await request(app)
    .get(`/proveedores?pagina=${numero}&limite=${limite}`)
    .set(auth(token));
  expect(r.statusCode).toBe(200);
  return r.body.data;
}

describe('Contrato de la paginacion', () => {
  test('sin parametros devuelve la primera pagina del tamano por defecto', async () => {
    const r = await request(app).get('/proveedores').set(auth(token));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.items.length).toBeLessThanOrEqual(POR_PAGINA);
    expect(r.body.data.paginacion).toMatchObject({
      pagina: 1,
      limite: POR_PAGINA,
      totalPaginas: expect.any(Number),
      tieneAnterior: false,
    });
  });

  test('el total cuenta todos los registros, no solo los de la pagina', async () => {
    const { paginacion } = await paginaDeProveedores(1, 5);

    expect(paginacion.total).toBeGreaterThanOrEqual(TOTAL);
    expect(paginacion.totalPaginas).toBe(Math.ceil(paginacion.total / 5));
  });

  test('las paginas consecutivas no se repiten', async () => {
    const primera = await paginaDeProveedores(1, 5);
    const segunda = await paginaDeProveedores(2, 5);

    expect(primera.paginacion.tieneSiguiente).toBe(true);
    expect(segunda.paginacion.tieneAnterior).toBe(true);

    const ids = (p) => p.items.map((x) => x.id);
    const comunes = ids(primera).filter((id) => ids(segunda).includes(id));
    expect(comunes).toEqual([]);
  });

  test('la ultima pagina marca que no hay siguiente', async () => {
    const una = await paginaDeProveedores(1, POR_PAGINA);
    const ultima = await paginaDeProveedores(una.paginacion.totalPaginas, POR_PAGINA);

    expect(ultima.paginacion.tieneSiguiente).toBe(false);
    expect(ultima.paginacion.tieneAnterior).toBe(true);
  });

  test('una pagina mas alla del final sale vacia, no da error', async () => {
    const { items, paginacion } = await paginaDeProveedores(9999, 10);

    expect(items).toEqual([]);
    expect(paginacion.total).toBeGreaterThan(0);
    expect(paginacion.tieneSiguiente).toBe(false);
  });

  test('el limite es ajustable por el cliente', async () => {
    const diez = await paginaDeProveedores(1, 10);
    const veinte = await paginaDeProveedores(1, 20);

    expect(veinte.items.length).toBeGreaterThan(diez.items.length);
    expect(veinte.paginacion.limite).toBe(20);
    // Mismo total: solo cambia cuántas filas entran en la respuesta.
    expect(veinte.paginacion.total).toBe(diez.paginacion.total);
  });
});

describe('Valores de pagina y limite invalidos', () => {
  test.each([
    ['pagina=0', 'pagina'],
    ['pagina=-1', 'pagina'],
    ['pagina=abc', 'pagina'],
    ['pagina=1.5', 'pagina'],
    ['limite=0', 'limite'],
    ['limite=-5', 'limite'],
    ['limite=xyz', 'limite'],
  ])('%s responde 400', async (query, campo) => {
    const r = await request(app).get(`/proveedores?${query}`).set(auth(token));

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toContain(campo);
  });

  test('un limite por encima del maximo responde 400', async () => {
    const r = await request(app)
      .get(`/proveedores?limite=${LIMITE_MAXIMO + 1}`)
      .set(auth(token));

    expect(r.statusCode).toBe(400);
    expect(r.body.message).toMatch(/no puede ser mayor/);
  });

  test('el limite maximo si se acepta', async () => {
    const r = await request(app)
      .get(`/proveedores?limite=${LIMITE_MAXIMO}`)
      .set(auth(token));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.paginacion.limite).toBe(LIMITE_MAXIMO);
  });
});

describe('La paginacion no rompe el aislamiento', () => {
  test('el total de una planta no incluye los de otra', async () => {
    const mia = await request(app).get('/proveedores').set(auth(token));
    const ajena = await request(app).get('/proveedores').set(auth(tokenAjeno));

    expect(mia.body.data.paginacion.total).toBeGreaterThan(ajena.body.data.paginacion.total);
    expect(ajena.body.data.paginacion.total).toBe(0);
  });

  test('recorrer paginas nunca revela registros de otra planta', async () => {
    for (let pagina = 1; pagina <= 4; pagina += 1) {
      const r = await request(app)
        .get(`/proveedores?pagina=${pagina}&limite=5`)
        .set(auth(tokenAjeno));

      expect(r.body.data.items).toEqual([]);
    }
  });
});

describe('Los filtros por ruta tambien paginan', () => {
  test('un filtro devuelve items con su bloque de paginacion', async () => {
    const zona = await require('../../src/entities').Zona.findOne({
      where: { plantaId: planta.id },
    });

    const r = await request(app)
      .get(`/proveedores/zona/${zona.id}?limite=5`)
      .set(auth(token));

    expect(r.statusCode).toBe(200);
    expect(Array.isArray(r.body.data.items)).toBe(true);
    expect(r.body.data.paginacion.limite).toBe(5);
    expect(r.body.data.filtro).toEqual({ campo: 'zonaId', valor: String(zona.id) });
  });

  test('un filtro que devuelve un solo registro va en item, sin paginacion', async () => {
    const propio = await crearProveedor({ planta, sufijo, orden: 99 });

    const r = await request(app)
      .get(`/proveedores/dni/${propio.dni}`)
      .set(auth(token));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.dni).toBe(propio.dni);
    expect(r.body.data.items).toBeUndefined();
    expect(r.body.data.paginacion).toBeUndefined();
  });
});
