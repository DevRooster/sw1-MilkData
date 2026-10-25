const ROLES = {
  superadmin: 'superadmin',
  admin: 'admin',
  supervisor: 'supervisor',
  acopiador: 'acopiador',
  operador: 'operador',
  laboratorio: 'laboratorio',
  proveedor: 'proveedor',
};

const RECURSOS = [
  'plantas',
  'proveedores',
  'unidades',
  'zonas',
  'rutas',
  'recorridos',
  'recolecciones',
  'calidad',
  'notificaciones',
  'asistencias',
  'productos',
  'reportes',
  'usuarios',
];

const TODOS = '*';

/**
 * Matriz rol -> recurso -> operaciones permitidas ('read' y/o 'write').
 * `*` como recurso concede acceso a todos los recursos.
 *
 * La matriz es igual para todas las plantas: el aislamiento no depende del
 * rol sino de `plantaId`, que viaja en el token y se aplica en los servicios.
 *
 * El superadmin tiene la misma matriz que el admin. Lo que lo distingue no son
 * los permisos sino el alcance: puede pedir un token para cualquier planta con
 * `POST /auth/planta`, y entonces opera en esa como si fuera la suya.
 *
 * Crear plantas es privativo del superadmin. El admin de una planta administra
 * la suya, y por eso solo llega a consultarlas: la lista le sirve para
 * mostrarla en su perfil, no para abrir sedes nuevas.
 */
const PERMISOS = {
  [ROLES.superadmin]: { [TODOS]: ['read', 'write'] },
  [ROLES.admin]: { plantas: ['read'], [TODOS]: ['read', 'write'] },
  /**
   * `usuarios` no lo tienen supervisor ni los demás: dar de alta a alguien o
   * cambiarle el rol decide quién entra al sistema, así que es del admin de la
   * planta para arriba, no de quien supervisa el trabajo de campo.
   */
  [ROLES.supervisor]: {
    plantas: ['read'],
    proveedores: ['read', 'write'],
    unidades: ['read', 'write'],
    zonas: ['read', 'write'],
    rutas: ['read', 'write'],
    recorridos: ['read', 'write'],
    recolecciones: ['read', 'write'],
    calidad: ['read', 'write'],
    notificaciones: ['read', 'write'],
    asistencias: ['read', 'write'],
    productos: ['read', 'write'],
    reportes: ['read'],
  },
  /**
   * Acopiador: el chófer de la unidad. Lee proveedores, zonas, unidades y las
   * rutas para saber a dónde ir, y escribe en recorridos y recolecciones. No
   * toca catálogos: si cambia el orden de una ruta, lo decide la planta.
   */
  [ROLES.acopiador]: {
    proveedores: ['read'],
    unidades: ['read'],
    zonas: ['read'],
    rutas: ['read'],
    recorridos: ['read', 'write'],
    recolecciones: ['read', 'write'],
    asistencias: ['read', 'write'],
    reportes: ['read'],
  },
  [ROLES.operador]: {
    proveedores: ['read'],
    unidades: ['read'],
    zonas: ['read'],
    rutas: ['read'],
    recorridos: ['read'],
    recolecciones: ['read', 'write'],
    calidad: ['read', 'write'],
    notificaciones: ['read'],
    asistencias: ['read', 'write'],
    productos: ['read', 'write'],
    reportes: ['read'],
  },
  [ROLES.laboratorio]: {
    proveedores: ['read'],
    recolecciones: ['read'],
    calidad: ['read', 'write'],
    productos: ['read'],
    reportes: ['read'],
  },
  [ROLES.proveedor]: {
    proveedores: ['read'],
    recolecciones: ['read'],
    notificaciones: ['read'],
    productos: ['read'],
  },
};

module.exports = {
  ROLES,
  RECURSOS,
  PERMISOS,
  /** Roles con alcance sobre más de una planta. */
  MULTIPLANTA: [ROLES.superadmin],
};
