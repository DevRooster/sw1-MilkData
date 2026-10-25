const {
  app, request, login, auth, closeDatabase, plantaPrincipal, CREDENCIALES_INICIO,
  tokenForRole, cleanupTestUsers,
} = require('../helpers/auth');

let token;

beforeAll(async () => {
  token = await login();
});

afterAll(closeDatabase);

describe('POST /auth/login', () => {
  test('devuelve token y usuario sin password', async () => {
    const response = await request(app).post('/auth/login').send({
      email: CREDENCIALES_INICIO.email, password: CREDENCIALES_INICIO.password,
    });

    expect(response.statusCode).toBe(200);
    expect(response.body.data.token).toBeTruthy();
    expect(response.body.data.user.email).toBe('admin@milkdata.com');
    expect(response.body.data.user.password).toBeUndefined();
  });

  test('el token incluye la planta del usuario', async () => {
    const response = await request(app).post('/auth/login').send({
      email: CREDENCIALES_INICIO.email, password: CREDENCIALES_INICIO.password,
    });
    const { verifyToken } = require('../../src/security/auth.service');
    const payload = await verifyToken(response.body.data.token);

    const planta = await plantaPrincipal();
    expect(payload.plantaId).toBe(planta.id);
  });

  test('rechaza credenciales invalidas con 401', async () => {
    const response = await request(app).post('/auth/login').send({
      email: 'admin@milkdata.com', password: 'incorrecta',
    });

    expect(response.statusCode).toBe(401);
    expect(response.body.success).toBe(false);
  });

  test('rechaza emails inexistentes con 401', async () => {
    const response = await request(app).post('/auth/login').send({
      email: 'nadie@milkdata.com', password: 'Admin123!',
    });

    expect(response.statusCode).toBe(401);
  });
});

describe('POST /auth/verify', () => {
  test('confirma un token valido', async () => {
    const response = await request(app).post('/auth/verify').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.user.email).toBe('admin@milkdata.com');
    expect(response.body.data.user.plantaId).toBeTruthy();
  });

  test('exige token', async () => {
    expect((await request(app).post('/auth/verify')).statusCode).toBe(401);
  });
});

describe('POST /auth/refresh', () => {
  test('emite un token nuevo verificable que conserva la planta', async () => {
    const response = await request(app).post('/auth/refresh').set(auth(token));

    expect(response.statusCode).toBe(200);

    const verificado = await request(app).post('/auth/verify').set(auth(response.body.data.token));
    expect(verificado.statusCode).toBe(200);
    expect(verificado.body.data.user.plantaId).toBeTruthy();
  });

  test('exige token', async () => {
    expect((await request(app).post('/auth/refresh')).statusCode).toBe(401);
  });
});

describe('POST /auth/logout', () => {
  test('confirma el cierre', async () => {
    const response = await request(app).post('/auth/logout').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.success).toBe(true);
  });

  test('exige token', async () => {
    expect((await request(app).post('/auth/logout')).statusCode).toBe(401);
  });
});

describe('GET /health', () => {
  test('responde sin autenticacion', async () => {
    const response = await request(app).get('/health');

    expect(response.statusCode).toBe(200);
    expect(response.body.data.status).toBe('ok');
  });
});

describe('Documentacion', () => {
  test('/api-docs.json expone el spec OpenAPI', async () => {
    const response = await request(app).get('/api-docs.json');

    expect(response.statusCode).toBe(200);
    expect(response.body.openapi).toBe('3.0.0');
    const paths = Object.keys(response.body.paths);
    expect(paths.length).toBeGreaterThan(40);
    expect(paths).toContain('/recolecciones');
    expect(paths).toContain('/plantas');
    expect(paths).not.toContain('/entregas');
  });

  test('/api-docs sirve la interfaz Swagger', async () => {
    expect((await request(app).get('/api-docs/')).statusCode).toBe(200);
  });
});

