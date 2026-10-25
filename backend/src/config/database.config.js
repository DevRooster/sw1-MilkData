const Sequelize = require('sequelize');
const dotenv = require('dotenv');

dotenv.config();

const sequelize = new Sequelize(
  process.env.DB_NAME || 'milkdata',
  process.env.DB_USER || 'root',
  process.env.DB_PASSWORD || '',
  {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    dialect: 'mysql',
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    define: {
      timestamps: true,
      underscored: true,
      freezeTableName: true,
    },
    pool: {
      max: 10,
      min: 0,
      acquire: 30000,
      idle: 10000,
    },
  }
);

async function testConnection() {
  await sequelize.authenticate();
  return true;
}

/**
 * Crea las tablas que falten y reutiliza las que ya existen.
 * `alter: false` y `force: false` garantizan que nunca se modifique ni se
 * borre nada de una base que ya tiene datos.
 */
async function syncSchema({ log = console.log } = {}) {
  // sequelize.sync() solo conoce las tablas de los modelos ya registrados,
  // por eso las entidades se cargan dentro de la funcion y no en el modulo.
  require('../entities');
  const { runMigrations } = require('../migrations');

  await sequelize.authenticate();
  const queryInterface = sequelize.getQueryInterface();

  // Fase 1 y 2: renombres y cambios sobre tablas que ya existen.
  // Los renombres van antes del sync: si no, sync crearia la tabla nueva
  // vacia y el RENAME de la vieja fallaria por colision de nombre.
  await runMigrations({ sequelize, log, fase: 'antes' });

  const before = new Set(await queryInterface.showAllTables());
  await sequelize.sync({ alter: false, force: false });

  // Fase 3: columnas que referencian tablas que acaba de crear `sync`.
  await runMigrations({ sequelize, log, fase: 'despues' });

  const tables = await queryInterface.showAllTables();
  return {
    created: tables.filter((table) => !before.has(table)),
    reused: tables.filter((table) => before.has(table)),
  };
}

module.exports = {
  sequelize,
  testConnection,
  syncSchema,
};
