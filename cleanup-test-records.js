const { sequelize } = require('./src/config/database.config');

async function main() {
  try {
    await sequelize.query('DELETE FROM usuario WHERE email = ?', {
      replacements: ['repo-test@example.com'],
    });
    await sequelize.query('DELETE FROM rol WHERE nombre = ?', {
      replacements: ['admin_repo_test'],
    });
    await sequelize.query('DELETE FROM unidad WHERE nombre = ?', {
      replacements: ['Unidad Repo Test'],
    });

    console.log('TEST_RECORDS_CLEANED');
  } catch (error) {
    console.error('CLEAN_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
