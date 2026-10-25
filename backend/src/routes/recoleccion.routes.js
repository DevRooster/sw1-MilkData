const express = require('express');
const controller = require('../controllers/recoleccion.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('recolecciones', 'read'), layer, controller.list);
router.get('/proveedor/:value', authMiddleware, authorize('recolecciones', 'read'), layer, controller.filterByProveedor);
router.get('/zona/:value', authMiddleware, authorize('recolecciones', 'read'), layer, controller.filterByZona);
router.get('/fecha/:value', authMiddleware, authorize('recolecciones', 'read'), layer, controller.filterByFecha);
router.get('/:id', authMiddleware, authorize('recolecciones', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('recolecciones', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('recolecciones', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('recolecciones', 'write'), layer, controller.delete);

module.exports = router;
