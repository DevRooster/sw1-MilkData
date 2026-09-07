const express = require('express');
const request = require('supertest');
const { sequelize } = require('./src/config/database.config');
const { Proveedor } = require('./src/entities');
const proveedorRoutes = require('./src/routes/proveedor.routes');
const { errorMiddleware } = require('./src/middlewares/error.middleware');

const app = express();
app.use(express.json());
app.use('/', proveedorRoutes);
app.use(errorMiddleware);

async function main() {
  const suffix = Date.now().toString();
  const payload = {
    nombre: 'Prueba',
    apellido: 'Fase7',
    dni: `T${suffix}`.slice(-20),
    telefono: '999999999',
    codigo: `F7-${suffix}`.slice(-50),
    activo: true,
  };

  let createdId;
  try {
    const response = await request(app)
      .post('/proveedores')
      .send(payload);

    console.log('HTTP_REQUEST: POST /proveedores');
    console.log('HTTP_STATUS:', response.statusCode);
    console.log('HTTP_RESPONSE_JSON:', JSON.stringify(response.body));

    createdId = response.body.data && response.body.data.proveedor && response.body.data.proveedor.id;
    const trace = response.body.data && response.body.data.layerTrace;
    if (response.statusCode !== 201 || JSON.stringify(trace) !== JSON.stringify(['routes', 'controller', 'service', 'repository'])) {
      throw new Error(`La prueba de capas falló: status=${response.statusCode}, trace=${JSON.stringify(trace)}`);
    }
  } finally {
    if (createdId) {
      await Proveedor.destroy({ where: { id: createdId } });
      console.log('CLEANUP_CREATED_PROVIDER_ID:', createdId);
    }
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('PHASE7_HTTP_ERROR:', error.message);
  process.exitCode = 1;
});
