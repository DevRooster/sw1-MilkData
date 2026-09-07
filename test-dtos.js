const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario } = require('./src/entities');
const authDto = require('./src/dtos/auth.dto');
const proveedorDto = require('./src/dtos/proveedor.dto');

async function main() {
  try {
    const rol = await Rol.create({ nombre: 'dto_rol_test', descripcion: 'rol dto', nivel: 1, activo: true });
    const usuario = await Usuario.create({
      nombre: 'Usuario',
      apellido: 'DTO',
      email: 'dto-user@example.com',
      password: 'supersecret',
      rolId: rol.id,
      activo: true,
    });

    const rawUsuario = await Usuario.findByPk(usuario.id, {
      include: [{ association: 'rol' }],
    });

    const inputJson = rawUsuario.toJSON();
    const outputJson = authDto.toDTO(rawUsuario);

    console.log('AUTH_DTO_INPUT:', JSON.stringify(inputJson, null, 2));
    console.log('AUTH_DTO_OUTPUT:', JSON.stringify(outputJson, null, 2));
    console.log('PASSWORD_EXCLUDED:', Object.prototype.hasOwnProperty.call(outputJson, 'password') ? 'NO' : 'YES');

    console.log('PROVEEDOR_DTO_AVAILABLE:', typeof proveedorDto.toDTO === 'function');

    await Usuario.destroy({ where: { id: usuario.id } });
    await Rol.destroy({ where: { id: rol.id } });
    process.exit(0);
  } catch (error) {
    console.error('DTO_TEST_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
