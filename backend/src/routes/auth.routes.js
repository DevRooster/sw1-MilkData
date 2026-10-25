const express = require('express');
const authController = require('../controllers/auth.controller');
const { loginRateLimiter } = require('../middlewares/rateLimit.middleware');
const { registerAccessMiddleware } = require('../middlewares/register.middleware');
const { authMiddleware } = require('../middlewares/auth.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.post('/register', layer, registerAccessMiddleware, authController.register);
router.post('/login', loginRateLimiter, layer, authController.login);
router.post('/verify', authMiddleware, layer, authController.verify);
router.post('/refresh', authMiddleware, layer, authController.refresh);
router.post('/logout', authMiddleware, layer, authController.logout);
router.get('/perfil', authMiddleware, layer, authController.perfil);
router.put('/perfil', authMiddleware, layer, authController.actualizarPerfil);

// Alcance multi-planta del superadmin.
router.get('/plantas', authMiddleware, layer, authController.plantasDisponibles);
router.post('/planta', authMiddleware, layer, authController.cambiarPlanta);

// La matriz de permisos del token, para que el móvil dibuje su menú con lo que
// la API va a responderle en vez de con una copia de la matriz.
router.get('/permisos', authMiddleware, layer, authController.permisos);

module.exports = router;
