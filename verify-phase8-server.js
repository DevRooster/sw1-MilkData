const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor } = require('./src/entities');
const securityAuthService = require('./src/security/auth.service');

async function call(path, options = {}) {
  const response = await fetch(`http://127.0.0.1:3000${path}`, {
    headers: { 'content-type': 'application/json' },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const body = await response.json();
  return { status: response.status, body };
}

async function main() {
  const suffix = Date.now().toString();
  let role;
  let user;
  let provider;
  try {
    role = await Rol.create({ nombre: `server_${suffix}`, descripcion: 'Rol temporal servidor', nivel: 1, activo: true });
    user = await Usuario.create({ nombre: 'Server', apellido: 'Test', email: `server_${suffix}@example.com`, password: await securityAuthService.hashPassword('Admin123!'), rolId: role.id, activo: true });

    const register = await call('/auth/register', { method: 'POST', body: { nombre: 'HTTP', apellido: 'Register', email: `http_${suffix}@example.com`, password: 'Admin123!', rolId: role.id } });
    const login = await call('/auth/login', { method: 'POST', body: { email: `server_${suffix}@example.com`, password: 'Admin123!' } });
    const providerResponse = await call('/proveedores', { method: 'POST', body: { nombre: 'HTTP', apellido: 'Provider', dni: `S${suffix}`, codigo: `S${suffix}`, activo: true } });
    provider = await Proveedor.findByPk(providerResponse.body.data.proveedor.id);

    const checks = [
      ['AUTH_REGISTER', register],
      ['AUTH_LOGIN', login],
      ['PROVEEDOR_POST', providerResponse],
    ];
    for (const path of ['/unidades', '/zonas', '/entregas', '/calidad', '/notificaciones', '/asistencias', '/reportes/contraste', '/reportes/calidad', '/reportes/calidad-proveedor']) {
      checks.push([`GET_${path.slice(1).replaceAll('/', '_').toUpperCase()}`, await call(path)]);
    }

    for (const [label, result] of checks) {
      console.log(`${label}_STATUS:`, result.status);
      console.log(`${label}_JSON:`, JSON.stringify(result.body));
      if (result.status < 200 || result.status >= 300) throw new Error(`${label} devolvió ${result.status}`);
    }
    console.log('FINAL_ROUTE_STRUCTURE_CHECK: PASS');
  } finally {
    if (provider) await Proveedor.destroy({ where: { id: provider.id } });
    if (user) await Usuario.destroy({ where: { id: user.id } });
    await Usuario.destroy({ where: { email: `http_${suffix}@example.com` } });
    if (role) await Rol.destroy({ where: { id: role.id } });
    await sequelize.close();
    console.log('CLEANUP_PHASE8_SERVER: COMPLETE');
  }
}

main().catch((error) => {
  console.error('PHASE8_SERVER_ERROR:', error.message);
  process.exitCode = 1;
});
