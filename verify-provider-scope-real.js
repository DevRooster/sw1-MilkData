const request = require('supertest');
const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor, Unidad, Zona, Entrega } = require('./src/entities');
const bcrypt = require('bcryptjs');

async function main() {
  const suffix = Date.now().toString();
  let role;
  let user;
  let providerA;
  let providerB;
  let unit;
  let zone;
  let delivery;
  try {
    role = await Rol.create({ nombre: `scope_${suffix}`, descripcion: 'scope test', nivel: 1, activo: true });
    user = await Usuario.create({ nombre: 'Scope', apellido: 'Test', email: `scope_${suffix}@example.com`, password: await bcrypt.hash('Scope123!', 10), rolId: role.id, activo: true });
    unit = await Unidad.create({ nombre: `Scope Unit ${suffix}`, tipo: 'furgon', capacidad: 100, cerrado: false, activo: true });
    zone = await Zona.create({ nombre: `Scope Zone ${suffix}`, ruta: 'Scope', unidadId: unit.id, activo: true });
    providerA = await Proveedor.create({ nombre: 'A', apellido: 'Provider', dni: `A${suffix}`, codigo: `A${suffix}`, zonaId: zone.id, activo: true });
    providerB = await Proveedor.create({ nombre: 'B', apellido: 'Provider', dni: `B${suffix}`, codigo: `B${suffix}`, zonaId: zone.id, activo: true });
    delivery = await Entrega.create({ proveedorId: providerB.id, zonaId: zone.id, unidadId: unit.id, usuarioId: user.id, cantidad: 7, fecha: '2026-09-07', registradoEn: 'campo', sincronizado: false });

    const login = await request(app).post('/auth/login').send({ email: user.email, password: 'Scope123!' });
    const token = login.body.data.token;
    const response = await request(app).get(`/entregas/proveedor/${providerB.id}`).set('Authorization', `Bearer ${token}`);
    console.log('OTHER_PROVIDER_ID:', providerB.id);
    console.log('OWN_PROVIDER_ID:', providerA.id);
    console.log('OTHER_PROVIDER_DELIVERY_ID:', delivery.id);
    console.log('GET_OTHER_PROVIDER_STATUS:', response.statusCode);
    console.log('GET_OTHER_PROVIDER_JSON:', JSON.stringify(response.body));
    console.log('SCOPE_ENFORCED:', response.statusCode === 403 ? true : false);
  } finally {
    if (delivery) await Entrega.destroy({ where: { id: delivery.id } });
    if (providerA || providerB) await Proveedor.destroy({ where: { id: [providerA, providerB].filter(Boolean).map((item) => item.id) } });
    if (zone) await Zona.destroy({ where: { id: zone.id } });
    if (unit) await Unidad.destroy({ where: { id: unit.id } });
    if (user) await Usuario.destroy({ where: { id: user.id } });
    if (role) await Rol.destroy({ where: { id: role.id } });
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('SCOPE_TEST_ERROR:', error.message);
  process.exitCode = 1;
});
