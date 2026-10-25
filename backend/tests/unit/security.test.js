const permissionsService = require('../../src/security/permissions.service');
const { ROLES, PERMISOS, RECURSOS } = require('../../src/security/role-permissions.config');
const securityAuthService = require('../../src/security/auth.service');
const { withRetry } = require('../../src/resilience/retry');
const { createResilientNotificationSender } = require('../../src/resilience/notification.sender');
const { NotificacionService } = require('../../src/services/impl/notificacion.service');
const { httpError, notFound, unauthorized, forbidden, badRequest } = require('../../src/utils/http-error');

const CTX = { plantaId: 3 };

describe('Matriz de permisos por rol', () => {
  test('admin tiene acceso total', () => {
    const admin = { rol: ROLES.admin };
    expect(permissionsService.can(admin, 'recolecciones', 'write')).toBe(true);
    expect(permissionsService.can(admin, 'reportes', 'read')).toBe(true);
    expect(permissionsService.isAdmin(admin)).toBe(true);
  });

  test('supervisor escribe en lo operativo pero no en reportes', () => {
    const supervisor = { rol: ROLES.supervisor };
    expect(permissionsService.can(supervisor, 'recolecciones', 'write')).toBe(true);
    expect(permissionsService.can(supervisor, 'reportes', 'read')).toBe(true);
    expect(permissionsService.can(supervisor, 'reportes', 'write')).toBe(false);
  });

  test('operador escribe en recolecciones y calidad', () => {
    const operador = { rol: ROLES.operador };
    expect(permissionsService.can(operador, 'recolecciones', 'write')).toBe(true);
    expect(permissionsService.can(operador, 'proveedores', 'write')).toBe(false);
    expect(permissionsService.can(operador, 'proveedores', 'read')).toBe(true);
  });

  test('laboratorio solo escribe en calidad', () => {
    const laboratorio = { rol: ROLES.laboratorio };
    expect(permissionsService.can(laboratorio, 'calidad', 'write')).toBe(true);
    expect(permissionsService.can(laboratorio, 'recolecciones', 'write')).toBe(false);
    expect(permissionsService.can(laboratorio, 'zonas', 'read')).toBe(false);
  });

  test('proveedor solo lee', () => {
    const proveedor = { rol: ROLES.proveedor };
    expect(permissionsService.can(proveedor, 'recolecciones', 'read')).toBe(true);
    expect(permissionsService.can(proveedor, 'recolecciones', 'write')).toBe(false);
    expect(permissionsService.can(proveedor, 'unidades', 'read')).toBe(false);
  });

  test('las tablas globales no se aíslan', () => {
    // `rol` y `planta` no son recursos de la matriz: el admin los maneja
    // globalmente y el resto de roles no los toca.
    expect(PERMISOS[ROLES.supervisor].rol).toBeUndefined();
    expect(PERMISOS[ROLES.proveedor].rol).toBeUndefined();
  });

  test('solo el superadmin escribe plantas', () => {
    for (const rol of Object.values(ROLES)) {
      expect(permissionsService.can({ rol }, 'plantas', 'write')).toBe(rol === ROLES.superadmin);
    }
  });

  test('admin y supervisor consultan la lista de plantas', () => {
    // El laboratorio y el proveedor no llegan a ver la lista de sedes.
    expect(permissionsService.can({ rol: ROLES.admin }, 'plantas', 'read')).toBe(true);
    expect(permissionsService.can({ rol: ROLES.supervisor }, 'plantas', 'read')).toBe(true);
    expect(permissionsService.can({ rol: ROLES.superadmin }, 'plantas', 'read')).toBe(true);
    expect(permissionsService.can({ rol: ROLES.proveedor }, 'plantas', 'read')).toBe(false);
    expect(permissionsService.can({ rol: ROLES.laboratorio }, 'plantas', 'read')).toBe(false);
  });

  test('el superadmin tiene los mismos permisos que el admin en el resto', () => {
    for (const recurso of RECURSOS.filter((r) => r !== 'plantas')) {
      expect(permissionsService.can({ rol: ROLES.superadmin }, recurso, 'write'))
        .toBe(permissionsService.can({ rol: ROLES.admin }, recurso, 'write'));
    }
  });

  test('isAdmin cubre al superadmin, que administra todas las plantas', () => {
    expect(permissionsService.isAdmin({ rol: ROLES.admin })).toBe(true);
    expect(permissionsService.isAdmin({ rol: ROLES.superadmin })).toBe(true);
    expect(permissionsService.isAdmin({ rol: ROLES.supervisor })).toBe(false);
  });

  test('solo el superadmin tiene alcance multi-planta', () => {
    expect(permissionsService.isSuperadmin({ rol: ROLES.superadmin })).toBe(true);
    expect(permissionsService.isSuperadmin({ rol: ROLES.admin })).toBe(false);
  });

  test('sin rol o rol desconocido no hay acceso', () => {
    expect(permissionsService.can(null, 'recolecciones', 'read')).toBe(false);
    expect(permissionsService.can({}, 'recolecciones', 'read')).toBe(false);
    expect(permissionsService.can({ rol: 'fantasma' }, 'recolecciones', 'read')).toBe(false);
  });

  test('la matriz no menciona el recurso antiguo entregas', () => {
    expect(RECURSOS).toContain('recolecciones');
    expect(RECURSOS).not.toContain('entregas');
    for (const permisos of Object.values(PERMISOS)) {
      expect(permisos.entregas).toBeUndefined();
    }
  });

  test('canAccess acepta rol, role y rolNombre', () => {
    expect(permissionsService.canAccess(null, 'admin')).toBe(false);
    expect(permissionsService.canAccess({ rol: 'admin' }, 'admin')).toBe(true);
    expect(permissionsService.canAccess({ role: 'admin' }, 'admin')).toBe(true);
    expect(permissionsService.canAccess({ rolNombre: 'admin' }, ['admin', 'supervisor'])).toBe(true);
    expect(permissionsService.canAccess({ rol: 'admin' })).toBe(true);
  });
});

