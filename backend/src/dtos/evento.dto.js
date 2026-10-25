/**
 * Proyección de un evento.
 *
 * Mismo criterio que en los demás DTO: solo columnas que existen y, cuando la
 * relación viene cargada, lo justo para reconocerla en una lista sin pedir nada
 * más. Un evento son cuatro campos de texto y una fecha, así que no hay nada que
 * resumir.
 */
function toDTO(entidad) {
  if (!entidad) {
    return null;
  }

  return {
    id: entidad.id,
    plantaId: entidad.plantaId,
    nombre: entidad.nombre,
    fecha: entidad.fecha,
    lugar: entidad.lugar,
    descripcion: entidad.descripcion,
    createdAt: entidad.createdAt,
    updatedAt: entidad.updatedAt,
  };
}

module.exports = {
  toDTO,
};