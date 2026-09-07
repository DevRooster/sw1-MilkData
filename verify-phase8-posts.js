const request = require('supertest');
const app = require('./app');
const { sequelize } = require('./src/config/database.config');
const { Rol, Usuario, Proveedor, Unidad, Zona, Entrega, ControlCalidad, Notificacion, Asistencia } = require('./src/entities');
const securityAuthService = require('./src/security/auth.service');

function assertResponse(label, response) {
  const trace = response.body.data && response.body.data.layerTrace;
  if (response.statusCode < 200 || response.statusCode >= 300 || JSON.stringify(trace) !== JSON.stringify(['routes', 'controller', 'service', 'repository'])) {
    throw new Error(`${label} inválido: status=${response.statusCode}, body=${JSON.stringify(response.body)}`);
  }
  console.log(`${label}_STATUS:`, response.statusCode);
  console.log(`${label}_JSON:`, JSON.stringify(response.body));
}

async function main() {
  const suffix = Date.now().toString();
  const created = { role: null, user: null, provider: null, unidad: null, zona: null, entrega: null, calidad: null, notificacion: null, asistencia: null };

  try {
    created.role = await Rol.create({ nombre: `fase8_${suffix}`, descripcion: 'Rol temporal Fase 8', nivel: 1, activo: true });
    created.user = await Usuario.create({
      nombre: 'Usuario', apellido: 'Fase8', email: `fase8_${suffix}@example.com`,
      password: await securityAuthService.hashPassword('Admin123!'), rolId: created.role.id, activo: true,
    });

    const proveedorResponse = await request(app).post('/proveedores').send({
      nombre: 'Proveedor', apellido: 'Fase8', dni: `D${suffix}`, codigo: `C${suffix}`, activo: true,
    });
    assertResponse('PROVEEDOR_SETUP', proveedorResponse);
    created.provider = await Proveedor.findByPk(proveedorResponse.body.data.proveedor.id);

    const unidadResponse = await request(app).post('/unidades').send({ nombre: `Unidad ${suffix}`, tipo: 'furgon', capacidad: 1000, cerrado: false, activo: true });
    assertResponse('UNIDAD_POST', unidadResponse);
    created.unidad = await Unidad.findByPk(unidadResponse.body.data.item.id);

    const zonaResponse = await request(app).post('/zonas').send({ nombre: `Zona ${suffix}`, ruta: 'Ruta Fase 8', horaInicio: '06:00:00', horaFin: '12:00:00', unidadId: created.unidad.id, activo: true });
    assertResponse('ZONA_POST', zonaResponse);
    created.zona = await Zona.findByPk(zonaResponse.body.data.item.id);

    const entregaResponse = await request(app).post('/entregas').send({
      proveedorId: created.provider.id, zonaId: created.zona.id, unidadId: created.unidad.id, usuarioId: created.user.id,
      cantidad: 25, fecha: '2026-09-07', hora: '08:00:00', temperatura: 4, registradoEn: 'campo', sincronizado: false,
    });
    assertResponse('ENTREGA_POST', entregaResponse);
    created.entrega = await Entrega.findByPk(entregaResponse.body.data.item.id);

    const calidadResponse = await request(app).post('/calidad').send({
      entregaId: created.entrega.id, usuarioId: created.user.id, grasa: 3.5, proteina: 3.2,
      lactosa: 4.7, densidad: 1.03, temperatura: 4, aguaAnadida: 0, ph: 6.7, resultado: 'pura',
    });
    assertResponse('CALIDAD_POST', calidadResponse);
    created.calidad = await ControlCalidad.findByPk(calidadResponse.body.data.item.id);

    const notificacionResponse = await request(app).post('/notificaciones').send({
      proveedorId: created.provider.id, usuarioId: created.user.id, tipo: 'reunion',
      titulo: 'Aviso Fase 8', mensaje: 'Notificación de prueba', leida: false, enviada: false,
    });
    assertResponse('NOTIFICACION_POST', notificacionResponse);
    created.notificacion = await Notificacion.findByPk(notificacionResponse.body.data.item.id);

    const asistenciaResponse = await request(app).post('/asistencias').send({
      proveedorId: created.provider.id, usuarioId: created.user.id, evento: 'Capacitación Fase 8', fecha: '2026-09-07', registradoPor: 'manual',
    });
    assertResponse('ASISTENCIA_POST', asistenciaResponse);
    created.asistencia = await Asistencia.findByPk(asistenciaResponse.body.data.item.id);
  } finally {
    if (created.asistencia) await Asistencia.destroy({ where: { id: created.asistencia.id } });
    if (created.notificacion) await Notificacion.destroy({ where: { id: created.notificacion.id } });
    if (created.calidad) await ControlCalidad.destroy({ where: { id: created.calidad.id } });
    if (created.entrega) await Entrega.destroy({ where: { id: created.entrega.id } });
    if (created.zona) await Zona.destroy({ where: { id: created.zona.id } });
    if (created.unidad) await Unidad.destroy({ where: { id: created.unidad.id } });
    if (created.provider) await Proveedor.destroy({ where: { id: created.provider.id } });
    if (created.user) await Usuario.destroy({ where: { id: created.user.id } });
    if (created.role) await Rol.destroy({ where: { id: created.role.id } });
    console.log('CLEANUP_PHASE8_POSTS: COMPLETE');
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('PHASE8_POST_ERROR:', error.message);
  process.exitCode = 1;
});
