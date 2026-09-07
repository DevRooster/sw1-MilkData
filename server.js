const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const logger = require('./src/utils/logger');

const port = Number(process.env.PORT || 3000);

async function startServer() {
  await sequelize.authenticate();
  const server = app.listen(port, () => {
    logger.info(`MilkData API escuchando en el puerto ${port}`);
  });
  return server;
}

if (require.main === module) {
  startServer().catch((error) => {
    logger.error('No se pudo iniciar el servidor', error);
    process.exit(1);
  });
}

module.exports = { app, startServer };
