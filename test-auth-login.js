const bcrypt = require('bcryptjs');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario } = require('./src/entities');
const authService = require('./src/services/impl/auth.service');

async function main() {
  try {
    const rol = await Rol.create({ nombre: 'auth_login_role', descripcion: 'rol auth login', nivel: 1, activo: true });
    const passwordHash = await bcrypt.hash('Admin123!', 10);
    const usuario = await Usuario.create({
      nombre: 'Auth',
      apellido: 'Login',
      email: 'auth-login@example.com',
      password: passwordHash,
      rolId: rol.id,
      activo: true,
    });

    const success = await authService.login({ email: 'auth-login@example.com', password: 'Admin123!' });
    console.log('LOGIN_SUCCESS_TOKEN_PRESENT:', !!success.token);
    console.log('LOGIN_SUCCESS_USER_EMAIL:', success.user.email);

    try {
      await authService.login({ email: 'auth-login@example.com', password: 'wrongpass' });
      console.log('BAD_LOGIN_UNEXPECTED_SUCCESS');
    } catch (error) {
      console.log('BAD_LOGIN_ERROR_STATUS:', error && error.statusCode ? error.statusCode : 'unknown');
      console.log('BAD_LOGIN_ERROR_MESSAGE:', error && error.message ? error.message : String(error));
    }

    await Usuario.destroy({ where: { id: usuario.id } });
    await Rol.destroy({ where: { id: rol.id } });
    process.exit(0);
  } catch (error) {
    console.error('AUTH_LOGIN_CHECK_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
