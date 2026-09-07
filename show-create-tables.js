const { sequelize } = require('./src/config/database.config');

async function main() {
  try {
    const proveedor = await sequelize.query('SHOW CREATE TABLE proveedor');
    const calidad = await sequelize.query('SHOW CREATE TABLE control_calidad');

    console.log('--- SHOW CREATE TABLE proveedor ---');
    console.log(JSON.stringify(proveedor[0], null, 2));
    console.log('--- SHOW CREATE TABLE control_calidad ---');
    console.log(JSON.stringify(calidad[0], null, 2));
  } catch (error) {
    console.error('SHOW_CREATE_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
