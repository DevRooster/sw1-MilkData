const CircuitBreaker = require('opossum');

function createCircuitBreaker(action, options = {}) {
  return new CircuitBreaker(action, {
    errorThresholdPercentage: Number(options.errorThresholdPercentage ?? 50),
    volumeThreshold: Number(options.volumeThreshold ?? 2),
    resetTimeout: Number(options.resetTimeout ?? 10000),
    rollingCountTimeout: Number(options.rollingCountTimeout ?? 10000),
  });
}

module.exports = {
  createCircuitBreaker,
};