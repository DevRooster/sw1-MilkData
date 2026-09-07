function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    nombre: entidad.nombre,
    apellido: entidad.apellido,
    dni: entidad.dni,
    telefono: entidad.telefono,
    codigo: entidad.codigo,
    zonaId: entidad.zonaId,
    usuarioId: entidad.usuarioId,
    activo: entidad.activo,
    zona: entidad.zona ? {
      id: entidad.zona.id,
      nombre: entidad.zona.nombre,
      ruta: entidad.zona.ruta,
      horaInicio: entidad.zona.horaInicio,
      horaFin: entidad.zona.horaFin,
      unidadId: entidad.zona.unidadId,
      activo: entidad.zona.activo,
    } : null,
    usuario: entidad.usuario ? {
      id: entidad.usuario.id,
      nombre: entidad.usuario.nombre,
      apellido: entidad.usuario.apellido,
      email: entidad.usuario.email,
      rolId: entidad.usuario.rolId,
      proveedorId: entidad.usuario.proveedorId,
      activo: entidad.usuario.activo,
      ultimoAcceso: entidad.usuario.ultimoAcceso,
    } : null,
    createdAt: entidad.createdAt,
    updatedAt: entidad.updatedAt,
  };
}

module.exports = {
  toDTO,
};
