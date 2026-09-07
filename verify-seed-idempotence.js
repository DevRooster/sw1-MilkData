const { execFileSync } = require('node:child_process');
const { sequelize } = require('./src/config/database.config');
const { Rol, Unidad, Zona, Usuario, Proveedor } = require('./src/entities');

async function counts() {
  return {
    roles: await Rol.count(),
    unidades: await Unidad.count(),
    zonas: await Zona.count(),
    usuarios: await Usuario.count(),
    proveedores: await Proveedor.count(),
  };
}

function runSeed(label) {
  console.log(`RUN_${label}: node seed.js`);
  execFileSync(process.execPath, ['seed.js'], { stdio: 'inherit' });
}

async function main() {
  try {
    runSeed('FIRST');
    const beforeSecond = await counts();
    console.log('COUNTS_BEFORE_SECOND_RUN:', JSON.stringify(beforeSecond));

    runSeed('SECOND');
    const afterSecond = await counts();
    console.log('COUNTS_AFTER_SECOND_RUN:', JSON.stringify(afterSecond));

    const expected = { roles: 5, unidades: 4, zonas: 4, usuarios: 1, proveedores: 5 };
    const idempotent = JSON.stringify(beforeSecond) === JSON.stringify(afterSecond);
    const expectedCounts = JSON.stringify(afterSecond) === JSON.stringify(expected);
    console.log('EXPECTED_COUNTS:', JSON.stringify(expected));
    console.log('IDEMPOTENT_SECOND_RUN:', idempotent);
    console.log('SEED_EXPECTATIONS_MET:', expectedCounts);

    if (!idempotent || !expectedCounts) {
      throw new Error('El seed no es idempotente o no creó las cantidades esperadas');
    }
  } finally {
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('SEED_IDEMPOTENCE_ERROR:', error.message);
  process.exitCode = 1;
});
