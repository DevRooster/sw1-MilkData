const dotenv = require('dotenv');

dotenv.config();

const jwtConfig = {
  secret: process.env.JWT_SECRET || 'mi-secreto-super-seguro-para-milkdata-2026',
  expiresIn: process.env.JWT_EXPIRES_IN || '7d',
};

module.exports = {
  jwtConfig,
};
