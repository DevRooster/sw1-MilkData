const express = require('express');
const controller = require('../controllers/calidad.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/', authMiddleware, authorize('calidad', 'read'), layer, controller.list);
router.get('/recoleccion/:value', authMiddleware, authorize('calidad', 'read'), layer, controller.filterByRecoleccion);
router.get('/:id', authMiddleware, authorize('calidad', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('calidad', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('calidad', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('calidad', 'write'), layer, controller.delete);

module.exports = router;
