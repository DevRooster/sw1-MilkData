/**
 * Proyección de la planta.
 *
 * No se filtran campos: una planta es la raíz del aislamiento y sus datos son
 * públicos dentro del sistema (nombre, código, dirección y si está activa).
 * El DTO existe para que el superadmin y `PlantaService` devuelvan siempre la
 * misma forma, en vez de depender de la que traiga la consulta.
 */
function toDTO(planta) {
  if (!planta) {
    return null;
  }
  const datos = typeof planta.toJSON === 'function' ? planta.toJSON() : planta;

  return {
    id: datos.id,
    nombre: datos.nombre,
    codigo: datos.codigo,
    direccion: datos.direccion ?? null,
    imagen: datos.imagen ?? null,
    activo: datos.activo,
  };
}

module.exports = { toDTO };
