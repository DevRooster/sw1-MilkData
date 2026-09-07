const { execFileSync } = require('node:child_process');
const bcrypt = require('bcryptjs');
const request = require('supertest');
const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor, Unidad, Zona, Entrega, ControlCalidad, Notificacion, Asistencia } = require('./src/entities');

const password = 'Bootstrap123!';
const suffix = Date.now().toString();

async function wipe() {
  await Notificacion.destroy({ where: {}, truncate: false });
  await ControlCalidad.destroy({ where: {}, truncate: false });
  await Asistencia.destroy({ where: {}, truncate: false });
  await Entrega.destroy({ where: {}, truncate: false });
  await Proveedor.destroy({ where: {}, truncate: false });
  await Usuario.destroy({ where: {}, truncate: false });
  await Zona.destroy({ where: {}, truncate: false });
  await Unidad.destroy({ where: {}, truncate: false });
  await Rol.destroy({ where: {}, truncate: false });
}

async function createRole(nombre) {
  return Rol.create({ nombre, descripcion: `Rol ${nombre} bootstrap`, nivel: 1, activo: true });
}

async function printScenario(label, response) {
  console.log(`${label}_STATUS:`, response.statusCode);
  console.log(`${label}_JSON:`, JSON.stringify(response.body));
}

async function main() {
  let adminRole;
  let providerRole;
  let qualityRole;
  let adminToken;
  let providerToken;

  try {
    await wipe();
    adminRole = await createRole('admin');
    providerRole = await createRole('proveedor');
    qualityRole = await createRole('calidad');
    console.log('BOOTSTRAP_DATABASE_CLEAN: true');

    const firstAdmin = await request(app).post('/auth/register').send({
      nombre: 'Primer', apellido: 'Admin', email: `first_admin_${suffix}@example.com`, password, rolId: adminRole.id,
    });
    await printScenario('SCENARIO_1_FIRST_ADMIN_NO_TOKEN', firstAdmin);

    const blockedProviderBootstrap = await request(app).post('/auth/register').send({
      nombre: 'Proveedor', apellido: 'Bootstrap', email: `blocked_${suffix}@example.com`, password, rolId: providerRole.id,
    });
    await printScenario('SCENARIO_2_PROVIDER_BEFORE_ADMIN_NO_TOKEN', blockedProviderBootstrap);

    const noTokenAfterAdmin = await request(app).post('/auth/register').send({
      nombre: 'Otro', apellido: 'Admin', email: `no_token_${suffix}@example.com`, password, rolId: providerRole.id,
    });
    await printScenario('SCENARIO_3_AFTER_ADMIN_NO_TOKEN', noTokenAfterAdmin);

    const adminLogin = await request(app).post('/auth/login').send({ email: `first_admin_${suffix}@example.com`, password });
    adminToken = adminLogin.body.data.token;
    const providerUser = await request(app).post('/auth/register').set('Authorization', `Bearer ${adminToken}`).send({
      nombre: 'Usuario', apellido: 'Proveedor', email: `provider_${suffix}@example.com`, password, rolId: providerRole.id,
    });
    const providerLogin = await request(app).post('/auth/login').send({ email: `provider_${suffix}@example.com`, password });
    providerToken = providerLogin.body.data.token;

    const nonAdminAttempt = await request(app).post('/auth/register').set('Authorization', `Bearer ${providerToken}`).send({
      nombre: 'No', apellido: 'Admin', email: `forbidden_${suffix}@example.com`, password, rolId: qualityRole.id,
    });
    await printScenario('SCENARIO_4_NON_ADMIN_TOKEN', nonAdminAttempt);

    const adminAttempt = await request(app).post('/auth/register').set('Authorization', `Bearer ${adminToken}`).send({
      nombre: 'Nuevo', apellido: 'Calidad', email: `quality_${suffix}@example.com`, password, rolId: qualityRole.id,
    });
    await printScenario('SCENARIO_5_ADMIN_TOKEN_ANY_ROLE', adminAttempt);

    const invalidRoleAfterAdmin = await request(app).post('/auth/register').set('Authorization', `Bearer ${adminToken}`).send({
      nombre: 'Rol', apellido: 'Invalido', email: `invalid_${suffix}@example.com`, password, rolId: 999999,
    });
    await printScenario('INVALID_ROLE_AFTER_ADMIN', invalidRoleAfterAdmin);

    const concurrentA = request(app).post('/auth/register').send({
      nombre: 'Race', apellido: 'A', email: `race_a_${suffix}@example.com`, password, rolId: adminRole.id,
    });
    const concurrentB = request(app).post('/auth/register').send({
      nombre: 'Race', apellido: 'B', email: `race_b_${suffix}@example.com`, password, rolId: adminRole.id,
    });
    const raceResults = await Promise.all([concurrentA, concurrentB]);
    console.log('CONCURRENT_FIRST_ADMIN_STATUSES:', JSON.stringify(raceResults.map((result) => result.statusCode)));
    console.log('CONCURRENT_FIRST_ADMIN_JSON:', JSON.stringify(raceResults.map((result) => result.body)));
    console.log('RACE_CONCLUSION: la comprobación no es atómica; con emails distintos ambos pueden crear admin si llegan simultáneamente.');
  } finally {
    await wipe();
    execFileSync(process.execPath, ['seed.js'], { stdio: 'inherit' });
    console.log('REGISTER_BOOTSTRAP_CLEANUP_AND_SEED_RESTORE: COMPLETE');
    await sequelize.close();
  }
}

main().catch(async (error) => {
  console.error('REGISTER_BOOTSTRAP_ERROR:', error.message);
  try { await sequelize.close(); } catch (_) { /* cierre defensivo */ }
  process.exitCode = 1;
});
