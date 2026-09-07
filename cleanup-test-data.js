const { sequelize } = require('./src/config/database.config');

async function main() {
  try {
    const tables = [
      { table: 'usuario', condition: "email LIKE '%@example.com' OR email LIKE '%dto-user@example.com%' OR email = 'repo-test@example.com'" },
      { table: 'rol', condition: "nombre IN ('admin_repo_test', 'dto_rol_test') OR nombre LIKE 'rol_%'" },
      { table: 'unidad', condition: "nombre IN ('Unidad Repo Test') OR nombre LIKE 'Unidad %Test%'" },
      { table: 'proveedor', condition: "dni LIKE 'TEST-%' OR codigo LIKE 'TEST-%' OR codigo LIKE 'PROV-%'" },
    ];

    for (const entry of tables) {
      const result = await sequelize.query(`DELETE FROM ${entry.table} WHERE ${entry.condition}`);
      console.log(`CLEANED:${entry.table}`, JSON.stringify(result[0]));
    }

    console.log('TEST_DATA_CLEANUP_COMPLETE');
    process.exit(0);
  } catch (error) {
    console.error('CLEANUP_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
