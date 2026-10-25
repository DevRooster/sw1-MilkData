const express = require('express');
const controller = require('../controllers/zona.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('zonas', 'read'), layer, controller.list);
router.get('/nombre/:value', authMiddleware, authorize('zonas', 'read'), layer, controller.filterByNombre);
router.get('/unidad/:value', authMiddleware, authorize('zonas', 'read'), layer, controller.filterByUnidad);
router.get('/:id', authMiddleware, authorize('zonas', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('zonas', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('zonas', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('zonas', 'write'), layer, controller.delete);

module.exports = router;
