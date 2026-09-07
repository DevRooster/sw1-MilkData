const jwt = require('jsonwebtoken');
const { jwtConfig } = require('../config/auth.config');

function signToken(payload) {
  return jwt.sign(payload, jwtConfig.secret, { expiresIn: jwtConfig.expiresIn });
}

function verifyToken(token) {
  if (!token) {
    const error = new Error('Token requerido.');
    error.statusCode = 401;
    throw error;
  }

  try {
    return jwt.verify(token, jwtConfig.secret);
  } catch (error) {
    const err = new Error('Token inválido o expirado.');
    err.statusCode = 401;
    throw err;
  }
}

module.exports = {
  signToken,
  verifyToken,
};
