const express = require('express');
const controller = require('../controllers/usuario.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

/**
 * Usuarios de la planta.
 *
 * El alta no está aquí: pasa por `POST /auth/register`, que tiene reglas propias
 * —bootstrap de la primera planta y la prohibición de que un admin de planta
 * cree a un superadmin—. Un `POST /usuarios` normal se saltaría esas reglas.
 */
router.get('/', authMiddleware, authorize('usuarios', 'read'), layer, controller.list);
router.get('/:id', authMiddleware, authorize('usuarios', 'read'), layer, controller.findById);
router.put('/:id', authMiddleware, authorize('usuarios', 'write'), layer, controller.update);

// Estas van antes de `/:id` porque si no, un `PUT /usuarios/5/rol` se leería
// como un id de "5/rol".
router.put('/:id/rol', authMiddleware, authorize('usuarios', 'write'), layer, controller.cambiarRol);
router.put('/:id/activo', authMiddleware, authorize('usuarios', 'write'), layer, controller.cambiarActivo);
router.put(
  '/:id/password',
  authMiddleware,
  authorize('usuarios', 'write'),
  layer,
  controller.cambiarPassword
);

router.delete('/:id', authMiddleware, authorize('usuarios', 'write'), layer, controller.delete);

module.exports = router;