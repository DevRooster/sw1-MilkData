const express = require('express');
const request = require('supertest');

process.env.RATE_LIMIT_MAX = '2';
process.env.RATE_LIMIT_WINDOW_MS = '60000';

const securityAuthService = require('./src/security/auth.service');
const { buildLoginRateLimiter } = require('./src/middlewares/rateLimit.middleware');

if (!securityAuthService || typeof securityAuthService.verifyToken !== 'function') {
  throw new Error('Falta src/security/auth.service.js o no expone verifyToken');
}

const loginRateLimiter = buildLoginRateLimiter({ max: 2, windowMs: 60000 });

const app = express();
app.use(express.json());
app.post('/auth/login', loginRateLimiter, (req, res) => {
  res.status(200).json({
    success: true,
    data: { ok: true },
    message: 'login ok',
    errors: [],
  });
});

(async () => {
  const first = await request(app).post('/auth/login').send({ email: 'a@test.com', password: 'x' });
  const second = await request(app).post('/auth/login').send({ email: 'b@test.com', password: 'y' });
  const blocked = await request(app).post('/auth/login').send({ email: 'c@test.com', password: 'z' });

  console.log('FIRST_STATUS', first.statusCode);
  console.log('SECOND_STATUS', second.statusCode);
  console.log('BLOCKED_STATUS', blocked.statusCode);
  console.log('BLOCKED_BODY', JSON.stringify(blocked.body));

  if (blocked.statusCode !== 429) {
    throw new Error('La ruta de login no devolvió 429 tras superar el límite');
  }
})();
