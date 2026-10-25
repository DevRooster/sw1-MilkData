const jwt = require('jsonwebtoken');
const { authMiddleware } = require('../../src/middlewares/auth.middleware');
const { authorize } = require('../../src/middlewares/authorize.middleware');
const { errorMiddleware } = require('../../src/middlewares/error.middleware');
const { buildLoginRateLimiter } = require('../../src/middlewares/rateLimit.middleware');
const { jwtConfig } = require('../../src/config/auth.config');

function sign(payload, options = {}) {
  return jwt.sign(payload, jwtConfig.secret, { expiresIn: '1h', ...options });
}

describe('authMiddleware', () => {
  test('rechaza peticiones sin cabecera Authorization', async () => {
    const next = jest.fn();
    await authMiddleware({ headers: {} }, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  test('arma req.contexto con la planta del token', async () => {
    const next = jest.fn();
    const req = { headers: { authorization: `Bearer ${sign({ sub: 1, rol: 'admin', plantaId: 4 })}` } };

    await authMiddleware(req, {}, next);

    expect(next).toHaveBeenCalled();
    expect(req.contexto).toEqual({
      userId: 1,
      email: undefined,
      rol: 'admin',
      rolId: undefined,
      plantaId: 4,
      superadmin: false,
    });
  });

  test('marca el contexto como superadmin cuando el rol lo es', async () => {
    const next = jest.fn();
    const req = { headers: { authorization: `Bearer ${sign({ sub: 1, rol: 'superadmin', plantaId: 4 })}` } };

    await authMiddleware(req, {}, next);

    expect(req.contexto.superadmin).toBe(true);
    // Sigue operando en una sola planta: la del token.
    expect(req.contexto.plantaId).toBe(4);
  });

  test('un token sin plantaId se rechaza con 401', async () => {
    const next = jest.fn();
    const req = { headers: { authorization: `Bearer ${sign({ sub: 1, rol: 'admin' })}` } };

    await authMiddleware(req, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  test('propaga 401 con token expirado', async () => {
    const next = jest.fn();
    const req = { headers: { authorization: `Bearer ${sign({ sub: 1, plantaId: 1 }, { expiresIn: -1 })}` } };

    await authMiddleware(req, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  test('propaga 401 con firma manipulada', async () => {
    const next = jest.fn();
    const partes = sign({ sub: 1, plantaId: 1 }).split('.');
    const req = { headers: { authorization: `Bearer ${partes[0]}.${partes[1]}.firma-falsa` } };

    await authMiddleware(req, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });
});

describe('authorize', () => {
  test('permite cuando el rol tiene la operacion', () => {
    const next = jest.fn();
    authorize('recolecciones', 'write')({ user: { rol: 'admin' } }, {}, next);

    expect(next).toHaveBeenCalledWith();
  });

  test('bloquea con 403 cuando el rol no tiene la operacion', () => {
    const next = jest.fn();
    authorize('recolecciones', 'write')({ user: { rol: 'proveedor' } }, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });

  test('bloquea cuando no hay usuario', () => {
    const next = jest.fn();
    authorize('recolecciones', 'read')({}, {}, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });
});

describe('errorMiddleware', () => {
  function run(err) {
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
    errorMiddleware(err, {}, res, jest.fn());
    return { status: res.status.mock.calls[0][0], body: res.json.mock.calls[0][0] };
  }

  test('respeta el statusCode de la application', () => {
    const { status, body } = run({ statusCode: 404, message: 'Registro no encontrado.' });

    expect(status).toBe(404);
    expect(body).toEqual({
      success: false,
      data: null,
      message: 'Registro no encontrado.',
      errors: ['Registro no encontrado.'],
    });
  });

  test('traduce error de foreign key a 400', () => {
    const { status, body } = run({ name: 'SequelizeForeignKeyConstraintError' });

    expect(status).toBe(400);
    expect(body.message).toMatch(/referencia relacionada/i);
  });

  test('traduce error de valor unico duplicado a 400', () => {
    const { status, body } = run({ name: 'SequelizeUniqueConstraintError' });

    expect(status).toBe(400);
    expect(body.errors).toEqual(['Valor duplicado']);
  });

  test('traduce error de validacion a 400 con la lista de mensajes', () => {
    const { status, body } = run({
      name: 'SequelizeValidationError',
      errors: [{ message: 'nombre no puede estar vacío' }],
    });

    expect(status).toBe(400);
    expect(body.errors).toEqual(['nombre no puede estar vacío']);
  });

  test('un error sin statusCode responde 500 sin filtrar el mensaje interno', () => {
    const { status, body } = run(new Error('detalle interno'));

    expect(status).toBe(500);
    expect(body.message).toBe('Error interno del servidor.');
  });
});

describe('buildLoginRateLimiter', () => {
  test('expone el middleware de express-rate-limit', () => {
    expect(typeof buildLoginRateLimiter({ max: 2, windowMs: 60000 })).toBe('function');
  });
});
