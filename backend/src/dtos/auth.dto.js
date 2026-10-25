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
    plantaId: entidad.plantaId,
    // `?? null` cubre los dos casos: columna NULL en base de datos y atributo
    // nunca asignado en la instancia.
    imagen: entidad.imagen ?? null,
    activo: entidad.activo,
    ultimoAcceso: entidad.ultimoAcceso,
  };

  if (entidad.rol) {
    dto.rol = entidad.rol;
  }

  if (entidad.planta) {
    dto.planta = {
      id: entidad.planta.id,
      nombre: entidad.planta.nombre,
      codigo: entidad.planta.codigo,
    };
  }

  if (entidad.proveedor) {
    dto.proveedor = entidad.proveedor;
  }

  return dto;
}

module.exports = {
  toDTO,
};