describe('Errores HTTP tipados', () => {
  test('cada fabrica fija su statusCode', () => {
    expect(httpError('malo').statusCode).toBe(400);
    expect(notFound().statusCode).toBe(404);
    expect(unauthorized().statusCode).toBe(401);
    expect(forbidden().statusCode).toBe(403);
    expect(badRequest('x').statusCode).toBe(400);
  });
});

describe('Servicio de seguridad', () => {
  test('cifra, compara y firma tokens', async () => {
    const hash = await securityAuthService.hashPassword('secret');
    expect(await securityAuthService.comparePassword('secret', hash)).toBe(true);
    expect(await securityAuthService.comparePassword('malo', hash)).toBe(false);

    const token = await securityAuthService.signToken({ sub: 3, plantaId: 1 });
    expect((await securityAuthService.verifyToken(token)).sub).toBe(3);
  });

  test('verifyToken rechaza token vacio, expirado y manipulado con 401', async () => {
    await expect(securityAuthService.verifyToken()).rejects.toMatchObject({ statusCode: 401 });
    await expect(securityAuthService.verifyToken('no-es-un-jwt')).rejects.toMatchObject({
      statusCode: 401,
      message: 'Token inválido o expirado.',
    });
  });
});

describe('Retry y circuit breaker', () => {
  test('reintenta hasta agotar los intentos', async () => {
    let intentos = 0;
    const resultado = await withRetry(async () => {
      intentos += 1;
      if (intentos < 2) throw new Error('transitorio');
      return 'ok';
    }, { retries: 2 });

    expect(resultado).toBe('ok');
    expect(intentos).toBe(2);
  });

  test('propaga el error cuando se agotan los reintentos', async () => {
    let intentos = 0;
    await expect(withRetry(async () => {
      intentos += 1;
      throw new Error('definitivo');
    }, { retries: 2 })).rejects.toThrow('definitivo');
    expect(intentos).toBe(3);
  });

  test('notifica cada reintento en onRetry', async () => {
    const vistos = [];
    await expect(withRetry(async () => { throw new Error('x'); }, {
      retries: 1,
      onRetry: (intento) => vistos.push(intento),
    })).rejects.toThrow();
    expect(vistos).toEqual([1]);
  });

  test('el circuito abre tras superar el umbral de fallos', async () => {
    const sender = createResilientNotificationSender({
      externalSender: async () => { throw new Error('caído'); },
      retries: 0,
      volumeThreshold: 1,
    });

    await expect(sender.send({ id: 1 })).rejects.toThrow('caído');
    expect(sender.breaker.opened).toBe(true);
    await expect(sender.send({ id: 2 })).rejects.toThrow(/breaker is open/i);
  });
});

