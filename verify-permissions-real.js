const bcrypt = require('bcryptjs');
const request = require('supertest');
const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor, Unidad, Zona, Entrega, ControlCalidad, Notificacion } = require('./src/entities');

async function login(email, password) {
  const response = await request(app).post('/auth/login').send({ email, password });
  if (response.statusCode !== 200) throw new Error(`Login falló para ${email}: ${response.statusCode}`);
  return response.body.data.token;
}

function auth(token) {
  return { Authorization: `Bearer ${token}` };
}

async function main() {
  const suffix = Date.now().toString();
  const password = 'PermTest123!';
  const roleNames = ['admin', 'ingeniero', 'acopiador', 'calidad', 'proveedor'];
  const roles = [];
  const users = [];
  let unidad;
  let zona;
  let provider;
  let entrega;
  let entregaForQuality;
  let calidad;
  let notification;

  try {
    for (const name of roleNames) {
      const role = await Rol.create({ nombre: `${name}_${suffix}`, descripcion: `Prueba ${name}`, nivel: 1, activo: true });
      roles.push(role);
      users.push(await Usuario.create({
        nombre: name,
        apellido: 'PermTest',
        email: `${name}_${suffix}@example.com`,
        password: await bcrypt.hash(password, 10),
        rolId: role.id,
        activo: true,
      }));
    }

    unidad = await Unidad.create({ nombre: `Perm Unidad ${suffix}`, tipo: 'furgon', capacidad: 1000, cerrado: false, activo: true });
    zona = await Zona.create({ nombre: `Perm Zona ${suffix}`, ruta: 'Ruta Permisos', unidadId: unidad.id, activo: true });
    provider = await Proveedor.create({ nombre: 'Perm', apellido: 'Proveedor', dni: `P${suffix}`, codigo: `PERM-${suffix}`, zonaId: zona.id, activo: true });
    entrega = await Entrega.create({ proveedorId: provider.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: users[0].id, cantidad: 10, fecha: '2026-09-07', registradoEn: 'campo', sincronizado: false });
    entregaForQuality = await Entrega.create({ proveedorId: provider.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: users[0].id, cantidad: 9, fecha: '2026-09-07', registradoEn: 'planta', sincronizado: false });

    const tokens = {};
    for (let index = 0; index < roleNames.length; index += 1) {
      tokens[roleNames[index]] = await login(users[index].email, password);
    }

    const cases = [];
    async function run(label, role, method, path, body) {
      const response = await request(app)[method](path).set(auth(tokens[role])).send(body);
      cases.push({ label, role, method: method.toUpperCase(), path, status: response.statusCode, body: response.body });
      return response;
    }

    const entregaPayload = { proveedorId: provider.id, zonaId: zona.id, unidadId: unidad.id, usuarioId: users[0].id, cantidad: 11, fecha: '2026-09-07', registradoEn: 'campo', sincronizado: false };
    await run('proveedor intenta crear entrega', 'proveedor', 'post', '/entregas', entregaPayload);
    await run('admin crea entrega', 'admin', 'post', '/entregas', { ...entregaPayload, cantidad: 12 });

    const calidadPayload = { entregaId: entrega.id, usuarioId: users[3].id, grasa: 3, proteina: 3, lactosa: 4, densidad: 1, temperatura: 4, aguaAnadida: 0, ph: 6, resultado: 'pura' };
    const providerQuality = await run('proveedor intenta crear calidad', 'proveedor', 'post', '/calidad', calidadPayload);
    calidad = providerQuality.body.data && providerQuality.body.data.item ? await ControlCalidad.findByPk(providerQuality.body.data.item.id) : null;
    await run('calidad crea control', 'calidad', 'post', '/calidad', { ...calidadPayload, entregaId: entregaForQuality.id, usuarioId: users[3].id });

    const notificationPayload = { proveedorId: provider.id, usuarioId: users[0].id, tipo: 'reunion', titulo: 'Permisos', mensaje: `Prueba ${suffix}`, leida: false, enviada: false };
    const providerNotification = await run('proveedor intenta crear notificacion', 'proveedor', 'post', '/notificaciones', notificationPayload);
    notification = providerNotification.body.data && providerNotification.body.data.item ? await Notificacion.findByPk(providerNotification.body.data.item.id) : null;
    await run('admin crea notificacion', 'admin', 'post', '/notificaciones', { ...notificationPayload, mensaje: `Prueba admin ${suffix}` });

    await run('proveedor consulta reportes', 'proveedor', 'get', '/reportes/contraste');
    await run('calidad consulta reportes', 'calidad', 'get', '/reportes/contraste');
    const unauthenticated = await request(app).get('/reportes/contraste');
    cases.push({ label: 'sin token consulta reportes', role: 'ninguno', method: 'GET', path: '/reportes/contraste', status: unauthenticated.statusCode, body: unauthenticated.body });

    for (const item of cases) {
      console.log(`${item.label} [${item.role}] ${item.method} ${item.path} STATUS:`, item.status);
      console.log(`${item.label} JSON:`, JSON.stringify(item.body));
    }

    console.log('PERMISSIONS_SERVICE_USED_BY_ROUTES:', false);
    console.log('AUTH_MIDDLEWARE_USED_BY_ROUTES:', false);
    console.log('DEFAULT_POLICY:', 'sin middleware de autorización: las rutas permiten la petición y no devuelven 403');
  } finally {
    if (provider) await Notificacion.destroy({ where: { proveedorId: provider.id } });
    if (entrega || entregaForQuality) await ControlCalidad.destroy({ where: { entregaId: [entrega, entregaForQuality].filter(Boolean).map((item) => item.id) } });
    if (entrega || entregaForQuality) await Entrega.destroy({ where: { id: [entrega, entregaForQuality].filter(Boolean).map((item) => item.id) } });
    if (provider) await Proveedor.destroy({ where: { id: provider.id } });
    if (zona) await Zona.destroy({ where: { id: zona.id } });
    if (unidad) await Unidad.destroy({ where: { id: unidad.id } });
    if (users.length) await Usuario.destroy({ where: { id: users.map((user) => user.id) } });
    if (roles.length) await Rol.destroy({ where: { id: roles.map((role) => role.id) } });
    await sequelize.close();
    console.log('PERMISSIONS_TEST_CLEANUP: COMPLETE');
  }
}

main().catch((error) => {
  console.error('PERMISSIONS_TEST_ERROR:', error.message);
  process.exitCode = 1;
});
