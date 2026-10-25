/**
 * El total y la paginación de `/rutas`.
 *
 * El listado trae el número de paradas de cada ruta, y para eso incluye la
 * relación `paradas`. Esa relación es un `hasMany`, así que el `JOIN` multiplica
 * las filas: una ruta con tres paradas aparece tres veces. Si el total cuenta
 * filas en vez de rutas, anuncia más rutas de las que hay, y las páginas salen
 * raras.
 *
 * Medido: con cuatro rutas y cinco paradas, la API anunciaba `total: 6` y con
 * `limite: 3` repartía las cuatro rutas en dos páginas de tres y una, como si
 * fueran seis.
 *
 * ---
 *
 * Las rutas se crean con `crearEscenario`, el helper de la suite, y no a mano:
 * `ruta_parada.proveedor_id` es obligatorio, y una parada sin proveedor no es
 * una parada —es una fila que la base no acepta—. Si esta prueba fabricara sus
 * propias paradas, estaría midiendo un escenario que no existe.
 */

const { app, request, tokenForRole, auth, closeDatabase } = require('../helpers/auth');
const { Planta } = require('../../src/entities');
const { crearEscenario, limpiar } = require('../helpers/rutas');

const sufijo = `conteo${Date.now().toString(36)}`;

/** Cuántas paradas tiene cada ruta creada: unas multiplican y otras no. */
const PARADAS_POR_RUTA = [0, 1, 3];

let planta;
let tokenAdmin;
let escenarios;

/** Una página de `/rutas`, ya comprobada. */
async function paginaDeRutas(query = '') {
  const r = await request(app).get(`/rutas${query}`).set(auth(tokenAdmin));
  expect(r.statusCode).toBe(200);
  expect(r.body.success).toBe(true);
  return r.body.data;
}

beforeAll(async () => {
  planta = await Planta.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  tokenAdmin = await tokenForRole('admin', sufijo);

  escenarios = [];
  for (let i = 0; i < PARADAS_POR_RUTA.length; i += 1) {
    // `crearEscenario` crea zona, ruta, paradas y proveedores. Con cero paradas
    // deja la zona y la ruta igualmente, que es justo el caso que hace falta.
    // eslint-disable-next-line no-await-in-loop
    const escenario = await crearEscenario({
      planta,
      sufijo: `${sufijo}${i}`,
      paradas: PARADAS_POR_RUTA[i],
    });
    escenarios.push(escenario);
  }
});

afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await closeDatabase();
});

/** Los códigos de las tres rutas que crea esta prueba. */
const codigos = () => escenarios.map((e) => e.ruta.codigo);

/** Las tres rutas de esta prueba, tal como las devuelve el listado. */
function misRutas(items) {
  return items.filter((r) => codigos().includes(r.codigo));
}

describe('El total de rutas cuenta rutas, no filas del join', () => {
  test('el total no crece con las paradas que tiene cada ruta', async () => {
    const { paginacion, items } = await paginaDeRutas('?pagina=1&limite=100');

    const mias = misRutas(items);
    expect(mias).toHaveLength(3);

    // El include se conserva: el listado sigue enseñando cuántas paradas hay.
    expect(mias.map((r) => r.paradas).sort()).toEqual([0, 1, 3]);

    // Y el total es exactamente el número de rutas que hay. Si sumase las
    // paradas, saldría más.
    expect(paginacion.total).toBe(items.length);
  });

  test('con un limite menor que las rutas, el total sigue siendo el de todas', async () => {
    const todo = await paginaDeRutas('?pagina=1&limite=100');
    const pagina = await paginaDeRutas('?pagina=1&limite=2');

    expect(pagina.paginacion.total).toBe(todo.paginacion.total);
    expect(pagina.items).toHaveLength(2);
  });
});

describe('Paginar rutas con paradas de por medio no pierde ninguna', () => {
  test('recorrer todas las paginas devuelve cada ruta una vez', async () => {
    const primera = await paginaDeRutas('?pagina=1&limite=2');
    const { total, totalPaginas } = primera.paginacion;
    expect(totalPaginas).toBeGreaterThan(1);

    const vistas = [];
    for (let pagina = 1; pagina <= totalPaginas; pagina += 1) {
      // eslint-disable-next-line no-await-in-loop
      const { items } = await paginaDeRutas(`?pagina=${pagina}&limite=2`);
      vistas.push(...items.map((r) => r.id));
    }

    // Sin repeticiones: ese era el síntoma de contar filas del join.
    expect(new Set(vistas).size).toBe(vistas.length);
    // Y sin pérdidas: entre todas las páginas salen todas las rutas.
    expect(vistas.length).toBe(total);
  });

  test('una pagina de mas alla del final sale vacia, no repite la ultima', async () => {
    const primera = await paginaDeRutas('?pagina=1&limite=2');
    const final = await paginaDeRutas(`?pagina=${primera.paginacion.totalPaginas + 5}&limite=2`);

    expect(final.items).toHaveLength(0);
    expect(final.paginacion.total).toBe(primera.paginacion.total);
  });

  test('el totalPaginas sale de las rutas, no de las paradas', async () => {
    const conDos = await paginaDeRutas('?pagina=1&limite=2');
    const conTodos = await paginaDeRutas('?pagina=1&limite=100');

    const esperado = Math.ceil(conTodos.paginacion.total / 2);
    expect(conDos.paginacion.totalPaginas).toBe(esperado);
  });
});

describe('El total de rutas tambien vale con filtro', () => {
  test('una busqueda que no encuentra nada da total cero', async () => {
    const { paginacion, items } = await paginaDeRutas('?pagina=1&limite=10&busqueda=nomatchxyz');

    expect(paginacion.total).toBe(0);
    expect(items).toHaveLength(0);
  });

  test('una busqueda da un total acorde con lo que devuelve', async () => {
    // El total tiene que ser el de lo que coincide con el filtro, no el de toda
    // la planta: si contase filas del join, saldría inflado también aquí.
    const todas = await paginaDeRutas('?pagina=1&limite=100');
    const filtradas = await paginaDeRutas(
      `?pagina=1&limite=100&busqueda=${encodeURIComponent(codigos()[0])}`
    );

    expect(filtradas.items.length).toBeGreaterThan(0);
    expect(filtradas.paginacion.total).toBe(filtradas.items.length);
    expect(filtradas.paginacion.total).toBeLessThan(todas.paginacion.total);
  });
});
