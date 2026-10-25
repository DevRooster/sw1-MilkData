const express = require('express');
const controller = require('../controllers/notificacion.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('notificaciones', 'read'), layer, controller.list);
router.get('/proveedor/:value', authMiddleware, authorize('notificaciones', 'read'), layer, controller.filterByProveedor);
router.get('/tipo/:value', authMiddleware, authorize('notificaciones', 'read'), layer, controller.filterByTipo);
router.get('/:id', authMiddleware, authorize('notificaciones', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('notificaciones', 'write'), layer, controller.create);
router.post('/enviar', authMiddleware, authorize('notificaciones', 'write'), layer, controller.send);
router.put('/:id', authMiddleware, authorize('notificaciones', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('notificaciones', 'write'), layer, controller.delete);

module.exports = router;
