const jwt = require('jsonwebtoken');
const authService = require('./src/services/impl/auth.service');
const { jwtConfig } = require('./src/config/auth.config');

async function main() {
  const expiredToken = jwt.sign({ sub: 1, email: 'expired@test.com' }, jwtConfig.secret, { expiresIn: -1 });
  const validToken = jwt.sign({ sub: 1, email: 'valid@test.com', rol: 1 }, jwtConfig.secret, { expiresIn: '1h' });
  const parts = validToken.split('.');
  const tamperedToken = `${parts[0]}.${parts[1]}.firma-manipulada`;

  for (const [label, token] of [['EXPIRED_TOKEN', expiredToken], ['TAMPERED_TOKEN', tamperedToken]]) {
    try {
      await authService.verifyToken(token);
      console.log(`${label}_UNEXPECTED_SUCCESS`);
      process.exitCode = 1;
    } catch (error) {
      console.log(`${label}_STATUS:`, error.statusCode);
      console.log(`${label}_MESSAGE:`, error.message);
      if (error.statusCode !== 401) process.exitCode = 1;
    }
  }

  const refreshed = await authService.refreshToken(validToken);
  const refreshedPayload = await authService.verifyToken(refreshed.token);
  console.log('REFRESH_TOKEN_PRESENT:', Boolean(refreshed.token));
  console.log('REFRESH_TOKEN_VALID_SUB:', refreshedPayload.sub);

  const logout = await authService.logout();
  console.log('LOGOUT_RESPONSE:', JSON.stringify(logout));
  console.log('LOGOUT_INVALIDATES_JWT:', false);
  console.log('LOGOUT_NOTE: logout() solo devuelve confirmación; JWT stateless no se invalida en servidor.');
}

main().catch((error) => {
  console.error('AUTH_TOKEN_LIFECYCLE_ERROR:', error.message);
  process.exitCode = 1;
});
