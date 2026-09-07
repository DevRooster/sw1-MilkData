function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  const dto = {
    id: entidad.id,
    nombre: entidad.nombre,
    apellido: entidad.apellido,
    email: entidad.email,
    rolId: entidad.rolId,
    proveedorId: entidad.proveedorId,
    activo: entidad.activo,
    ultimoAcceso: entidad.ultimoAcceso,
  };

  if (entidad.rol) {
    dto.rol = entidad.rol;
  }

  if (entidad.proveedor) {
    dto.proveedor = entidad.proveedor;
  }

  return dto;
}

module.exports = {
  toDTO,
};