/**
 * `GET /auth/permisos` existe para que el móvil dibuje su menú con lo que la API
 * va a responderle. Su valor está entero en que no mienta, así que la prueba
 * importante es la última: compara lo que dice el endpoint contra lo que hace de
 * verdad `authorizeMiddleware`, recurso por recurso.
 */
describe('GET /auth/permisos', () => {
  const sufijoPermisos = `perm${Date.now().toString(36)}`;

  /** Ruta de listado de cada recurso, para comprobarla por HTTP. */
  const RECURSO_A_RUTA = {
    plantas: '/plantas',
    proveedores: '/proveedores',
    unidades: '/unidades',
    zonas: '/zonas',
    rutas: '/rutas',
    recorridos: '/recorridos',
    recolecciones: '/recolecciones',
    calidad: '/calidad',
    notificaciones: '/notificaciones',
    asistencias: '/asistencias',
    productos: '/productos',
    usuarios: '/usuarios',
  };

  afterAll(() => cleanupTestUsers(sufijoPermisos));

  test('devuelve el rol y los recursos del token', async () => {
    const response = await request(app).get('/auth/permisos').set(auth(token));

    expect(response.statusCode).toBe(200);
    expect(response.body.data.rol).toBe('superadmin');
    expect(response.body.data.superadmin).toBe(true);
    expect(typeof response.body.data.recursos).toBe('object');
    expect(Object.keys(response.body.data.recursos).length).toBeGreaterThan(0);
  });

  test('el superadmin puede escribir en todo', async () => {
    const { data } = (await request(app).get('/auth/permisos').set(auth(token))).body;

    const { RECURSOS } = require('../../src/security/role-permissions.config');
    for (const recurso of RECURSOS) {
      expect(data.recursos[recurso]).toContain('write');
    }
  });

  test('exige token', async () => {
    expect((await request(app).get('/auth/permisos')).statusCode).toBe(401);
  });

  test('un rol sin permiso no recibe el recurso con la lista vacía', async () => {
    // Viene ausente, no con `[]`: así el lanzador no tiene que decidir qué
    // hacer con lo que no se puede usar.
    const tokenAcopiador = await tokenForRole('acopiador', sufijoPermisos);
    const { data } = (await request(app).get('/auth/permisos').set(auth(tokenAcopiador))).body;

    expect(data.recursos.usuarios).toBeUndefined();
    expect(data.recursos.plantas).toBeUndefined();
    // Y lo que sí puede, lo puede escribir.
    expect(data.recursos.recolecciones).toEqual(['read', 'write']);
  });

  test('lo que promete el endpoint es lo que hace la API', async () => {
    const tokenAcopiador = await tokenForRole('acopiador', sufijoPermisos);
    const { data } = (await request(app).get('/auth/permisos').set(auth(tokenAcopiador))).body;

    // Se recorren todos los recursos con ruta de listado. Los que el endpoint
    // concede tienen que pasar de verdad, y los que no tienen que recibir 403.
    // Si alguien cambia la matriz en un sitio y no en el otro, esto falla.
    for (const [recurso, ruta] of Object.entries(RECURSO_A_RUTA)) {
      const response = await request(app).get(ruta).set(auth(tokenAcopiador));
      const prometido = Boolean(data.recursos[recurso]);

      if (prometido) {
        expect(response.statusCode).not.toBe(403);
      } else {
        expect(response.statusCode).toBe(403);
      }
    }
  });

  test('el laboratorio no puede ni leer unidades', async () => {
    // El caso que motivó el endpoint: un rol al que hay que esconderle un
    // módulo entero.
    const tokenLab = await tokenForRole('laboratorio', sufijoPermisos);
    const { data } = (await request(app).get('/auth/permisos').set(auth(tokenLab))).body;

    expect(data.recursos.unidades).toBeUndefined();
    expect((await request(app).get('/unidades').set(auth(tokenLab))).statusCode).toBe(403);
    expect(data.recursos.calidad).toContain('write');
  });
});
