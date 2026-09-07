function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    proveedorId: entidad.proveedorId,
    zonaId: entidad.zonaId,
    unidadId: entidad.unidadId,
    usuarioId: entidad.usuarioId,
    cantidad: entidad.cantidad,
    fecha: entidad.fecha,
    hora: entidad.hora,
    temperatura: entidad.temperatura,
    registradoEn: entidad.registradoEn,
    sincronizado: entidad.sincronizado,
    proveedor: entidad.proveedor ? {
      id: entidad.proveedor.id,
      nombre: entidad.proveedor.nombre,
      apellido: entidad.proveedor.apellido,
      dni: entidad.proveedor.dni,
      codigo: entidad.proveedor.codigo,
    } : null,
    zona: entidad.zona ? {
      id: entidad.zona.id,
      nombre: entidad.zona.nombre,
      ruta: entidad.zona.ruta,
    } : null,
    unidad: entidad.unidad ? {
      id: entidad.unidad.id,
      nombre: entidad.unidad.nombre,
      tipo: entidad.unidad.tipo,
      capacidad: entidad.unidad.capacidad,
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
