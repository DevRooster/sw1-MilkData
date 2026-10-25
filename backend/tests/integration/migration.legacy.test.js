/**
 * Prueba de migración real: levanta una base con el esquema anterior a
 * multi-planta y a `recoleccion`, la migra y verifica que los datos se
 * conservan. Corre en un proceso aparte porque necesita su propia conexión y
 * su propia variable de entorno.
 */
const { execFileSync } = require('child_process');
const path = require('path');
const { crearBaseConDatosViejos, eliminarBase, conexion } = require('../helpers/legacy-schema');

const BASE = 'milkdata_test_migracion';
const RAIZ = path.join(__dirname, '..', '..');

jest.setTimeout(120000);
jest.retryTimes(0);

// Cierra cualquier conexion pendiente al terminar la suite.
afterAll(async () => {
  const { sequelize } = require('../../src/config/database.config');
  try {
    await sequelize.close();
  } catch (_) {
    /* ya cerrada */
  }
});

async function contar(c, tabla) {
  const [rows] = await c.query(`SELECT COUNT(*) AS total FROM ${tabla}`);
  return Number(rows[0].total);
}

describe('Migración desde el esquema anterior', () => {
  let c;

  beforeAll(async () => {
    await crearBaseConDatosViejos(BASE);
    c = await conexion();
  });

  afterAll(async () => {
    if (c) {
      await c.end();
    }
    await eliminarBase(BASE);
  });

  test('el esquema viejo tiene entrega y no tiene planta', async () => {
    await c.query(`USE ${BASE}`);

    const tablas = await c.query('SHOW TABLES');
    const nombres = tablas[0].map((fila) => Object.values(fila)[0]);

    expect(nombres).toContain('entrega');
    expect(nombres).toContain('control_calidad');
    expect(nombres).not.toContain('planta');
    expect(nombres).not.toContain('recoleccion');
  });

  test('la migración conserva los datos y renombra las tablas', () => {
    // El proceso hijo necesita credenciales con permiso sobre la base de
    // prueba. Se le pasan las administrativas a proposito: el usuario de la
    // aplicacion solo tiene acceso a la base principal, y aqui se migra una
    // base aislada que este proceso creo.
    const salida = execFileSync('node', ['scripts/db-sync.js'], {
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

    expect(salida).toContain('planta: crear tabla');
    expect(salida).toContain('entrega: renombrar tabla a recoleccion');
    expect(salida).toContain('control_calidad: renombrar entrega_id a recoleccion_id');
  });

  test('las tablas quedan renombradas y los datos intactos', async () => {
    await c.query(`USE ${BASE}`);
    const tablas = await c.query('SHOW TABLES');
    const nombres = tablas[0].map((fila) => Object.values(fila)[0]);

    expect(nombres).toContain('recoleccion');
    expect(nombres).not.toContain('entrega');
    expect(await contar(c, 'recoleccion')).toBe(1);
    expect(await contar(c, 'control_calidad')).toBe(1);
    expect(await contar(c, 'proveedor')).toBe(1);
  });

  test('la recolección conserva sus datos originales', async () => {
    await c.query(`USE ${BASE}`);
    const [rows] = await c.query(
      'SELECT cantidad, fecha, registrado_en, proveedor_id FROM recoleccion'
    );

    expect(rows[0].cantidad).toBe(42);
    // mysql2 devuelve DATE como Date en zona horaria local; se compara el dia.
    const fecha = new Date(rows[0].fecha);
    expect(fecha.getFullYear()).toBe(2026);
    expect(fecha.getMonth()).toBe(0);
    expect(fecha.getDate()).toBe(1);
    expect(rows[0].registrado_en).toBe('campo');
    expect(rows[0].proveedor_id).toBe(1);
  });

  test('la columna de control_calidad quedo como recoleccion_id', async () => {
    await c.query(`USE ${BASE}`);
    const [columnas] = await c.query('SHOW COLUMNS FROM control_calidad');
    const nombres = columnas.map((columna) => columna.Field);

    expect(nombres).toContain('recoleccion_id');
    expect(nombres).not.toContain('entrega_id');
  });

  test('la foreign key sigue apuntando a la tabla renombrada', async () => {
    await c.query(`USE ${BASE}`);
    const [fks] = await c.query(
      `SELECT rc.CONSTRAINT_NAME, rc.REFERENCED_TABLE_NAME
       FROM information_schema.REFERENTIAL_CONSTRAINTS rc
       WHERE rc.CONSTRAINT_SCHEMA = ? AND rc.REFERENCED_TABLE_NAME = 'recoleccion'`,
      [BASE]
    );

    expect(fks.length).toBeGreaterThan(0);
  });

  test('todas las tablas operativas tienen planta_id not null', async () => {
    await c.query(`USE ${BASE}`);

    for (const tabla of [
      'usuario', 'proveedor', 'unidad', 'zona',
      'recoleccion', 'control_calidad',
    ]) {
      const [columnas] = await c.query(`SHOW COLUMNS FROM ${tabla}`);
      const planta = columnas.find((columna) => columna.Field === 'planta_id');

      expect(planta).toBeTruthy();
      expect(planta.Null).toBe('NO');
    }
  });

  test('los datos previos quedan asignados a la planta principal', async () => {
    await c.query(`USE ${BASE}`);
    const [plantas] = await c.query('SELECT id, codigo FROM planta');
    expect(plantas).toHaveLength(1);
    expect(plantas[0].codigo).toBe('HUA');

    for (const tabla of ['usuario', 'proveedor', 'unidad', 'zona', 'recoleccion', 'control_calidad']) {
      const [rows] = await c.query(
        `SELECT COUNT(*) AS huerfanos FROM ${tabla} WHERE planta_id IS NULL`
      );
      expect(Number(rows[0].huerfanos)).toBe(0);

      const [ok] = await c.query(
        `SELECT COUNT(*) AS total FROM ${tabla} WHERE planta_id = ${plantas[0].id}`
      );
      expect(Number(ok[0].total)).toBeGreaterThan(0);
    }
  });

  test('la imagen por defecto es null, no undefined', async () => {
    await c.query(`USE ${BASE}`);
    const [rows] = await c.query('SELECT imagen FROM proveedor LIMIT 1');
    expect(rows[0].imagen).toBeNull();
  });

  test('correr la migracion otra vez no rompe nada', () => {
    // El proceso hijo necesita credenciales con permiso sobre la base de
    // prueba. Se le pasan las administrativas a proposito: el usuario de la
    // aplicacion solo tiene acceso a la base principal, y aqui se migra una
    // base aislada que este proceso creo.
    const salida = execFileSync('node', ['scripts/db-sync.js'], {
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

    expect(salida).toContain('Migraciones omitidas');
    expect(salida).not.toContain('  + ');
  });
});
