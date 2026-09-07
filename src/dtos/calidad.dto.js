function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    entregaId: entidad.entregaId,
    usuarioId: entidad.usuarioId,
    grasa: entidad.grasa,
    proteina: entidad.proteina,
    lactosa: entidad.lactosa,
    densidad: entidad.densidad,
    temperatura: entidad.temperatura,
    aguaAnadida: entidad.aguaAnadida,
    ph: entidad.ph,
    resultado: entidad.resultado,
    entrega: entidad.entrega ? {
      id: entidad.entrega.id,
      proveedorId: entidad.entrega.proveedorId,
      fecha: entidad.entrega.fecha,
      cantidad: entidad.entrega.cantidad,
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
