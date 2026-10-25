const express = require('express');
const controller = require('../controllers/planta.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

/**
 * Plantas: exigen token pero no se aíslan, porque una planta es el límite y no
 * algo contenido dentro de él. Cualquier rol autenticado puede consultarlas
 * (para mostrar su propia planta en el perfil); solo el admin las modifica.
 */
router.get('/', authMiddleware, authorize('plantas', 'read'), layer, controller.list);
router.get('/codigo/:codigo', authMiddleware, authorize('plantas', 'read'), layer, controller.findByCodigo);
router.get('/:id', authMiddleware, authorize('plantas', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('plantas', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('plantas', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('plantas', 'write'), layer, controller.delete);

module.exports = router;
