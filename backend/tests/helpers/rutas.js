const { sequelize } = require('../../src/config/database.config');
const {
  Planta, Unidad, Zona, Proveedor, Ruta, RutaParada, Recorrido, RecorridoParada, Recoleccion,
} = require('../../src/entities');

/**
 * Datos de prueba para rutas y recorridos.
 *
 * Todo lo que se crea lleva el sufijo en el nombre, así la limpieza puede
 * borrar por coincidencia sin tocar los registros del seed.
 */

let contadorProveedor = 0;

/** Proveedor de prueba. El dni y el código llevan el sufijo para no chocar. */
async function crearProveedor({ planta, zona = null, sufijo, orden = 1 }) {
  contadorProveedor += 1;
  const marca = `${sufijo}${contadorProveedor}`.toUpperCase().slice(0, 20);
  return Proveedor.create({
    nombre: `Nombre${orden}`,
    apellido: `Apellido${orden}`,
    dni: marca,
    codigo: `C${marca}`.slice(0, 50),
    telefono: '900000000',
    direccion: `Calle ${orden} 123`,
    plantaId: planta.id,
    zonaId: zona ? zona.id : null,
    activo: true,
  });
}

/**
 * Escenario completo: una zona, una ruta, sus paradas ordenadas y los
 * proveedores que las atienden.
 */
async function crearEscenario({ planta, sufijo, paradas = 3 }) {
  const zona = await Zona.create({
    nombre: `Zona ${sufijo}`,
    ruta: `Ruta texto ${sufijo}`,
    plantaId: planta.id,
    activo: true,
  });

  const ruta = await Ruta.create({
    plantaId: planta.id,
    nombre: `Ruta ${sufijo}`,
    codigo: `R${sufijo}`.toUpperCase().slice(0, 20),
    descripcion: `Ruta de prueba ${sufijo}`,
    horaInicio: '06:00:00',
    horaFin: '11:00:00',
    activa: true,
  });

  const proveedores = [];
  const paradasRuta = [];
  for (let i = 0; i < paradas; i += 1) {
    const proveedor = await crearProveedor({ planta, zona, sufijo, orden: i + 1 });
    proveedores.push(proveedor);
  }

  for (let i = 0; i < proveedores.length; i += 1) {
    paradasRuta.push(await RutaParada.create({
      plantaId: planta.id,
      rutaId: ruta.id,
      proveedorId: proveedores[i].id,
      orden: i + 1,
      horaEstimada: `0${6 + i}:00:00`,
      activa: true,
    }));
  }

  await zona.update({ rutaId: ruta.id });
  for (const proveedor of proveedores) {
    await proveedor.update({ rutaId: ruta.id });
  }

  return { zona, ruta, proveedores, paradas: paradasRuta };
}

/**
 * Unidad de prueba. El acopiador es opcional: `unidad.acopiador_id` admite
 * null, y hay escenarios donde lo que se prueba es justamente que una unidad
 * todavía no tiene chófer asignado.
 */
async function crearUnidad({ planta, acopiador, sufijo }) {
  return Unidad.create({
    plantaId: planta.id,
    acopiadorId: acopiador ? acopiador.id : null,
    nombre: `Unidad ${sufijo}`,
    tipo: 'furgon',
    capacidad: 1000,
    cerrado: false,
    activo: true,
  });
}

/**
 * Borra solo lo que la suite creó: filas con el sufijo **y** de esa planta.
 *
 * El filtro por planta no es opcional. Los tests corren contra la base del
 * seed, y varias suites crean plantas temporales para comprobar el
 * aislamiento; si el borrado fuera solo por sufijo, la limpieza de una planta
 * temporal se llevaría los proveedores de la planta principal.
 *
 * Se desactivan las claves foráneas porque las recolecciones apuntan a la
 * parada del recorrido que las originó, y el orden natural dependería de qué
 * paradas se llegaron a atender.
 *
 * @param {object} opciones
 * @param {number} opciones.plantaId
 * @param {string} opciones.sufijo  marca común de todo lo que creó la suite
 */
async function limpiar({ plantaId, sufijo }) {
  if (!sufijo) {
    throw new Error('limpiar() necesita el sufijo: sin él borraría la planta entera.');
  }
  if (!plantaId) {
    throw new Error('limpiar() necesita el plantaId: borraría datos de otras plantas.');
  }
  const marca = `%${sufijo}%`;
  const p = [plantaId, marca];

  await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');
  try {
    const [paradas] = await sequelize.query(
      `SELECT rp.id
         FROM recorrido_parada rp
         JOIN recorrido r ON r.id = rp.recorrido_id
        WHERE r.planta_id = ? AND (
          EXISTS (SELECT 1 FROM unidad u WHERE u.id = r.unidad_id AND u.nombre LIKE ?)
          OR EXISTS (SELECT 1 FROM ruta ru WHERE ru.id = r.ruta_id AND ru.codigo LIKE ?)
        )`,
      { replacements: [plantaId, marca, marca] }
    );
    const paradaIds = paradas.map((x) => x.id);

    if (paradaIds.length) {
      await sequelize.query(
        'UPDATE recoleccion SET recorrido_parada_id = NULL WHERE recorrido_parada_id IN (?)',
        { replacements: [paradaIds] }
      );
      await sequelize.query('DELETE FROM recorrido_parada WHERE id IN (?)', { replacements: [paradaIds] });
    }

    await sequelize.query(
      `DELETE FROM recorrido
        WHERE planta_id = ? AND id IN (
          SELECT id FROM (
            SELECT r.id FROM recorrido r
              JOIN unidad u ON u.id = r.unidad_id
             WHERE r.planta_id = ? AND u.nombre LIKE ?
          ) AS t
        )`,
      { replacements: [plantaId, plantaId, marca] }
    );

    await sequelize.query(
      `DELETE rp FROM ruta_parada rp
         JOIN ruta ru ON ru.id = rp.ruta_id
        WHERE rp.planta_id = ? AND ru.codigo LIKE ?`,
      { replacements: p }
    );
    await sequelize.query('DELETE FROM ruta WHERE planta_id = ? AND codigo LIKE ?', { replacements: p });
    await sequelize.query('DELETE FROM proveedor WHERE planta_id = ? AND dni LIKE ?', { replacements: p });
    await sequelize.query('DELETE FROM zona WHERE planta_id = ? AND nombre LIKE ?', { replacements: p });
    await sequelize.query('DELETE FROM unidad WHERE planta_id = ? AND nombre LIKE ?', { replacements: p });
    await sequelize.query('DELETE FROM usuario WHERE planta_id = ? AND email LIKE ?', { replacements: p });
  } finally {
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');
  }
}

module.exports = {
  crearEscenario,
  crearProveedor,
  crearUnidad,
  limpiar,
  Planta,
};
