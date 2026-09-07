const express = require('express');
const controller = require('../controllers/reporte.controller');
const layer = require('./route-layer');

const router = express.Router();
router.get('/contraste', layer, controller.reporteContraste);
router.get('/calidad', layer, controller.reporteCalidad);
router.get('/calidad-proveedor', layer, controller.reporteCalidadProveedor);
router.get('/calidad/proveedor/:proveedorId', layer, controller.reporteCalidadProveedor);

module.exports = router;
