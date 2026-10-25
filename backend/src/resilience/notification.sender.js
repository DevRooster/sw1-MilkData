const { withRetry } = require('./retry');
const { createCircuitBreaker } = require('./circuitBreaker');

async function defaultExternalSender(payload) {
  return { accepted: true, payload };
}

function createResilientNotificationSender(options = {}) {
  const externalSender = options.externalSender || defaultExternalSender;
  const retryOptions = {
    retries: Number(options.retries ?? 2),
    onRetry: options.onRetry,
  };
  const breaker = createCircuitBreaker(
    (payload) => withRetry(() => externalSender(payload), retryOptions),
    options
  );

  return {
    breaker,
    send(payload) {
      return breaker.fire(payload);
    },
  };
}

module.exports = {
  createResilientNotificationSender,
};