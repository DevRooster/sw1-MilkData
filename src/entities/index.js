const Rol = require('./rol.entity');
const Unidad = require('./unidad.entity');
const Zona = require('./zona.entity');
const Usuario = require('./usuario.entity');
const Proveedor = require('./proveedor.entity');
const Entrega = require('./entrega.entity');
const ControlCalidad = require('./controlCalidad.entity');
const Notificacion = require('./notificacion.entity');
const Asistencia = require('./asistencia.entity');

// Relaciones: Usuario ↔ Rol
Rol.hasMany(Usuario, { foreignKey: 'rolId', as: 'usuarios' });
Usuario.belongsTo(Rol, { foreignKey: 'rolId', as: 'rol' });

// Usuario ↔ Proveedor (1:1)
Usuario.hasOne(Proveedor, { foreignKey: 'usuarioId', as: 'proveedor' });
Proveedor.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Proveedor ↔ Zona
Zona.hasMany(Proveedor, { foreignKey: 'zonaId', as: 'proveedores' });
Proveedor.belongsTo(Zona, { foreignKey: 'zonaId', as: 'zona' });

// Zona ↔ Unidad
Unidad.hasMany(Zona, { foreignKey: 'unidadId', as: 'zonas' });
Zona.belongsTo(Unidad, { foreignKey: 'unidadId', as: 'unidad' });

// Entrega ↔ Proveedor / Zona / Unidad / Usuario
Proveedor.hasMany(Entrega, { foreignKey: 'proveedorId', as: 'entregas' });
Entrega.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Zona.hasMany(Entrega, { foreignKey: 'zonaId', as: 'entregas' });
Entrega.belongsTo(Zona, { foreignKey: 'zonaId', as: 'zona' });

Unidad.hasMany(Entrega, { foreignKey: 'unidadId', as: 'entregas' });
Entrega.belongsTo(Unidad, { foreignKey: 'unidadId', as: 'unidad' });

Usuario.hasMany(Entrega, { foreignKey: 'usuarioId', as: 'entregas' });
Entrega.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// ControlCalidad ↔ Entrega / Usuario
Entrega.hasOne(ControlCalidad, { foreignKey: 'entregaId', as: 'controlCalidad' });
ControlCalidad.belongsTo(Entrega, { foreignKey: 'entregaId', as: 'entrega' });

Usuario.hasMany(ControlCalidad, { foreignKey: 'usuarioId', as: 'controlesCalidad' });
ControlCalidad.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Notificacion ↔ Proveedor / Usuario
Proveedor.hasMany(Notificacion, { foreignKey: 'proveedorId', as: 'notificaciones' });
Notificacion.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Usuario.hasMany(Notificacion, { foreignKey: 'usuarioId', as: 'notificaciones' });
Notificacion.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Asistencia ↔ Proveedor / Usuario
Proveedor.hasMany(Asistencia, { foreignKey: 'proveedorId', as: 'asistencias' });
Asistencia.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Usuario.hasMany(Asistencia, { foreignKey: 'usuarioId', as: 'asistencias' });
Asistencia.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

module.exports = {
  Rol,
  Unidad,
  Zona,
  Usuario,
  Proveedor,
  Entrega,
  ControlCalidad,
  Notificacion,
  Asistencia,
};
