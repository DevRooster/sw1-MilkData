/**
 * El flujo completo del acopiador, de punta a punta y en orden.
 *
 * Las otras suites verifican cada endpoint por separado. Esta recorre el día
 * de trabajo tal como lo vive el chófer en el móvil: entrar, ver su ruta,
 * arrancar, recolectar en cada parada y cerrar. Si algo se rompe en el camino
 * entre dos endpoints, aquí se nota.
 */
const { app, request, auth, closeDatabase } = require('../helpers/auth');
const { Rol, Planta, Usuario } = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');
const { crearEscenario, crearUnidad, limpiar, Planta: PlantaEntity } = require('../helpers/rutas');

const sufijo = `flujo${Date.now().toString(36)}`;
const CRED = 'Acopiador123!';

let planta;
let tokenAcopiador;
let tokenAdmin;
let zona;
let unidad;
let proveedores;
let ruta;
let recorridoId;
let paradasDelRecorrido;

beforeAll(async () => {
  planta = await PlantaEntity.findOne({ where: { codigo: 'HUA' } });
  if (!planta) throw new Error('Ejecuta el seed primero: pnpm run seed');

  const rolAcopiador = await Rol.findOne({ where: { nombre: 'acopiador' } });
  const rolAdmin = await Rol.findOne({ where: { nombre: 'admin' } });

  const chof = await Usuario.create({
    nombre: 'César', apellido: 'Quispe',
    email: `acopiador.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAcopiador.id, plantaId: planta.id, activo: true,
  });
  tokenAcopiador = await securityAuthService.signToken({
    sub: chof.id, email: chof.email, rol: 'acopiador',
    rolId: rolAcopiador.id, plantaId: planta.id,
  });

  const admin = await Usuario.create({
    nombre: 'Jefe', apellido: 'Planta',
    email: `admin.${sufijo}@test.com`,
    password: await securityAuthService.hashPassword(CRED),
    rolId: rolAdmin.id, plantaId: planta.id, activo: true,
  });
  tokenAdmin = await securityAuthService.signToken({
    sub: admin.id, email: admin.email, rol: 'admin',
    rolId: rolAdmin.id, plantaId: planta.id,
  });

  ({ zona, ruta, proveedores } = await crearEscenario({ planta, sufijo, paradas: 3 }));
  unidad = await crearUnidad({ planta, acopiador: chof, sufijo });
});

afterAll(async () => {
  await limpiar({ plantaId: planta.id, sufijo });
  await closeDatabase();
});

describe('El día del acopiador', () => {
  test('1. entra con su usuario', async () => {
    const r = await request(app)
      .post('/auth/login')
      .send({ email: `acopiador.${sufijo}@test.com`, password: CRED });

    expect(r.statusCode).toBe(200);
    expect(r.body.data.token).toBeTruthy();
    // El rol llega como objeto; el móvil lee `rol.nombre`.
    expect(r.body.data.user.rol.nombre).toBe('acopiador');
    expect(r.body.data.user.plantaId).toBe(planta.id);
  });

  test('2. la planta le asignó una unidad con él como acopiador', async () => {
    const r = await request(app).get(`/unidades/${unidad.id}`).set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.item.acopiadorId).toBeTruthy();
  });

  test('3. ve las rutas disponibles', async () => {
    const r = await request(app).get('/rutas').set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    const propia = r.body.data.items.find((x) => x.id === ruta.id);
    expect(propia.nombre).toBe(ruta.nombre);
    expect(propia.paradas).toBe(3);
  });

  test('4. abre su ruta y ve las paradas en orden, con a dónde ir', async () => {
    const r = await request(app).get(`/rutas/${ruta.id}`).set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    const paradas = r.body.data.item.paradas;
    expect(paradas.map((p) => p.orden)).toEqual([1, 2, 3]);

    // Cada parada debe bring lo que el móvil necesita sin llamadas extra.
    for (const parada of paradas) {
      expect(parada.proveedor.nombre).toBeTruthy();
      expect(parada.proveedor.dni).toBeTruthy();
      expect(parada.proveedor.telefono).toBeTruthy();
      expect(parada.proveedor.direccion).toBeTruthy();
    }
    expect(paradas[0].horaEstimada).toMatch(/^\d{2}:\d{2}:\d{2}$/);
  });

  test('5. no puede cambiar el orden de la ruta', async () => {
    const r = await request(app)
      .post(`/rutas/${ruta.id}/paradas`)
      .set(auth(tokenAcopiador))
      .send({ proveedorId: proveedores[0].id });

    expect(r.statusCode).toBe(403);
  });

  test('6. planifica el recorrido con su ayudante externo', async () => {
    const r = await request(app)
      .post('/recorridos')
      .set(auth(tokenAcopiador))
      .send({
        rutaId: ruta.id,
        unidadId: unidad.id,
        ayudanteNombre: 'Luis',
        ayudanteApellido: 'Ayuda',
        ayudanteDni: '70555444',
        ayudanteCelular: '987111222',
      });

    expect(r.statusCode).toBe(201);
    expect(r.body.data.item.estado).toBe('PLANIFICADO');
    expect(r.body.data.item.ayudanteNombre).toBe('Luis');
    expect(r.body.data.item.ayudanteDni).toBe('70555444');
    recorridoId = r.body.data.item.id;
  });

  test('7. todavía no tiene nada en su recorrido actual', async () => {
    const r = await request(app).get('/recorridos/actual').set(auth(tokenAcopiador));
    expect(r.body.data.item).toBeNull();
  });

  test('8. marca EN RUTA: ahí arranca el día', async () => {
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/iniciar`)
      .set(auth(tokenAcopiador))
      .send({ kilometrajeInicio: 12000 });

    expect(r.statusCode).toBe(200);
    const item = r.body.data.item;
    expect(item.estado).toBe('EN_RUTA');
    expect(item.horaInicio).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    expect(item.kilometrajeInicio).toBe(12000);
    expect(item.paradas).toHaveLength(3);
    paradasDelRecorrido = item.paradas;
  });

  test('9. su recorrido actual es este', async () => {
    const r = await request(app).get('/recorridos/actual').set(auth(tokenAcopiador));
    expect(r.body.data.item.id).toBe(recorridoId);
  });

  test('10. la ruta recomendada le muestra lo que falta', async () => {
    const r = await request(app)
      .get(`/rutas/${ruta.id}/recomendada?recorridoId=${recorridoId}`)
      .set(auth(tokenAcopiador));

    expect(r.statusCode).toBe(200);
    expect(r.body.data.ruta.paradas.map((p) => p.estado))
      .toEqual(['PENDIENTE', 'PENDIENTE', 'PENDIENTE']);
  });

  test('11. recolecta en la primera parada', async () => {
    const primera = paradasDelRecorrido[0];
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/paradas/${primera.id}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 32.5, temperatura: 5.8 });

    expect(r.statusCode).toBe(201);
    const atendida = r.body.data.item.paradas.find((p) => p.id === primera.id);
    expect(atendida.estado).toBe('ATENDIDA');
    expect(atendida.litros).toBe(32.5);
    expect(atendida.recoleccionId).toBeTruthy();
    expect(atendida.horaLlegada).toBeTruthy();
  });

  test('12. el proveedor no estaba, la marca OMITIDA', async () => {
    const segunda = paradasDelRecorrido[1];
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/paradas/${segunda.id}/atender`)
      .set(auth(tokenAcopiador))
      .send({ estado: 'OMITIDA', observaciones: 'No estaba en la finca' });

    expect(r.statusCode).toBe(200);
    const omitida = r.body.data.item.paradas.find((p) => p.id === segunda.id);
    expect(omitida.estado).toBe('OMITIDA');
    expect(omitida.observaciones).toBe('No estaba en la finca');
  });

  test('13. recolecta en la última parada', async () => {
    const tercera = paradasDelRecorrido[2];
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/paradas/${tercera.id}/recolectar`)
      .set(auth(tokenAcopiador))
      .send({ cantidad: 18 });

    expect(r.statusCode).toBe(201);
    expect(r.body.data.item.paradas.find((p) => p.id === tercera.id).litros).toBe(18);
  });

  test('14. el recorrido ya refleja lo que hizo', async () => {
    const r = await request(app)
      .get(`/recorridos/${recorridoId}`)
      .set(auth(tokenAcopiador));

    const item = r.body.data.item;
    expect(item.estado).toBe('EN_RUTA');
    expect(item.paradas.map((p) => p.estado))
      .toEqual(['ATENDIDA', 'OMITIDA', 'ATENDIDA']);
    expect(item.ruta.nombre).toBe(ruta.nombre);
    expect(item.unidad.nombre).toBe(unidad.nombre);
  });

  test('15. la planta ve la recolección en su reporte', async () => {
    const r = await request(app)
      .get(`/reportes/calidad/proveedor/${proveedores[0].id}`)
      .set(auth(tokenAdmin));

    expect(r.statusCode).toBe(200);
  });

  test('16. finaliza el recorrido', async () => {
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/finalizar`)
      .set(auth(tokenAcopiador))
      .send({ kilometrajeFin: 12048, observaciones: 'Vuelta completa' });

    expect(r.statusCode).toBe(200);
    const item = r.body.data.item;
    expect(item.estado).toBe('FINALIZADO');
    expect(item.horaFin).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    expect(item.kilometrajeFin).toBe(12048);
    expect(item.kilometrajeFin - item.kilometrajeInicio).toBe(48);
  });

  test('17. ya no tiene recorrido en curso', async () => {
    const r = await request(app).get('/recorridos/actual').set(auth(tokenAcopiador));
    expect(r.body.data.item).toBeNull();
  });

  test('18. las recolecciones quedaron enlazadas a sus paradas', async () => {
    const { Recoleccion } = require('../../src/entities');
    const { Op } = require('sequelize');

    const delDia = await Recoleccion.findAll({
      where: { recorridoParadaId: { [Op.not]: null }, plantaId: planta.id },
      include: [{ association: 'proveedor', where: { id: proveedores.map((p) => p.id) } }],
    });

    expect(delDia).toHaveLength(2);
    for (const recoleccion of delDia) {
      expect(recoleccion.recorridoParadaId).toBeTruthy();
      expect(recoleccion.cantidad).toBeGreaterThan(0);
      expect(recoleccion.unidadId).toBe(unidad.id);
      expect(recoleccion.zonaId).toBe(zona.id);
    }
  });

  test('19. no puede volver a abrir el recorrido', async () => {
    const r = await request(app)
      .post(`/recorridos/${recorridoId}/iniciar`)
      .set(auth(tokenAcopiador))
      .send({});

    expect(r.statusCode).toBe(400);
  });
});
