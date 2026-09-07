class PermissionsService {
  canAccess(user, requiredRole) {
    if (!user) {
      return false;
    }

    if (!requiredRole) {
      return true;
    }

    const roles = Array.isArray(requiredRole) ? requiredRole : [requiredRole];
    return roles.includes(user.rol) || roles.includes(user.role) || roles.includes(user.rolId);
  }
}

module.exports = new PermissionsService();
