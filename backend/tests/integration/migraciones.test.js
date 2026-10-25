/**
 * El arranque no puede depender de datos que la app deja editar.
 *
 * La migración que registra la planta principal buscaba la planta por su código
 * `HUA`. Ese código es un campo más del formulario de Plantas, y el usuario lo
 * puede cambiar desde el móvil. Cuando lo cambió, la planta dejó de llamarse
 * `HUA`, la migración creyó que faltaba, intentó insertarla otra vez y reventó
 * contra el índice único de `nombre`:
 *
 *   SequelizeUniqueConstraintError: Duplicate entry 'Planta Ecológica Huata'
 *   for key 'planta.nombre'
 *
 * El servidor no arrancaba. La app entera se quedaba sin conexión, sin importar
 * qué módulo se abriera.
 *
 * ---
 *
 * La prueba va **en un proceso hijo y una base aparte**, no contra la base de la
 * suite, por dos razones:
 *
 * 1. Toca datos de verdad: hay que cambiar el código de una planta para
 *    reproducir el fallo. Si eso se hace en la base compartida y algo revienta
 *    antes de restaurar, las siguientes suites se encuentran sin planta y fallan
 *    todas —que es justo lo que pasó la primera vez—.
 * 2. Reproduce el arranque entero, con `scripts/db-sync.js`, que es lo que hace
 *    el servidor al encenderse. Una prueba que solo llame a `antesDe` a mano
 *    podría pasar mientras el arranque real revienta.
 */

const { execFileSync } = require('child_process');
const path = require('path');
const { eliminarBase, conexion } = require('../helpers/legacy-schema');

const BASE = 'milkdata_test_arranque';
const RAIZ = path.join(__dirname, '..', '..');

jest.setTimeout(180000);
jest.retryTimes(0);

/**
 * Arranca el esquema contra `BASE` en un proceso aparte.
 *
 * @returns {string} la salida, que enumera las migraciones aplicadas y omitidas.
 */
function arrancar() {
  return execFileSync('node', ['scripts/db-sync.js'], {
    cwd: RAIZ,
    env: {
      ...process.env,
      DB_NAME: BASE,
      NODE_ENV: 'test',
      DB_USER: process.env.TEST_DB_ADMIN_USER || process.env.DB_USER,
      DB_PASSWORD: process.env.TEST_DB_ADMIN_PASSWORD ?? process.env.DB_PASSWORD,
    },
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

/** Una base de datos vacía, como la de un ordenador recién estrenado. */
async function crearBaseVacia() {
  const c = await conexion();
  await c.query(`DROP DATABASE IF EXISTS \`${BASE}\``);
  await c.query(`CREATE DATABASE \`${BASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await c.end();
}

async function consultar(sql, valores = []) {
  const c = await conexion();
  await c.query(`USE \`${BASE}\``);
  const [filas] = await c.query(sql, valores);
  await c.end();
  return filas;
}

/** Cambia el código de la planta principal, como si alguien lo hiciera en la app. */
async function renombrarPlantaPrincipal(nuevoCodigo) {
  const res = await consultar('UPDATE planta SET codigo = ? WHERE nombre = ?', [
    nuevoCodigo,
    'Planta Ecológica Huata',
  ]);
  return res.affectedRows;
}

describe('Arrancar cuando el codigo de la planta ya no es el de arranque', () => {
  beforeAll(async () => {
    await crearBaseVacia();
  });

  afterAll(async () => {
    await eliminarBase(BASE);
  });

  test('una base vacia arranca', () => {
    // Si esto revienta, `execFileSync` lanza y la prueba falla aqui mismo.
    const salida = arrancar();

    expect(salida).toContain('Migraciones aplicadas');
  });

  test('la planta inicial se crea con su codigo de arranque', async () => {
    const filas = await consultar('SELECT codigo FROM planta ORDER BY id LIMIT 1');

    expect(filas).toHaveLength(1);
    expect(filas[0].codigo).toBe('HUA');
  });

  test('las migraciones aplicadas quedan anotadas en el registro', async () => {
    const filas = await consultar('SELECT nombre FROM migracion_aplicada');

    expect(filas.length).toBeGreaterThan(0);
    expect(filas.map((f) => f.nombre)).toContain('planta: registrar la planta principal');
  });

  test('cambiar el codigo desde la app y volver a arrancar NO revoca', () => {
    // El escenario exacto que tumbó la API: el usuario edita el campo `codigo`
    // del formulario de Plantas y reinicia.
    return renombrarPlantaPrincipal('HUATA')
      .then((afectadas) => {
        expect(afectadas).toBe(1);
      })
      .then(() => arrancar())
      .then((salida) => {
        // Antes esto reventaba con
        // `SequelizeUniqueConstraintError: Duplicate entry ... for key 'planta.nombre'`
        // y el servidor se quedaba sin arrancar.
        expect(salida).toContain('Migraciones omitidas');
      });
  });

  test('despues de esos arranques la planta no se duplica', async () => {
    const filas = await consultar('SELECT COUNT(*) AS total FROM planta');

    expect(Number(filas[0].total)).toBe(1);
  });

  test('la planta conserva el codigo que le puso el usuario', async () => {
    const filas = await consultar('SELECT codigo FROM planta ORDER BY id LIMIT 1');

    expect(filas[0].codigo).toBe('HUATA');
  });

  test('volver a arrancar con el codigo cambiado tampoco revoca', () => {
    const salida = arrancar();

    expect(salida).toContain('Migraciones omitidas');
  });

  test('crear una segunda planta y arrancar tampoco revoca', async () => {
    return consultar(
      `INSERT INTO planta (nombre, codigo, direccion, activo, created_at, updated_at)
       VALUES ('Planta Ecológica De Arequipa', 'AREQUIPA', 'Arequipa', true, NOW(), NOW())`
    )
      .then(() => arrancar())
      .then((salida) => {
        expect(salida).toContain('Migraciones omitidas');
      });
  });

  test('no se agrega dos veces la columna planta_id', async () => {
    // Si una migración se volviera a aplicar, `agregar planta_id` intentaría
    // añadir una columna que ya está, y el arranque reventaría. Aquí se
    // comprueba que la columna sigue estando una sola vez.
    const columnas = await consultar('SHOW COLUMNS FROM usuario');
    const conPlanta = columnas.filter((c) => c.Field === 'planta_id');

    expect(conPlanta).toHaveLength(1);
  });
});