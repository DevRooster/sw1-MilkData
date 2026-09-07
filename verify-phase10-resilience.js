const { createResilientNotificationSender } = require('./src/resilience/notification.sender');
const { NotificacionService } = require('./src/services/impl/notificacion.service');

async function main() {
  let externalAttempts = 0;
  let retryAttempts = 0;
  let openedEvents = 0;
  const failingSender = createResilientNotificationSender({
    externalSender: async () => {
      externalAttempts += 1;
      throw new Error('Servicio externo de notificaciones caído');
    },
    retries: 2,
    volumeThreshold: 2,
    errorThresholdPercentage: 50,
    resetTimeout: 60000,
    onRetry: () => {
      retryAttempts += 1;
    },
  });
  failingSender.breaker.on('open', () => {
    openedEvents += 1;
  });

  const service = new NotificacionService(failingSender);
  const failures = [];
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      await service.send({ tipo: 'reunion', titulo: 'Prueba resiliencia', mensaje: 'Fallo forzado' });
    } catch (error) {
      failures.push({ attempt, name: error.name, code: error.code || null, message: error.message });
    }
  }

  console.log('SERVICE_FAILURES:', JSON.stringify(failures));
  console.log('EXTERNAL_ATTEMPTS:', externalAttempts);
  console.log('RETRY_ATTEMPTS:', retryAttempts);
  console.log('CIRCUIT_OPEN_EVENTS:', openedEvents);
  console.log('CIRCUIT_OPENED:', failingSender.breaker.opened);
  console.log('THIRD_CALL_BLOCKED_BY_OPEN_CIRCUIT:', failures[2] && failures[2].code === 'EOPENBREAKER');

  if (externalAttempts !== 6 || retryAttempts !== 4 || !failingSender.breaker.opened || openedEvents !== 1 || failures[2].code !== 'EOPENBREAKER') {
    throw new Error('La prueba no confirmó retry y apertura del circuit breaker');
  }
}

main().catch((error) => {
  console.error('PHASE10_RESILIENCE_ERROR:', error.message);
  process.exitCode = 1;
});
