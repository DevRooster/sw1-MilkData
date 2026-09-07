const { sequelize } = require('./src/config/database.config');

async function main() {
  try {
    const queries = [
      'SELECT id, nombre, email FROM usuario',
      'SELECT id, nombre FROM rol',
      'SELECT id, nombre FROM unidad',
      'SELECT id, dni, codigo FROM proveedor',
    ];

    for (const sql of queries) {
      const [rows] = await sequelize.query(sql);
      console.log('--- ' + sql + ' ---');
      console.log(JSON.stringify(rows, null, 2));
    }
  } catch (error) {
    console.error('CHECK_TABLES_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
