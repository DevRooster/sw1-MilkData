const express = require('express');
const controller = require('../controllers/unidad.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('unidades', 'read'), layer, controller.list);
router.get('/tipo/:value', authMiddleware, authorize('unidades', 'read'), layer, controller.filterByTipo);
router.get('/nombre/:value', authMiddleware, authorize('unidades', 'read'), layer, controller.filterByNombre);
router.get('/:id', authMiddleware, authorize('unidades', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('unidades', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('unidades', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('unidades', 'write'), layer, controller.delete);

module.exports = router;
