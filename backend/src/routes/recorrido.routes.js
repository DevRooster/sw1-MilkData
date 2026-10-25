const express = require('express');
const controller = require('../controllers/recorrido.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

const leer = [authMiddleware, authorize('recorridos', 'read'), layer];
const escribir = [authMiddleware, authorize('recorridos', 'write'), layer];

// El recorrido en curso del acopiador. Va primero para que `/actual` no
// se confunda con un id.
router.get('/actual', ...leer, controller.actual);

router.get('/', ...leer, controller.list);
router.get('/:id', ...leer, controller.findById);
router.post('/', ...escribir, controller.create);
router.put('/:id', ...escribir, controller.update);
router.delete('/:id', ...escribir, controller.delete);

// Ciclo de vida. La ruta no empieza hasta EN RUTA.
router.post('/:id/iniciar', ...escribir, controller.iniciar);
router.post('/:id/finalizar', ...escribir, controller.finalizar);
router.post('/:id/cancelar', ...escribir, controller.cancelar);

// Paradas del recorrido.
router.post('/:id/paradas/:paradaId/atender', ...escribir, controller.atenderParada);
router.post('/:id/paradas/:paradaId/recolectar', ...escribir, controller.recolectarEnParada);

module.exports = router;
