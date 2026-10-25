const express = require('express');
const controller = require('../controllers/ruta.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

// El acopiador necesita ver las rutas y el orden de paradas, noeditarlas.
const leer = [authMiddleware, authorize('rutas', 'read'), layer];
const escribir = [authMiddleware, authorize('rutas', 'write'), layer];

router.get('/', ...leer, controller.list);
router.get('/codigo/:codigo', ...leer, controller.findByCodigo);
router.get('/proveedores/:proveedorId/sugerencia', ...leer, controller.sugerencia);
router.get('/:id', ...leer, controller.findById);
router.get('/:id/recomendada', ...leer, controller.recomendada);
router.post('/', ...escribir, controller.create);
router.put('/:id', ...escribir, controller.update);
router.delete('/:id', ...escribir, controller.delete);

// Paradas de la ruta.
router.post('/:id/paradas', ...escribir, controller.agregarParada);
router.put('/:id/paradas/orden', ...escribir, controller.reordenarParadas);
router.delete('/:id/paradas/:paradaId', ...escribir, controller.quitarParada);

module.exports = router;
