const express = require('express');
const controller = require('../controllers/unidad.controller');
const layer = require('./route-layer');

const router = express.Router();
router.get('/', layer, controller.list);
router.post('/', layer, controller.create);
router.put('/:id', layer, controller.update);
router.delete('/:id', layer, controller.delete);

module.exports = router;
