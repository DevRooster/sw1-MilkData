const multer = require('multer');
const { SUBIDA, LIMITE_BYTES } = require('../config/upload.config');
const { badRequest } = require('../utils/http-error');

/**
 * Multer con destino en memoria. El nombre definitivo se decide después,
 * cuando ya se sabe la planta y el recurso, y así nunca se acepta un nombre
 * de archivo elegido por el cliente.
 */
const memoria = multer({ ...SUBIDA, storage: multer.memoryStorage() });

/** Middleware que toma un solo archivo del campo `archivo`. */
const subirArchivo = memoria.single('archivo');

/**
 * Envuelve a multer para que sus errores lleguen como 400 y no como 500, y
 * normaliza el mensaje de los límites.
 */
function conErrores(maneja) {
  return function manejarSubida(req, res, next) {
    return maneja(req, res, (error) => {
      if (!error) {
        return next();
      }
      if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
          const mb = (LIMITE_BYTES / (1024 * 1024)).toFixed(1);
          return next(badRequest(`La imagen supera el límite de ${mb} MB.`));
        }
        return next(badRequest(`No se pudo procesar el archivo: ${error.message}`));
      }
      return next(badRequest(error.message));
    });
  };
}

module.exports = {
  subirArchivo: conErrores(subirArchivo),
};
