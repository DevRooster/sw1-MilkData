const { PERMISOS, RECURSOS, ROLES, MULTIPLANTA } = require('./role-permissions.config');

class PermissionsService {
  /**
   * @param {object} user  Payload del JWT, debe incluir `rol` (nombre del rol).
   * @param {string} rol   Rol requerido.
   */
  canAccess(user, rol) {
    if (!user) {
      return false;
    }
    if (!rol) {
      return true;
    }

    const roles = Array.isArray(rol) ? rol : [rol];
    return roles.some((candidate) => this._matches(user, candidate));
  }

  _matches(user, rol) {
    return user.rol === rol || user.role === rol || user.rolNombre === rol;
  }

  /** Concede acceso si el rol del usuario tiene `operacion` sobre `recurso`. */
  can(user, recurso, operacion) {
    if (!user || !user.rol) {
      return false;
    }

    const permisos = PERMISOS[user.rol];
    if (!permisos) {
      return false;
    }

    const concedidos = permisos[recurso] || permisos['*'];
    if (!concedidos) {
      return false;
    }

    return concedidos.includes(operacion) || (concedidos.includes('write') && operacion === 'read');
  }

  isAdmin(user) {
    return Boolean(user) && (user.rol === ROLES.admin || this.isSuperadmin(user));
  }

  /**
   * El superadmin administra todas las plantas: puede pedir un token para
   * cualquiera de ellas y operar ahí con los mismos permisos que su admin.
   */
  isSuperadmin(user) {
    return Boolean(user) && MULTIPLANTA.includes(user.rol);
  }

  /**
   * Recursos que este usuario puede usar, con las operaciones de cada uno.
   *
   * Existe para que el móvil no tenga que reescribir la matriz de permisos: si
   * la lista de módulos se decidiera en Dart habría dos copias que algún día
   * dejarían de coincidir, y el síntoma sería un módulo visible en el
   * lanzador que la API contesta con 403.
   *
   * Solo salen los recursos con algún permiso. Un rol sin acceso a algo no
   * recibe la entrada con una lista vacía: no la recibe, y así el lanzador no
   * tiene que decidir qué hacer con lo que no puede usarse.
   */
  recursosDe(user) {
    const porRecurso = {};
    if (!user || !user.rol) {
      return porRecurso;
    }

    for (const recurso of RECURSOS) {
      const operaciones = [];
      if (this.can(user, recurso, 'read')) {
        operaciones.push('read');
      }
      if (this.can(user, recurso, 'write')) {
        operaciones.push('write');
      }
      if (operaciones.length > 0) {
        porRecurso[recurso] = operaciones;
      }
    }

    return porRecurso;
  }
}

module.exports = new PermissionsService();
module.exports.PermissionsService = PermissionsService;
