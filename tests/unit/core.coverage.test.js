const jwt = require('jsonwebtoken');
const { isValidDni, isValidEmail, isValidPhone } = require('../../src/utils/validators');
const { successResponse, errorResponse, paginatedResponse } = require('../../src/utils/response');
const permissions = require('../../src/security/permissions.service');
const jwtService = require('../../src/security/jwt.service');
const securityAuthService = require('../../src/security/auth.service');
const { withRetry } = require('../../src/resilience/retry');
const { createResilientNotificationSender } = require('../../src/resilience/notification.sender');
const { errorMiddleware } = require('../../src/middlewares/error.middleware');
const { authMiddleware } = require('../../src/middlewares/auth.middleware');

function responseMock() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

describe('Utilidades y seguridad', () => {
  test('validadores cubren entradas válidas e inválidas', () => {
    expect(isValidDni('12345678')).toBe(true);
    expect(isValidDni('123')).toBe(false);
    expect(isValidDni(null)).toBe(false);
    expect(isValidEmail('a@example.com')).toBe(true);
    expect(isValidEmail('invalid')).toBe(false);
    expect(isValidEmail(null)).toBe(false);
    expect(isValidPhone('+51999999999')).toBe(true);
    expect(isValidPhone('abc')).toBe(false);
    expect(isValidPhone(null)).toBe(false);
  });

  test('response helpers generan formato estándar', () => {
    const response = responseMock();
    successResponse(response, { id: 1 }, 'ok', 201);
    expect(response.status).toHaveBeenCalledWith(201);
    errorResponse(response, 'error', 400, 'bad');
    paginatedResponse(response, [], 0, 1, 10);
    expect(response.json).toHaveBeenCalledTimes(3);
  });

  test('permisos y JWT cubren éxito y errores', () => {
    expect(permissions.canAccess(null, 'admin')).toBe(false);
    expect(permissions.canAccess({ role: 'admin' }, 'admin')).toBe(true);
    expect(permissions.canAccess({ rolId: 2 }, [1, 2])).toBe(true);
    expect(permissions.canAccess({ rol: 'admin' })).toBe(true);
    const token = jwtService.signToken({ sub: 1 });
    expect(jwtService.verifyToken(token).sub).toBe(1);
    expect(() => jwtService.verifyToken()).toThrow('Token requerido.');
    expect(() => jwtService.verifyToken('bad-token')).toThrow('Token inválido o expirado.');
  });

  test('servicio de seguridad cifra, compara y firma', async () => {
    const hash = await securityAuthService.hashPassword('secret');
    expect(await securityAuthService.comparePassword('secret', hash)).toBe(true);
    expect(await securityAuthService.comparePassword('bad', hash)).toBe(false);
    const token = await securityAuthService.signToken({ sub: 3 });
    expect((await securityAuthService.verifyToken(token)).sub).toBe(3);
  });

  test('retry reintenta y también propaga agotamiento', async () => {
    let attempts = 0;
    const result = await withRetry(async () => {
      attempts += 1;
      if (attempts < 2) throw new Error('transitorio');
      return 'ok';
    }, { retries: 2 });
    expect(result).toBe('ok');
    expect(attempts).toBe(2);
    await expect(withRetry(async () => { throw new Error('definitivo'); }, { retries: 1 })).rejects.toThrow('definitivo');
  });

  test('sender resiliente permite éxito y circuito abierto', async () => {
    const successSender = createResilientNotificationSender({ externalSender: async () => ({ accepted: true }) });
    await expect(successSender.send({ id: 1 })).resolves.toEqual({ accepted: true });
    const failingSender = createResilientNotificationSender({ externalSender: async () => { throw new Error('caído'); }, retries: 0, volumeThreshold: 1 });
    await expect(failingSender.send({ id: 2 })).rejects.toThrow('caído');
    expect(failingSender.breaker.opened).toBe(true);
  });

  test('middlewares manejan autorización y errores', async () => {
    const missingResponse = responseMock();
    await authMiddleware({ headers: {} }, missingResponse, jest.fn());
    expect(missingResponse.status).toHaveBeenCalledWith(401);
    const errorResponseMock = responseMock();
    errorMiddleware({ statusCode: 422, message: 'fallo', errors: ['x'] }, {}, errorResponseMock, jest.fn());
    expect(errorResponseMock.status).toHaveBeenCalledWith(422);
    const next = jest.fn();
    const token = jwt.sign({ sub: 4 }, require('../../src/config/auth.config').jwtConfig.secret);
    await authMiddleware({ headers: { authorization: `Bearer ${token}` } }, responseMock(), next);
    expect(next).toHaveBeenCalled();
  });
});
