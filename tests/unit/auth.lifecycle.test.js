const jwt = require('jsonwebtoken');
const authService = require('../../src/services/impl/auth.service');
const { jwtConfig } = require('../../src/config/auth.config');

describe('Ciclo de vida de tokens', () => {
  test('verifyToken rechaza token expirado con 401', async () => {
    const token = jwt.sign({ sub: 1 }, jwtConfig.secret, { expiresIn: -1 });

    await expect(authService.verifyToken(token)).rejects.toMatchObject({
      statusCode: 401,
      message: 'Token inválido o expirado.',
    });
  });

  test('verifyToken rechaza firma manipulada con 401', async () => {
    const token = jwt.sign({ sub: 1 }, jwtConfig.secret, { expiresIn: '1h' });
    const parts = token.split('.');
    const tamperedToken = `${parts[0]}.${parts[1]}.firma-manipulada`;

    await expect(authService.verifyToken(tamperedToken)).rejects.toMatchObject({
      statusCode: 401,
      message: 'Token inválido o expirado.',
    });
  });

  test('refreshToken emite un token nuevo verificable', async () => {
    const token = jwt.sign({ sub: 7, email: 'user@test.com', rol: 1 }, jwtConfig.secret, { expiresIn: '1h' });
    const refreshed = await authService.refreshToken(token);
    const payload = await authService.verifyToken(refreshed.token);

    expect(refreshed.token).toBeTruthy();
    expect(payload.sub).toBe(7);
    expect(payload.email).toBe('user@test.com');
  });

  test('logout devuelve confirmación sin invalidar JWT stateless', async () => {
    await expect(authService.logout()).resolves.toEqual({
      success: true,
      message: 'Sesión cerrada correctamente.',
    });
  });
});
