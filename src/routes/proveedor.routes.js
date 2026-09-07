const express = require('express');
const proveedorController = require('../controllers/proveedor.controller');
const layer = require('./route-layer');

const router = express.Router();

router.post('/', layer, proveedorController.create);
router.put('/:id', layer, proveedorController.update);
router.delete('/:id', layer, proveedorController.remove);

module.exports = router;
