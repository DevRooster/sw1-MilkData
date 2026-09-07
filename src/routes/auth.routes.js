const express = require('express');
const authController = require('../controllers/auth.controller');
const { loginRateLimiter } = require('../middlewares/rateLimit.middleware');
const layer = require('./route-layer');

const router = express.Router();
router.post('/register', layer, authController.register);
router.post('/login', loginRateLimiter, layer, authController.login);
router.post('/verify', layer, authController.verify);

module.exports = router;
