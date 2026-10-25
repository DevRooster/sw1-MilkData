function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    nombre: entidad.nombre,
    apellido: entidad.apellido,
    dni: entidad.dni,
    telefono: entidad.telefono,
    // Se inclusionaba porque es de las columnas que se rellenan al dar de alta
    // un proveedor nuevo. Sin esto la columna era de solo escritura: se
    // guardaba bien, pero `GET /proveedores` no la devolvia y quien abriera a
    // editar un proveedor veria el campo vacio, aunque estuviera relleno. Y al
    // guardar de nuevo se habria Mandado vacio, con lo que el segundo guardado
    // borraba lo que el primero habia escrito.
    direccion: entidad.direccion ?? null,
    codigo: entidad.codigo,
    zonaId: entidad.zonaId,
    usuarioId: entidad.usuarioId,
    imagen: entidad.imagen ?? null,
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
      plantaId: entidad.usuario.plantaId,
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
