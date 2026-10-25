async function withRetry(operation, options = {}) {
  const retries = Number(options.retries || 0);
  const onRetry = options.onRetry || (() => {});
  let attempt = 0;

  while (true) {
    try {
      return await operation(attempt + 1);
    } catch (error) {
      if (attempt >= retries) {
        throw error;
      }
      attempt += 1;
      onRetry(attempt, error);
    }
  }
}

module.exports = {
  withRetry,
};