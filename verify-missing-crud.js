const request = require('supertest');
const app = require('./app');
const proveedorRepository = require('./src/repositories/proveedor.repository');
const unidadRepository = require('./src/repositories/unidad.repository');
const { sequelize } = require('./src/config/database.config');

async function main() {
  try {
    const providerUpdate = await proveedorRepository.update(999999, { nombre: 'No existe' });
    const providerDelete = await proveedorRepository.delete(999999);
    const unitUpdate = await unidadRepository.update(999999, { nombre: 'No existe' });
    const unitDelete = await unidadRepository.delete(999999);

    console.log('PROVEEDOR_REPOSITORY_UPDATE_999999:', providerUpdate);
    console.log('PROVEEDOR_REPOSITORY_DELETE_999999:', providerDelete);
    console.log('UNIDAD_REPOSITORY_UPDATE_999999:', unitUpdate);
    console.log('UNIDAD_REPOSITORY_DELETE_999999:', unitDelete);

    const providerUpdateHttp = await request(app).put('/proveedores/999999').send({ nombre: 'No existe' });
    const providerDeleteHttp = await request(app).delete('/proveedores/999999');
    const unitUpdateHttp = await request(app).put('/unidades/999999').send({ nombre: 'No existe' });
    const unitDeleteHttp = await request(app).delete('/unidades/999999');

    for (const [label, response] of [
      ['PROVEEDOR_UPDATE_HTTP', providerUpdateHttp],
      ['PROVEEDOR_DELETE_HTTP', providerDeleteHttp],
      ['UNIDAD_UPDATE_HTTP', unitUpdateHttp],
      ['UNIDAD_DELETE_HTTP', unitDeleteHttp],
    ]) {
      console.log(`${label}_STATUS:`, response.statusCode);
      console.log(`${label}_JSON:`, JSON.stringify(response.body));
      if (response.statusCode !== 404 || response.body.success !== false) {
        throw new Error(`${label} no tradujo el registro ausente a 404`);
      }
    }
  } finally {
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('MISSING_CRUD_ERROR:', error.message);
  process.exitCode = 1;
});
