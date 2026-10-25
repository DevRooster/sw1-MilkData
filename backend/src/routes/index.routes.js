const express = require('express');
const authRoutes = require('./auth.routes');
const uploadRoutes = require('./upload.routes');
const plantaRoutes = require('./planta.routes');
const proveedorRoutes = require('./proveedor.routes');
const unidadRoutes = require('./unidad.routes');
const zonaRoutes = require('./zona.routes');
const recoleccionRoutes = require('./recoleccion.routes');
const calidadRoutes = require('./calidad.routes');
const notificacionRoutes = require('./notificacion.routes');
const asistenciaRoutes = require('./asistencia.routes');
const eventoRoutes = require('./evento.routes');
const productoRoutes = require('./producto.routes');
const rutaRoutes = require('./ruta.routes');
const recorridoRoutes = require('./recorrido.routes');
const reporteRoutes = require('./reporte.routes');
const usuarioRoutes = require('./usuario.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/uploads', uploadRoutes);
router.use('/plantas', plantaRoutes);
router.use('/proveedores', proveedorRoutes);
router.use('/unidades', unidadRoutes);
router.use('/zonas', zonaRoutes);
router.use('/recolecciones', recoleccionRoutes);
router.use('/calidad', calidadRoutes);
router.use('/notificaciones', notificacionRoutes);
router.use('/asistencias', asistenciaRoutes);
router.use('/eventos', eventoRoutes);
router.use('/productos', productoRoutes);
router.use('/rutas', rutaRoutes);
router.use('/recorridos', recorridoRoutes);
router.use('/reportes', reporteRoutes);
router.use('/usuarios', usuarioRoutes);

module.exports = router;