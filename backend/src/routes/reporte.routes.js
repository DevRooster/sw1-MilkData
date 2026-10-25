const express = require('express');
const controller = require('../controllers/reporte.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { authorize } = require('../middlewares/authorize.middleware');
const layer = require('./route-layer');

const router = express.Router();

router.get('/contraste', authMiddleware, authorize('reportes', 'read'), layer, controller.reporteContraste);
router.get('/calidad', authMiddleware, authorize('reportes', 'read'), layer, controller.reporteCalidad);
router.get('/calidad-proveedor', authMiddleware, authorize('reportes', 'read'), layer, controller.reporteCalidadProveedor);
router.get('/calidad/proveedor/:proveedorId', authMiddleware, authorize('reportes', 'read'), layer, controller.reporteCalidadPorProveedor);

module.exports = router;
