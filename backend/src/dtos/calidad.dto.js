function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    recoleccionId: entidad.recoleccionId,
    usuarioId: entidad.usuarioId,
    grasa: entidad.grasa,
    proteina: entidad.proteina,
    lactosa: entidad.lactosa,
    densidad: entidad.densidad,
    temperatura: entidad.temperatura,
    aguaAnadida: entidad.aguaAnadida,
    ph: entidad.ph,
    resultado: entidad.resultado,
    recoleccion: entidad.recoleccion ? {
      id: entidad.recoleccion.id,
      proveedorId: entidad.recoleccion.proveedorId,
      fecha: entidad.recoleccion.fecha,
      cantidad: entidad.recoleccion.cantidad,
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
