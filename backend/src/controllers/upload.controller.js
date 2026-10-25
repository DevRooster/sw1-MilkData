const {
  TIPOS_PERMITIDOS,
  RECURSOS,
  LIMITE_BYTES,
  rutaRelativa,
  rutaEnDisco,
} = require('../config/upload.config');
const {
  persistir,
  eliminar,
  adjuntar,
  validarRecurso,
} = require('../services/upload.service');
const { successResponse } = require('../utils/response');
const { badRequest } = require('../utils/http-error');

/**
 * POST /uploads
 * multipart/form-data con:
 *   archivo  (binario, obligatorio)
 *   recurso  planta | usuario | proveedor | producto
 *   id       opcional: si viene, la imagen se adjunta al registro
 *
 * Con `id` la operación es atómica: guarda el archivo y actualiza la columna.
 * Sin `id` solo devuelve la ruta, para que el cliente la use después.
 */
async function subir(req, res, next) {
  try {
    if (!req.file) {
      throw badRequest('Falta el archivo en el campo "archivo".');
    }

    const recurso = validarRecurso(req.body && req.body.recurso);
    const plantaId = Number(req.contexto.plantaId);
    const id = req.body && req.body.id !== undefined && req.body.id !== ''
      ? Number(req.body.id)
      : null;

    const relativa = await persistir(req.file, plantaId, recurso);

    if (id === null) {
      return successResponse(
        res,
        { imagen: relativa, recurso, bytes: req.file.size },
        'Imagen almacenada',
        201
      );
    }

    try {
      const aplicada = await adjuntar(req.contexto, recurso, id, relativa);
      return successResponse(
        res,
        { imagen: aplicada, recurso, id, bytes: req.file.size },
        'Imagen actualizada',
        200
      );
    } catch (error) {
      // Si no se pudo adjuntar, el archivo huérfano no se queda en disco.
      await eliminar(relativa).catch(() => {});
      throw error;
    }
  } catch (error) {
    return next(error);
  }
}

/**
 * DELETE /uploads
 * body: { imagen: "/uploads/1/usuario/abc.png" }
 *
 * Desvincula la imagen del registro si apunta a uno, y borra el archivo si era
 * local. Las URLs externas no se tocan: la API no es dueña de esos archivos.
 */
async function borrar(req, res, next) {
  try {
    const imagen = req.body ? req.body.imagen : undefined;
    if (!imagen) {
      throw badRequest('Falta el campo "imagen".');
    }
    // La API solo borra archivos que ella misma almacenó. Una URL externa
    // puede apuntar a un recurso ajeno o inexistente en el futuro.
    if (rutaEnDisco(imagen) === null) {
      throw badRequest('La API solo borra imágenes que ella misma almacenó.');
    }

    const recurso = String(req.body.recurso || '').trim();
    const id = req.body.id !== undefined && req.body.id !== '' ? Number(req.body.id) : null;

    let desvinculado = false;
    if (recurso && id !== null) {
      validarRecurso(recurso);
      await adjuntar(req.contexto, recurso, id, null);
      desvinculado = true;
    }

    const eliminado = await eliminar(imagen);

    return successResponse(res, { imagen, eliminado, desvinculado }, 'Imagen eliminada');
  } catch (error) {
    return next(error);
  }
}

/** Metadatos de la configuración, útiles para que el cliente sepa los límites. */
function configuracion(_req, res) {
  return successResponse(res, {
    carpeta: 'uploads',
    urlBase: '/uploads',
    recursos: RECURSOS,
    limiteBytes: LIMITE_BYTES,
    tipos: Object.keys(TIPOS_PERMITIDOS),
    patron: rutaRelativa('<plantaId>', '<recurso>', '<uuid>.<ext>'),
  }, 'Configuración de imágenes');
}

module.exports = { subir, borrar, configuracion };
