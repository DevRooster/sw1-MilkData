function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    proveedorId: entidad.proveedorId,
    zonaId: entidad.zonaId,
    unidadId: entidad.unidadId,
    usuarioId: entidad.usuarioId,
    cantidad: entidad.cantidad,
    fecha: entidad.fecha,
    hora: entidad.hora,
    temperatura: entidad.temperatura,
    // Faltaba en el DTO, igual que le faltaba `direccion` al de proveedor.
    // `recorridoParadaId` es lo único que dice de qué parada de qué recorrido
    // salió esta recogida, y sin él una recoleccion hecha en el campo llegaba a
    // la app sin ningun vinculo con el recorrido que la origino.
    recorridoParadaId: entidad.recorridoParadaId ?? null,
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
