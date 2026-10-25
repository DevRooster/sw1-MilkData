const express = require('express');
const controller = require('../controllers/evento.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

/**
 * Eventos a los que se puede asistir.
 *
 * Comparte el permiso `asistencias` y no tiene uno propio: **un evento sin
 * asistencias no sirve para nada**. Quien puede apuntar una asistencia puede crear
 * el evento al que asistirá, y quien no puede apuntar tampoco necesita crear
 * eventos. Abrir un permiso aparte serían dos puertas a lo mismo, y algún día
 * alguien cerraría una y no la otra.
 */
router.get('/', authMiddleware, authorize('asistencias', 'read'), layer, controller.list);
router.get('/nombre/:value', authMiddleware, authorize('asistencias', 'read'), layer, controller.filterByNombre);
router.get('/:id', authMiddleware, authorize('asistencias', 'read'), layer, controller.findById);
router.post('/', authMiddleware, authorize('asistencias', 'write'), layer, controller.create);
router.put('/:id', authMiddleware, authorize('asistencias', 'write'), layer, controller.update);
router.delete('/:id', authMiddleware, authorize('asistencias', 'write'), layer, controller.delete);

module.exports = router;