const rateLimit = require('express-rate-limit');
const { rateLimitConfig } = require('../config/rateLimit.config');

function buildLoginRateLimiter(customConfig = {}) {
  const config = {
    ...rateLimitConfig,
    ...customConfig,
    windowMs: Number(customConfig.windowMs ?? process.env.RATE_LIMIT_WINDOW_MS ?? rateLimitConfig.windowMs ?? 900000),
    max: Number(customConfig.max ?? process.env.RATE_LIMIT_MAX ?? rateLimitConfig.max ?? 5),
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      data: null,
      message: 'Demasiadas peticiones. Inténtalo más tarde.',
      errors: ['Too many requests'],
    },
    skipSuccessfulRequests: false,
    handler: (req, res) => {
      res.status(429).json({
        success: false,
        data: null,
        message: 'Demasiadas peticiones. Inténtalo más tarde.',
        errors: ['Too many requests'],
      });
    },
  };

  return rateLimit(config);
}

const loginRateLimiter = buildLoginRateLimiter();

module.exports = {
  buildLoginRateLimiter,
  loginRateLimiter,
};
