const express = require('express');
const controller = require('../controllers/notificacion.controller');
const layer = require('./route-layer');

const router = express.Router();
router.post('/enviar', layer, controller.send);
router.get('/', layer, controller.list);
router.post('/', layer, controller.create);

module.exports = router;
