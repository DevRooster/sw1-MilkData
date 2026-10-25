const express = require('express');
const controller = require('../controllers/upload.controller');
const imagenController = require('../controllers/imagen.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const { subirArchivo } = require('../middlewares/upload.middleware');
const layer = require('./route-layer');

const router = express.Router();

/**
 * POST /uploads/api
 * multipart/form-data con:
 *   archivo  (binario, obligatorio)
 *   recurso  planta | usuario | proveedor | producto
 *   id       opcional: si viene, la imagen se adjunta al registro
 *
 * Con `id` la operación es atómica: guarda el archivo y actualiza la columna.
 * Sin `id` solo devuelve la ruta, para que el cliente la use después.
 */

// El endpoint de la API cuelga de /uploads/api para que el middleware estático
// de archivos no redirija `/uploads` hacia `/uploads/`.
router.get('/api', authMiddleware, layer, controller.configuracion);
router.post('/api', authMiddleware, layer, subirArchivo, controller.subir);
router.delete('/api', authMiddleware, authorize('productos', 'write'), layer, controller.borrar);

// --- Galería: varias imágenes por registro -------------------------------
//
// `/api/imagen/...` va antes que `/api/:recurso/...` a propósito. En Express el
// orden importa, y `imagen` es también un nombre de recurso válido: si el
// comodín|winara, `DELETE /api/imagen/5` intentaría borrar una imagen del
// recurso llamado "imagen".
router.delete(
  '/api/imagen/:id',
  authMiddleware,
  authorize('productos', 'write'),
  layer,
  imagenController.quitar
);
router.put(
  '/api/imagen/:id/principal',
  authMiddleware,
  authorize('productos', 'write'),
  layer,
  imagenController.marcarPrincipal
);

router.get('/api/:recurso/:id', authMiddleware, layer, imagenController.listar);
router.post(
  '/api/:recurso/:id',
  authMiddleware,
  layer,
  subirArchivo,
  imagenController.agregar
);

module.exports = router;
