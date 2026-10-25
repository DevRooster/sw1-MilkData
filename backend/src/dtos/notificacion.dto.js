function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    proveedorId: entidad.proveedorId,
    usuarioId: entidad.usuarioId,
    tipo: entidad.tipo,
    titulo: entidad.titulo,
    mensaje: entidad.mensaje,
    leida: entidad.leida,
    enviada: entidad.enviada,
    fechaEnvio: entidad.fechaEnvio,
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
