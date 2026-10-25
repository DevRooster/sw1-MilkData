function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    nombre: entidad.nombre,
    descripcion: entidad.descripcion,
    unidadMedida: entidad.unidadMedida,
    precioVenta: Number(entidad.precioVenta),
    imagen: entidad.imagen ?? null,
    estado: entidad.estado,
    createdAt: entidad.createdAt,
    updatedAt: entidad.updatedAt,
  };
}

module.exports = {
  toDTO,
};
