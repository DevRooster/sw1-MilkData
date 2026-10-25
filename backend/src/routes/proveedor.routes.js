const express = require('express');
const controller = require('../controllers/proveedor.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('proveedores', 'read'), layer, controller.list);
router.get('/dni/:value', authMiddleware, authorize('proveedores', 'read'), layer, controller.findByDni);
router.get('/codigo/:value', authMiddleware, authorize('proveedores', 'read'), layer, controller.findByCodigo);
router.get('/zona/:value', authMiddleware, authorize('proveedores', 'read'), layer, controller.filterByZona);
router.get('/:id', authMiddleware, authorize('proveedores', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('proveedores', 'write'), layer, controller.create);
router.put('/:id/imagen', authMiddleware, authorize('proveedores', 'write'), layer, controller.setImagen);
router.put('/:id', authMiddleware, authorize('proveedores', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('proveedores', 'write'), layer, controller.delete);

module.exports = router;
