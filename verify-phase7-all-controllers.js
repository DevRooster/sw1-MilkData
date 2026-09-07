const express = require('express');
const request = require('supertest');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor } = require('./src/entities');
const fase7Routes = require('./src/routes/index.routes');
const { errorMiddleware } = require('./src/middlewares/error.middleware');

const app = express();
app.use(express.json());
app.use('/', fase7Routes);
app.use(errorMiddleware);

function assertLayer(response, label) {
  const trace = response.body.data && response.body.data.layerTrace;
  if (response.statusCode < 200 || response.statusCode >= 300 || JSON.stringify(trace) !== JSON.stringify(['routes', 'controller', 'service', 'repository'])) {
    throw new Error(`${label} inválido: status=${response.statusCode}, trace=${JSON.stringify(trace)}, body=${JSON.stringify(response.body)}`);
  }
}

async function main() {
  const suffix = Date.now().toString();
  const roleName = `fase7_${suffix}`;
  const email = `fase7_${suffix}@example.com`;
  let role;
  let user;
  let provider;

  try {
    role = await Rol.create({ nombre: roleName, descripcion: 'Rol temporal Fase 7', nivel: 1, activo: true });

    const register = await request(app).post('/auth/register').send({
      nombre: 'Fase', apellido: 'Siete', email, password: 'Admin123!', rolId: role.id,
    });
    assertLayer(register, 'AUTH_REGISTER');
    user = await Usuario.findByPk(register.body.data.user.id);

    const login = await request(app).post('/auth/login').send({ email, password: 'Admin123!' });
    assertLayer(login, 'AUTH_LOGIN');

    const providerResponse = await request(app).post('/proveedores').send({
      nombre: 'Proveedor', apellido: 'Fase7', dni: `D${suffix}`, codigo: `C${suffix}`, activo: true,
    });
    assertLayer(providerResponse, 'PROVEEDOR');
    provider = await Proveedor.findByPk(providerResponse.body.data.proveedor.id);

    const requests = [
      ['UNIDAD', '/unidades'],
      ['ZONA', '/zonas'],
      ['ENTREGA', '/entregas'],
      ['CALIDAD', '/calidad'],
      ['NOTIFICACION', '/notificaciones'],
      ['ASISTENCIA', '/asistencias'],
      ['REPORTE_CONTRASTE', '/reportes/contraste'],
      ['REPORTE_CALIDAD', '/reportes/calidad'],
      ['REPORTE_CALIDAD_PROVEEDOR', '/reportes/calidad-proveedor'],
    ];

    const results = [];
    for (const [label, path] of requests) {
      const response = await request(app).get(path);
      assertLayer(response, label);
      results.push({ label, status: response.statusCode, trace: response.body.data.layerTrace });
    }

    console.log('AUTH_REGISTER_REQUEST: POST /auth/register');
    console.log('AUTH_REGISTER_RESPONSE_JSON:', JSON.stringify(register.body));
    console.log('AUTH_LOGIN_REQUEST: POST /auth/login');
    console.log('AUTH_LOGIN_RESPONSE_JSON:', JSON.stringify(login.body));
    console.log('CONTROLLER_STATUS_SUMMARY:', JSON.stringify([
      { label: 'AUTH_REGISTER', status: register.statusCode, trace: register.body.data.layerTrace },
      { label: 'AUTH_LOGIN', status: login.statusCode, trace: login.body.data.layerTrace },
      { label: 'PROVEEDOR', status: providerResponse.statusCode, trace: providerResponse.body.data.layerTrace },
      ...results,
    ]));
  } finally {
    if (provider) await Proveedor.destroy({ where: { id: provider.id } });
    if (user) await Usuario.destroy({ where: { id: user.id } });
    if (role) await Rol.destroy({ where: { id: role.id } });
    console.log('CLEANUP_PHASE7_AUTH_AND_PROVIDER: COMPLETE');
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('PHASE7_CONTROLLERS_ERROR:', error.message);
  process.exitCode = 1;
});