describe('NotificacionService.send', () => {
  /**
   * Un registro que sabe recargarse, como una instancia de Sequelize de verdad.
   *
   * `send` pasa la fila por `_conRelaciones()`, que la recarga para traer
   * proveedor y usuario. Un doble que devuelva un objeto pelado enseñaría que no
   * se recarga nunca, y la prueba dejaría de comprobar lo que dice comprobar.
   *
   * Lo que se apunta va en `avisado`, **fuera** del registro a propósito:
   * `send` devuelve el DTO, y el DTO solo copia las columnas que conoce, así que
   * un campo puesto en la propia fila desaparecería antes de poder mirarlo. Ya
   * pasó: la primera versión de esta prueba miraba `resultado.recargado` y
   * siempre salía `undefined`.
   */
  function registroQueRecarga(created, avisado) {
    return {
      id: 1,
      ...created[0],
      reload: async function recargar({ include } = {}) {
        avisado.recargado = Boolean(include);
        return this;
      },
    };
  }

  test('persiste con el plantaId de la sesión', async () => {
    const created = [];
    const avisado = {};
    const service = new NotificacionService({ send: async () => ({ accepted: true }) });
    service.repository = {
      create: async (data) => { created.push(data); return registroQueRecarga(created, avisado); },
    };

    const resultado = await service.send(CTX, { tipo: 'reunion', titulo: 'T', mensaje: 'M' });

    expect(resultado.plantaId).toBe(3);
    expect(resultado.enviada).toBe(true);
    expect(created[0].fechaEnvio).toBeInstanceOf(Date);
    // Y se recarga con las relaciones declaradas: sin eso la respuesta a un envío
    // saldría con el proveedor a `null`.
    expect(avisado.recargado).toBe(true);
  });

  test('ignora un plantaId enviado por el cliente', async () => {
    const created = [];
    const service = new NotificacionService({ send: async () => ({}) });
    service.repository = {
      create: async (data) => { created.push(data); return registroQueRecarga(created, {}); },
    };

    await service.send(CTX, { tipo: 'reunion', titulo: 'T', mensaje: 'M', plantaId: 99 });

    expect(created[0].plantaId).toBe(3);
  });

  test('sin relaciones que traer, no recarga', async () => {
    // El caso contrario: pedirle un `reload` a una fila que no lo necesita es
    // trabajo de más, y con `_incluir()` vacío el servicio no debería hacerlo.
    const created = [];
    const avisado = {};
    const service = new NotificacionService({ send: async () => ({}) });
    service._incluir = () => [];
    service.repository = {
      create: async (data) => { created.push(data); return registroQueRecarga(created, avisado); },
    };

    await service.send(CTX, { tipo: 'reunion', titulo: 'T', mensaje: 'M' });

    expect(avisado.recargado).toBeUndefined();
  });

  test('no persiste nada si el envio externo falla', async () => {
    const created = [];
    const service = new NotificacionService({
      send: async () => { throw new Error('externo caído'); },
    });
    service.repository = { create: async (data) => { created.push(data); } };

    await expect(service.send(CTX, { tipo: 'reunion' })).rejects.toThrow('externo caído');
    expect(created).toHaveLength(0);
  });
});
