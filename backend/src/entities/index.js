const Rol = require('./rol.entity');
const Planta = require('./planta.entity');
const Unidad = require('./unidad.entity');
const Zona = require('./zona.entity');
const Usuario = require('./usuario.entity');
const Proveedor = require('./proveedor.entity');
const Ruta = require('./ruta.entity');
const RutaParada = require('./rutaParada.entity');
const Recorrido = require('./recorrido.entity');
const RecorridoParada = require('./recorridoParada.entity');
const Recoleccion = require('./recoleccion.entity');
const ControlCalidad = require('./controlCalidad.entity');
const Notificacion = require('./notificacion.entity');
const Asistencia = require('./asistencia.entity');
const Evento = require('./evento.entity');
const Producto = require('./producto.entity');
const Imagen = require('./imagen.entity');

/**
 * Aislamiento por planta. `Rol` queda fuera: los niveles de permiso tienen el
 * mismo significado en todas las plantas. `Planta` es la raíz del aislamiento.
 */
const PLANTA = 'plantaId';

const AISLADAS = [
  Usuario, Proveedor, Ruta, RutaParada, Recorrido, RecorridoParada,
  Unidad, Zona, Recoleccion, ControlCalidad, Notificacion, Asistencia, Producto,
  Imagen, Evento,
];

for (const modelo of AISLADAS) {
  Planta.hasMany(modelo, { foreignKey: PLANTA, as: `${modelo.name.toLowerCase()}s` });
  modelo.belongsTo(Planta, { foreignKey: PLANTA, as: 'planta' });
}

// Usuario ↔ Rol
Rol.hasMany(Usuario, { foreignKey: 'rolId', as: 'usuarios' });
Usuario.belongsTo(Rol, { foreignKey: 'rolId', as: 'rol' });

// Usuario ↔ Proveedor (1:1)
Usuario.hasOne(Proveedor, { foreignKey: 'usuarioId', as: 'proveedor' });
Proveedor.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Unidad ↔ Acopiador (el chófer responsable de la unidad)
Unidad.belongsTo(Usuario, { foreignKey: 'acopiadorId', as: 'acopiador' });
Usuario.hasMany(Unidad, { foreignKey: 'acopiadorId', as: 'unidades' });

// `Imagen` NO declara `belongsTo` hacia usuario, producto, proveedor o planta.
//
// La relación es polimórfica: `recurso` dice de qué tabla es el registro y
// `recurso_id` cuál. No hay clave foránea real, y declararla como asociación
// habría que añadirla al mapa de referencias por planta —que valida que un
// registro no apunte a otro de otra planta— sin que exista columna que validar.
// El aislamiento se aplica en `imagen.service`, que busca siempre dentro de la
// planta de la sesión.

// Ruta ↔ Paradas ordenadas
Ruta.hasMany(RutaParada, { foreignKey: 'rutaId', as: 'paradas' });
RutaParada.belongsTo(Ruta, { foreignKey: 'rutaId', as: 'ruta' });

RutaParada.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });
Proveedor.hasMany(RutaParada, { foreignKey: 'proveedorId', as: 'paradasDeRuta' });

// Un proveedor pertenece a una sola ruta activa (RN37 del documento v7).
Proveedor.belongsTo(Ruta, { foreignKey: 'rutaId', as: 'ruta' });
Ruta.hasMany(Proveedor, { foreignKey: 'rutaId', as: 'proveedores' });

// Zona ↔ Ruta (una zona pertenece a una ruta; la ruta agrupa zonas)
Zona.belongsTo(Ruta, { foreignKey: 'rutaId', as: 'ruta' });
Ruta.hasMany(Zona, { foreignKey: 'rutaId', as: 'zonas' });

// Zona ↔ Unidad
Unidad.hasMany(Zona, { foreignKey: 'unidadId', as: 'zonas' });
Zona.belongsTo(Unidad, { foreignKey: 'unidadId', as: 'unidad' });

