const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { jwtConfig } = require('../config/auth.config');

class SecurityAuthService {
  async verifyToken(token) {
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

  async hashPassword(password) {
    return bcrypt.hash(password, 10);
  }

  async comparePassword(password, hash) {
    return bcrypt.compare(password, hash);
  }

  async signToken(payload) {
    return jwt.sign(payload, jwtConfig.secret, { expiresIn: jwtConfig.expiresIn });
  }
}

module.exports = new SecurityAuthService();
