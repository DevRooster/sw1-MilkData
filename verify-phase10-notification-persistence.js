const { sequelize } = require('./src/config/database.config');
const { QueryTypes } = require('sequelize');
const { Notificacion } = require('./src/entities');
const { createResilientNotificationSender } = require('./src/resilience/notification.sender');
const { NotificacionService } = require('./src/services/impl/notificacion.service');

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function selectByMessage(message) {
  return sequelize.query(
    'SELECT * FROM notificacion WHERE mensaje = :mensaje',
    { replacements: { mensaje: message }, type: QueryTypes.SELECT }
  );
}

async function main() {
  const failedMessage = `FALLO_FASE10_${Date.now()}`;
  const recoveredMessage = `RECUPERADO_FASE10_${Date.now()}`;
  let healthy = false;
  let recoveredRecord;
  let sender;

  try {
    sender = createResilientNotificationSender({
      externalSender: async () => {
        if (!healthy) {
          throw new Error('Servicio externo caído');
        }
        return { accepted: true };
      },
      retries: 2,
      volumeThreshold: 2,
      errorThresholdPercentage: 50,
      resetTimeout: 5000,
    });
    const service = new NotificacionService(sender);

    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        await service.send({ tipo: 'reunion', titulo: 'Fallo controlado', mensaje: failedMessage });
      } catch (error) {
        console.log(`FAILED_SEND_${attempt}_ERROR:`, error.message);
      }
    }

    const breakerWasOpen = sender.breaker.opened;
    console.log('BREAKER_OPEN_IMMEDIATELY_AFTER_FAILED_SENDS:', breakerWasOpen);
    const failedRows = await selectByMessage(failedMessage);
    console.log('FAILED_SELECT_SQL: SELECT * FROM notificacion WHERE mensaje = :mensaje');
    console.log('FAILED_SELECT_ROWS:', JSON.stringify(failedRows));
    console.log('BREAKER_OPEN_AFTER_FAILED_SELECT:', sender.breaker.opened);

    healthy = true;
    await wait(5200);
    recoveredRecord = await service.send({ tipo: 'reunion', titulo: 'Recuperación', mensaje: recoveredMessage });
    const recoveredRows = await selectByMessage(recoveredMessage);
    console.log('RECOVERED_SEND_STATUS: persisted');
    console.log('RECOVERED_SEND_RESPONSE:', JSON.stringify(recoveredRecord));
    console.log('RECOVERED_SELECT_SQL: SELECT * FROM notificacion WHERE mensaje = :mensaje');
    console.log('RECOVERED_SELECT_ROWS:', JSON.stringify(recoveredRows));
    console.log('BREAKER_CLOSED_AFTER_RECOVERY:', sender.breaker.closed);

    if (failedRows.length !== 0 || recoveredRows.length !== 1 || !breakerWasOpen || !sender.breaker.closed) {
      throw new Error('La persistencia o recuperación del circuit breaker no coincide con lo esperado');
    }
  } finally {
    if (recoveredRecord) {
      await Notificacion.destroy({ where: { id: recoveredRecord.id } });
    }
    await sequelize.close();
  }
}

main().catch((error) => {
  console.error('PHASE10_PERSISTENCE_ERROR:', error.message);
  process.exitCode = 1;
});
