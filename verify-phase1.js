const db = require('./src/config/database.config');
const auth = require('./src/config/auth.config');
const rate = require('./src/config/rateLimit.config');
const swagger = require('./src/config/swagger.config');
const response = require('./src/utils/response');
const validators = require('./src/utils/validators');
const helpers = require('./src/utils/helpers');
const logger = require('./src/utils/logger');

console.log('DB_OK', !!db.sequelize);
console.log('AUTH_OK', !!auth.jwtConfig && !!auth.jwtConfig.secret);
console.log('RATE_OK', !!rate.defaultRateLimiter);
console.log('SWAGGER_OK', !!swagger.swaggerSpec && !!swagger.swaggerSpec.openapi);
console.log('RESPONSE_OK', typeof response.successResponse === 'function');
console.log('VALIDATORS_OK', typeof validators.isValidDni === 'function');
console.log('HELPERS_OK', typeof helpers.isEmpty === 'function');
console.log('LOGGER_OK', !!logger);
