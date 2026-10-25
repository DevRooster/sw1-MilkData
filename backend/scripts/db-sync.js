const { sequelize, syncSchema } = require('../src/config/database.config');

async function main() {
  const { created, reused } = await syncSchema();

  console.log('Tablas creadas:', created.length ? created.join(', ') : '(ninguna)');
  console.log('Tablas reutilizadas:', reused.length ? reused.join(', ') : '(ninguna)');
}

main()
  .then(() => sequelize.close())
  .catch(async (error) => {
    console.error('No se pudo sincronizar el esquema:', error.message);
    // El SQL que falló es lo primero que hace falta paradiagnosticar una
    // migración; sin él solo queda el mensaje.
    if (error.sql) {
      console.error('SQL:', error.sql);
    }
    console.error(error.stack);
    await sequelize.close();
    process.exitCode = 1;
  });
