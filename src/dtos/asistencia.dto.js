function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    proveedorId: entidad.proveedorId,
    usuarioId: entidad.usuarioId,
    evento: entidad.evento,
    fecha: entidad.fecha,
    registradoPor: entidad.registradoPor,
    proveedor: entidad.proveedor ? {
      id: entidad.proveedor.id,
      nombre: entidad.proveedor.nombre,
      apellido: entidad.proveedor.apellido,
    } : null,
    usuario: entidad.usuario ? {
      id: entidad.usuario.id,
      nombre: entidad.usuario.nombre,
      apellido: entidad.usuario.apellido,
      email: entidad.usuario.email,
    } : null,
    createdAt: entidad.createdAt,
    updatedAt: entidad.updatedAt,
  };
}

module.exports = {
  toDTO,
};
