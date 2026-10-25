function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    proveedorId: entidad.proveedorId,
    usuarioId: entidad.usuarioId,
    evento: entidad.evento,
    eventoId: entidad.eventoId ?? null,
    /**
     * El evento del catálogo al que apunta esta asistencia, o `null`.
     *
     * El nombre sale en la clave `evento` de dentro, no aquí, para no pisar el
     * texto libre: quien tiene `eventoId` ve el texto que escribió y el evento que
     * eligió, y quien no lo tiene ve solo el texto. La lista decide cuál enseña.
     */
    eventoRelacion: entidad.eventoRelacion ? {
      id: entidad.eventoRelacion.id,
      nombre: entidad.eventoRelacion.nombre,
      fecha: entidad.eventoRelacion.fecha,
      lugar: entidad.eventoRelacion.lugar,
    } : null,
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