// Recoleccion ↔ Proveedor / Zona / Unidad / Usuario
Proveedor.hasMany(Recoleccion, { foreignKey: 'proveedorId', as: 'recolecciones' });
Recoleccion.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Zona.hasMany(Recoleccion, { foreignKey: 'zonaId', as: 'recolecciones' });
Recoleccion.belongsTo(Zona, { foreignKey: 'zonaId', as: 'zona' });

Unidad.hasMany(Recoleccion, { foreignKey: 'unidadId', as: 'recolecciones' });
Recoleccion.belongsTo(Unidad, { foreignKey: 'unidadId', as: 'unidad' });

Usuario.hasMany(Recoleccion, { foreignKey: 'usuarioId', as: 'recolecciones' });
Recoleccion.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Recorrido: la ejecución de una ruta por una unidad y un acopiador
Recorrido.belongsTo(Ruta, { foreignKey: 'rutaId', as: 'ruta' });
Ruta.hasMany(Recorrido, { foreignKey: 'rutaId', as: 'recorridos' });

Recorrido.belongsTo(Unidad, { foreignKey: 'unidadId', as: 'unidad' });
Unidad.hasMany(Recorrido, { foreignKey: 'unidadId', as: 'recorridos' });

Recorrido.belongsTo(Usuario, { foreignKey: 'acopiadorId', as: 'acopiador' });
Usuario.hasMany(Recorrido, { foreignKey: 'acopiadorId', as: 'recorridos' });

// Ayudante: interno (usuario de la planta) o externo (datos sueltos).
Recorrido.belongsTo(Usuario, { foreignKey: 'ayudanteUsuarioId', as: 'ayudanteUsuario' });

// Recorrido ↔ Paradas ejecutadas
Recorrido.hasMany(RecorridoParada, { foreignKey: 'recorridoId', as: 'paradas' });
RecorridoParada.belongsTo(Recorrido, { foreignKey: 'recorridoId', as: 'recorrido' });

RecorridoParada.belongsTo(RutaParada, { foreignKey: 'rutaParadaId', as: 'rutaParada' });
RecorridoParada.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });
Proveedor.hasMany(RecorridoParada, { foreignKey: 'proveedorId', as: 'paradasDeRecorrido' });

// Una recolección puede originatesen una parada de recorrido.
Recoleccion.hasOne(RecorridoParada, { foreignKey: 'recoleccionId', as: 'paradaDeRecorrido' });

// ControlCalidad ↔ Recoleccion / Usuario (un control por recolección)
Recoleccion.hasOne(ControlCalidad, { foreignKey: 'recoleccionId', as: 'controlCalidad' });
ControlCalidad.belongsTo(Recoleccion, { foreignKey: 'recoleccionId', as: 'recoleccion' });

Usuario.hasMany(ControlCalidad, { foreignKey: 'usuarioId', as: 'controlesCalidad' });
ControlCalidad.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Notificacion ↔ Proveedor / Usuario
Proveedor.hasMany(Notificacion, { foreignKey: 'proveedorId', as: 'notificaciones' });
Notificacion.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Usuario.hasMany(Notificacion, { foreignKey: 'usuarioId', as: 'notificaciones' });
Notificacion.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

// Asistencia ↔ Evento (opcional, por lo de `eventoId` que se explica abajo)
Asistencia.belongsTo(Evento, { foreignKey: 'eventoId', as: 'eventoRelacion' });
Evento.hasMany(Asistencia, { foreignKey: 'eventoId', as: 'asistencias' });

// Asistencia ↔ Proveedor / Usuario
Proveedor.hasMany(Asistencia, { foreignKey: 'proveedorId', as: 'asistencias' });
Asistencia.belongsTo(Proveedor, { foreignKey: 'proveedorId', as: 'proveedor' });

Usuario.hasMany(Asistencia, { foreignKey: 'usuarioId', as: 'asistencias' });
Asistencia.belongsTo(Usuario, { foreignKey: 'usuarioId', as: 'usuario' });

module.exports = {
  Rol,
  Planta,
  Unidad,
  Zona,
  Usuario,
  Proveedor,
  Ruta,
  RutaParada,
  Recorrido,
  RecorridoParada,
  Recoleccion,
  ControlCalidad,
  Notificacion,
  Asistencia,
  Producto,
  Imagen,
  Evento,
};
