const app = require('./src/app');
const { sequelize, syncSchema } = require('./src/config/database.config');
const logger = require('./src/utils/logger');

const port = Number(process.env.PORT || 3000);

async function startServer() {
  const { created, reused } = await syncSchema();

  if (created.length) {
    logger.info(`Tablas creadas: ${created.join(', ')}`);
  }
  if (reused.length) {
    logger.info(`Tablas existentes reutilizadas: ${reused.join(', ')}`);
  }
  if (!created.length && !reused.length) {
    logger.warn('El modelo no define ninguna tabla.');
  }

  const server = app.listen(port, () => {
    logger.info(`MilkData API escuchando en el puerto ${port}`);
  });
  return server;
}

async function stopServer(server) {
  await new Promise((resolve) => server.close(resolve));
  await sequelize.close();
}

if (require.main === module) {
  startServer().catch((error) => {
    logger.error('No se pudo iniciar el servidor', error);
    process.exit(1);
  });
}

module.exports = { app, startServer, stopServer };
