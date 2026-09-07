const dotenv = require('dotenv');
const { sequelize } = require('./src/config/database.config');

dotenv.config();

async function main() {
  try {
    await sequelize.authenticate();
    console.log('DB_CONNECTION_OK');
    console.log('DB_NAME:', process.env.DB_NAME || 'milkdata');
    console.log('DB_HOST:', process.env.DB_HOST || 'localhost');
    console.log('DB_PORT:', process.env.DB_PORT || 3306);
    process.exit(0);
  } catch (error) {
    console.error('DB_CONNECTION_ERROR');
    console.error('ERROR_MESSAGE:', error && error.message ? error.message : String(error));
    console.error('ERROR_STACK:', error && error.stack ? error.stack : 'No stack available');
    process.exit(1);
  }
}

main();
