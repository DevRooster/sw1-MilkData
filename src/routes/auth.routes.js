const express = require('express');
const authController = require('../controllers/auth.controller');
const { loginRateLimiter } = require('../middlewares/rateLimit.middleware');
const { registerAccessMiddleware } = require('../middlewares/register.middleware');
const layer = require('./route-layer');

const router = express.Router();
router.post('/register', layer, registerAccessMiddleware, authController.register);
router.post('/login', loginRateLimiter, layer, authController.login);
router.post('/verify', layer, authController.verify);

module.exports = router;
