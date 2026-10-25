// Este script imprime un informe, no SQL: se apaga el log de Sequelize.
process.env.NODE_ENV = process.env.NODE_ENV === 'test' ? 'test' : 'production';

const { sequelize } = require('../src/config/database.config');
require('../src/entities');

const ORDEN = [
  'planta',
  'rol',
  'unidad',
  'zona',
  'usuario',
  'proveedor',
  'producto',
  'recoleccion',
  'control_calidad',
  'notificacion',
  'asistencia',
];

/** Columnas que son clave for√°nea, y a qu√© tabla apuntan. */
async function clavesForaneas(queryInterface, tabla) {
  const [constraints] = await sequelize.query(
    `SELECT k.COLUMN_NAME AS columna, k.REFERENCED_TABLE_NAME AS referencia,
            rc.UPDATE_RULE AS onUpdate, rc.DELETE_RULE AS onDelete
     FROM information_schema.KEY_COLUMN_USAGE k
     JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
       ON rc.CONSTRAINT_NAME = k.CONSTRAINT_NAME
      AND rc.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
     WHERE k.TABLE_SCHEMA = DATABASE() AND k.TABLE_NAME = ?
       AND k.REFERENCED_TABLE_NAME IS NOT NULL
     ORDER BY k.COLUMN_NAME`,
    { replacements: [tabla] }
  );
  return constraints;
}

function tipo(columna) {
  const t = String(columna.type);
  const opciones = columna.type.options && columna.type.options.length
    ? `(${columna.type.options.join(',')})`
    : '';
  if (/ENUM/i.test(t)) return `ENUM${opciones}`;
  if (/VARCHAR/i.test(t)) return `VARCHAR${opciones}`;
  return t.toUpperCase().split('(')[0];
}

/** Columnas con indice unico, leidas de information_schema. */
async function columnasUnicas(queryInterface, tabla) {
  const [rows] = await sequelize.query(
    `SELECT COLUMN_NAME AS columna
     FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
       AND NON_UNIQUE = 0 AND INDEX_NAME <> 'PRIMARY'
     GROUP BY COLUMN_NAME`,
    { replacements: [tabla] }
  );
  return new Set(rows.map((r) => r.columna));
}

function marcasDe(nombre, columna, unicas) {
  const marcas = [];
  if (columna.primaryKey) marcas.push('PK');
  if (columna.autoIncrement) marcas.push('AUTO');
  if (columna.allowNull === false) marcas.push('NOT NULL');
  if (!columna.primaryKey && unicas.has(nombre)) marcas.push('UNIQUE');
  return marcas;
}

async function main() {
  const queryInterface = sequelize.getQueryInterface();
  const existentes = await queryInterface.showAllTables();
  const tablas = ORDEN.filter((t) => existentes.includes(t));
  const otras = existentes.filter((t) => !ORDEN.includes(t));

  console.log('='.repeat(80));
  console.log('  ESTRUCTURA DE LA BASE DE DATOS');
  console.log(`  ${existentes.length} tablas`);
  console.log('='.repeat(80));

  for (const tabla of tablas) {
    const columnas = await queryInterface.describeTable(tabla);
    const unicas = await columnasUnicas(queryInterface, tabla);
    const fks = await clavesForaneas(queryInterface, tabla);

    const ancho = Math.max(...Object.keys(columnas).map((c) => c.length)) + 2;
    const anchoTipo = Math.max(...Object.values(columnas).map((c) => tipo(c).length)) + 2;

    console.log('');
    console.log(`  ${tabla}  ${'‚"?'.repeat(Math.max(0, 74 - tabla.length))}`);
    console.log(`  ${'COLUMNA'.padEnd(ancho)}${'TIPO'.padEnd(anchoTipo)}CLAVES`);
    console.log(`  ${'‚"?'.repeat(ancho + anchoTipo + 40)}`);

    for (const [nombre, columna] of Object.entries(columnas)) {
      const marcas = marcasDe(nombre, columna, unicas);
      const fk = fks.find((f) => f.columna === nombre);
      if (fk) {
        marcas.push(`FK -> ${fk.referencia}`);
        if (fk.onDelete !== 'NO ACTION') marcas.push(`onDelete ${fk.onDelete}`);
      }
      console.log(`  ${nombre.padEnd(ancho)}${tipo(columna).padEnd(anchoTipo)}${marcas.join(', ')}`);
    }
  }

  if (otras.length) {
    console.log('');
    console.log(`  Tablas fuera del modelo: ${otras.join(', ')}`);
  }

  console.log('');
  console.log('='.repeat(80));
  console.log('  RELACIONES');
  console.log('='.repeat(80));
  console.log(`
  AISLAMIENTO POR PLANTA
  ----------------------
  ${tablas.length > 0 ? 'planta' : ''} es la raiz. Todas las tablas operativas llevan
  planta_id NOT NULL con indice, y cada consulta de la API la filtra por la
  planta del token. Dos plantas nunca ven los datos de la otra.

  Tablas aisladas : unidad, zona, usuario, proveedor, producto,
                    recoleccion, control_calidad, notificacion, asistencia
  Tablas globales : rol (permisos), planta (la raiz del aislamiento)


  DIAGRAMA
  --------
                                 planta
                                   |
      +------------+-------------+-------------+-------------+-------------+
      |            |             |             |             |             |
    usuario    proveedor      unidad        zona      producto   (raiz: rol)
      |            |             |             |
      | rol        | zona        +-- zonas     +-- recolecciones
      |            | unidades        recolecciones
      |            | notificaciones  |
      |            | asistencias     +-- control_calidad
      |            | recolecciones
      +-- proveedor (1:1, proveedor.usuario_id UNIQUE)

  usuario      --< recolecciones, control_calidad, notificaciones, asistencias
  proveedor    --< recolecciones, notificaciones, asistencias
  zona         --< recolecciones
  unidad       --< recolecciones
  recoleccion  --1 control_calidad   (control_calidad.recoleccion_id UNIQUE)

  producto: catalogo independiente. El modulo de ventas (V20) lo conectara
  con ventas, inventario y produccion.
`);

  await sequelize.close();
}

main().catch(async (error) => {
  console.error('Error al inspeccionar el esquema:', error.message);
  await sequelize.close();
  process.exitCode = 1;
});

