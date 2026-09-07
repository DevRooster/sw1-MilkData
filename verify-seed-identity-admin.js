const { execFileSync } = require('node:child_process');
const request = require('supertest');
const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario } = require('./src/entities');

async function main() {
  try {
    const adminBefore = await Usuario.findOne({ where: { email: 'admin@milkdata.com' } });
    const roleBefore = await Rol.findOne({ where: { nombre: 'admin' } });
    const identityBefore = {
      admin: { id: adminBefore.id, createdAt: adminBefore.createdAt.toISOString() },
      role: { id: roleBefore.id, createdAt: roleBefore.createdAt.toISOString() },
    };
    console.log('IDENTITY_BEFORE_THIRD_RUN:', JSON.stringify(identityBefore));

    execFileSync(process.execPath, ['seed.js'], { stdio: 'inherit' });

    const adminAfter = await Usuario.findOne({ where: { email: 'admin@milkdata.com' } });
    const roleAfter = await Rol.findOne({ where: { nombre: 'admin' } });
    const identityAfter = {
      admin: { id: adminAfter.id, createdAt: adminAfter.createdAt.toISOString() },
      role: { id: roleAfter.id, createdAt: roleAfter.createdAt.toISOString() },
    };
    console.log('IDENTITY_AFTER_THIRD_RUN:', JSON.stringify(identityAfter));
    console.log('IDENTITY_UNCHANGED:', JSON.stringify(identityBefore) === JSON.stringify(identityAfter));

    const login = await request(app).post('/auth/login').send({ email: 'admin@milkdata.com', password: 'Admin123!' });
    console.log('ADMIN_LOGIN_STATUS:', login.statusCode);
    console.log('ADMIN_LOGIN_JSON:', JSON.stringify({
      success: login.body.success,
      message: login.body.message,
      tokenPresent: Boolean(login.body.data && login.body.data.token),
      email: login.body.data && login.body.data.user && login.body.data.user.email,
    }));

    if (JSON.stringify(identityBefore) !== JSON.stringify(identityAfter) || login.statusCode !== 200 || !login.body.data.token) {
      throw new Error('La identidad del seed cambió o el login real del admin falló');
    }
  } finally {
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('SEED_IDENTITY_ADMIN_ERROR:', error.message);
  process.exitCode = 1;
});
