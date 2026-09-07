const express = require('express');
const controller = require('../controllers/calidad.controller');
const layer = require('./route-layer');

const router = express.Router();
router.get('/', layer, controller.list);
router.post('/', layer, controller.create);

module.exports = router;
