const express = require('express');
const controller = require('../controllers/producto.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('productos', 'read'), layer, controller.list);
router.get('/nombre/:value', authMiddleware, authorize('productos', 'read'), layer, controller.findByNombre);
router.get('/:id', authMiddleware, authorize('productos', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('productos', 'write'), layer, controller.create);
router.put('/:id/imagen', authMiddleware, authorize('productos', 'write'), layer, controller.setImagen);
router.put('/:id', authMiddleware, authorize('productos', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('productos', 'write'), layer, controller.delete);

module.exports = router;
