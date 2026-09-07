const express = require('express');
const request = require('supertest');
const { signToken } = require('./src/security/jwt.service');
const { authMiddleware } = require('./src/middlewares/auth.middleware');

const app = express();
app.use(express.json());

app.get('/protected', authMiddleware, (req, res) => {
  res.status(200).json({
    success: true,
    data: { user: req.user },
    message: 'Acceso permitido',
    errors: [],
  });
});

async function main() {
  try {
    const noTokenResponse = await request(app).get('/protected');
    console.log('NO_TOKEN_STATUS:', noTokenResponse.statusCode);
    console.log('NO_TOKEN_BODY:', JSON.stringify(noTokenResponse.body));

    const token = signToken({ sub: 99, email: 'admin@milkdata.com', rol: 'admin' });
    const validResponse = await request(app).get('/protected').set('Authorization', `Bearer ${token}`);
    console.log('VALID_TOKEN_STATUS:', validResponse.statusCode);
    console.log('VALID_TOKEN_BODY:', JSON.stringify(validResponse.body));
  } catch (error) {
    console.error('PROTECTED_ROUTE_ERROR');
    console.error(error && error.message ? error.message : String(error));
    process.exit(1);
  }
}

main();
