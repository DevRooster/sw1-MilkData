const express = require('express');
const controller = require('../controllers/asistencia.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('asistencias', 'read'), layer, controller.list);
router.get('/proveedor/:value', authMiddleware, authorize('asistencias', 'read'), layer, controller.filterByProveedor);
router.get('/evento/:value', authMiddleware, authorize('asistencias', 'read'), layer, controller.filterByEvento);
router.get('/:id', authMiddleware, authorize('asistencias', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('asistencias', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('asistencias', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('asistencias', 'write'), layer, controller.delete);

module.exports = router;
