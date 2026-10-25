/**
 * Configuración de la paginación de listados.
 *
 * El móvil trabaja con pantallas pequeñas, así que la página por defecto es
 * corta: 10 filas obligan a desplazarse poco y mantienen la respuesta ligera
 * en conexiones lentas.
 *
 * El cliente puede pedir más mandando `limite`, hasta `LIMITE_MAXIMO`. El tope
 * existe para que nadie pida la tabla entera de un solo golpe.
 */
const POR_PAGINA = Number(process.env.PAGINACION_POR_PAGINA || 10);
const LIMITE_MAXIMO = Number(process.env.PAGINACION_LIMITE_MAXIMO || 200);

/** Números que no tienen sentido en `pagina` o `limite`. */
function noEsEnteroPositivo(valor) {
  return !Number.isInteger(valor) || valor < 1;
}

module.exports = {
  POR_PAGINA,
  LIMITE_MAXIMO,
  noEsEnteroPositivo,
};
