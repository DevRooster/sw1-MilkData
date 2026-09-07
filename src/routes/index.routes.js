const express = require('express');
const authRoutes = require('./auth.routes');
const proveedorRoutes = require('./proveedor.routes');
const unidadRoutes = require('./unidad.routes');
const zonaRoutes = require('./zona.routes');
const entregaRoutes = require('./entrega.routes');
const calidadRoutes = require('./calidad.routes');
const notificacionRoutes = require('./notificacion.routes');
const asistenciaRoutes = require('./asistencia.routes');
const reporteRoutes = require('./reporte.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/proveedores', proveedorRoutes);
router.use('/unidades', unidadRoutes);
router.use('/zonas', zonaRoutes);
router.use('/entregas', entregaRoutes);
router.use('/calidad', calidadRoutes);
router.use('/notificaciones', notificacionRoutes);
router.use('/asistencias', asistenciaRoutes);
router.use('/reportes', reporteRoutes);

module.exports = router;
