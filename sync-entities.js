const { sequelize } = require('./src/config/database.config');
const entities = require('./src/entities');

async function main() {
  try {
    await sequelize.sync({ alter: false, force: false });
    console.log('SEQUELIZE_SYNC_OK');
    const tableNames = await sequelize.getQueryInterface().showAllTables();
    console.log('TABLES:', JSON.stringify(tableNames, null, 2));
    process.exit(0);
  } catch (error) {
    console.error('SEQUELIZE_SYNC_ERROR');
    console.error(error && error.message ? error.message : String(error));
    if (error && error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
