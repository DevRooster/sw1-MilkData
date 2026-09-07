const { sequelize } = require('./src/config/database.config');
const rolRepository = require('./src/repositories/rol.repository');
const unidadRepository = require('./src/repositories/unidad.repository');
const usuarioRepository = require('./src/repositories/usuario.repository');

async function main() {
  try {
    const rol = await rolRepository.create({ nombre: 'admin_repo_test', descripcion: 'rol de prueba', nivel: 1, activo: true });
    const unidad = await unidadRepository.create({ nombre: 'Unidad Repo Test', tipo: 'furgon', capacidad: 1200, cerrado: true, activo: true });
    const usuario = await usuarioRepository.create({
      nombre: 'Usuario',
      apellido: 'Repo',
      email: 'repo-test@example.com',
      password: 'secret123',
      rolId: rol.id,
      activo: true,
    });

    const foundRol = await rolRepository.findById(rol.id);
    const foundUnidad = await unidadRepository.findById(unidad.id);
    const foundUsuario = await usuarioRepository.findByEmail('repo-test@example.com');

    console.log('CREATE_READ_OK');
    console.log('ROL:', JSON.stringify({ id: foundRol.id, nombre: foundRol.nombre }));
    console.log('UNIDAD:', JSON.stringify({ id: foundUnidad.id, nombre: foundUnidad.nombre }));
    console.log('USUARIO:', JSON.stringify({ id: foundUsuario.id, email: foundUsuario.email, rolId: foundUsuario.rolId }));

    process.exit(0);
  } catch (error) {
    console.error('REPOSITORY_TEST_ERROR');
    console.error(error && error.message ? error.message : String(error));
    if (error && error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
