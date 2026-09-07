const request = require('supertest');
const app = require('../../app');
const proveedorRepository = require('../../src/repositories/proveedor.repository');
const unidadRepository = require('../../src/repositories/unidad.repository');
const { sequelize } = require('../../src/config/database.config');

describe('CRUD para registros inexistentes', () => {
  afterAll(async () => {
    await sequelize.close();
  });

  test('repositories devuelven null y controllers devuelven 404', async () => {
    await expect(proveedorRepository.update(999999, { nombre: 'No existe' })).resolves.toBeNull();
    await expect(proveedorRepository.delete(999999)).resolves.toBeNull();
    await expect(unidadRepository.update(999999, { nombre: 'No existe' })).resolves.toBeNull();
    await expect(unidadRepository.delete(999999)).resolves.toBeNull();

    const responses = await Promise.all([
      request(app).put('/proveedores/999999').send({ nombre: 'No existe' }),
      request(app).delete('/proveedores/999999'),
      request(app).put('/unidades/999999').send({ nombre: 'No existe' }),
      request(app).delete('/unidades/999999'),
    ]);

    for (const response of responses) {
      expect(response.statusCode).toBe(404);
      expect(response.body).toEqual({
        success: false,
        data: null,
        message: 'Registro no encontrado.',
        errors: ['Registro no encontrado.'],
      });
    }
  });
});
