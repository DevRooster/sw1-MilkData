const rateLimit = require('express-rate-limit');

const rateLimitConfig = {
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 900000),
  max: Number(process.env.RATE_LIMIT_MAX || 100),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    message: 'Demasiadas peticiones. Inténtalo más tarde.',
    errors: ['Too many requests'],
  },
};

const defaultRateLimiter = rateLimit(rateLimitConfig);

module.exports = {
  rateLimitConfig,
  defaultRateLimiter,
};
