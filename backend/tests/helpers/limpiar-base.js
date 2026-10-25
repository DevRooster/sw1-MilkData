process.env.NODE_ENV = 'production';
const { sequelize } = require('../../src/config/database.config');
const datosSemilla = require('../../scripts/seed');

/** Nombres y códigos que introduce el seed; todo lo demás es de las pruebas. */
const NOMBRES_UNIDAD = datosSemilla.UNIDADES.map((u) => u.nombre);
const NOMBRES_ZONA = datosSemilla.ZONAS.map((z) => z.nombre);
const NOMBRES_ROL = datosSemilla.ROLES.map((r) => r.nombre);
const CODIGOS_RUTA = [...new Set(datosSemilla.ZONAS.map((z) => z.ruta))].map((nombre) => nombre
  .toUpperCase()
  .replace(/[^A-Z0-9]/g, '')
  .slice(0, 20));
const DNIS_PROVEEDOR = datosSemilla.PROVEEDORES.map((p) => p.dni);
const CODIGOS_PLANTA = datosSemilla.PLANTAS.map((p) => p.codigo);

/**
 * Deja la base como quedaría tras un seed limpio: borra todo lo que no venga
 * del seed para empezar cada corrida desde un estado conocido.
 *
 * Las listas se leen de `scripts/seed.js`, así que agregar una fila al seed
 * la incluye automáticamente sin tocar este archivo.
 */
async function limpiar() {
  await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');
  try {
    // Primero se sueltan las referencias entre tablas de rutas y recorridos.
    await sequelize.query('UPDATE recoleccion SET recorrido_parada_id = NULL WHERE recorrido_parada_id IS NOT NULL');
    await sequelize.query('DELETE FROM recorrido_parada');
    await sequelize.query('DELETE FROM recorrido');
    // Las paradas del seed son las de las rutas del seed.
    await sequelize.query(
      'DELETE FROM ruta_parada WHERE ruta_id NOT IN (SELECT id FROM ruta WHERE codigo IN (?))',
      { replacements: [CODIGOS_RUTA] }
    );
    await sequelize.query('DELETE FROM ruta WHERE codigo NOT IN (?)', { replacements: [CODIGOS_RUTA] });

    await sequelize.query('DELETE FROM control_calidad');
    await sequelize.query('DELETE FROM recoleccion');
    await sequelize.query('DELETE FROM producto');
    await sequelize.query('DELETE FROM asistencia');
    await sequelize.query('DELETE FROM notificacion');

    await sequelize.query('DELETE FROM proveedor WHERE dni NOT IN (?)', { replacements: [DNIS_PROVEEDOR] });
    await sequelize.query('DELETE FROM zona WHERE nombre NOT IN (?)', { replacements: [NOMBRES_ZONA] });
    await sequelize.query('DELETE FROM unidad WHERE nombre NOT IN (?)', { replacements: [NOMBRES_UNIDAD] });
    await sequelize.query('DELETE FROM usuario WHERE email NOT IN (?)', {
      replacements: [datosSemilla.EMAILS_DE_SEMILLA],
    });
    await sequelize.query('DELETE FROM rol WHERE nombre NOT IN (?)', { replacements: [NOMBRES_ROL] });
    await sequelize.query('DELETE FROM planta WHERE codigo NOT IN (?)', { replacements: [CODIGOS_PLANTA] });
  } finally {
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');
  }
}

const TABLAS = [
  'planta', 'rol', 'usuario', 'unidad', 'zona', 'proveedor', 'ruta', 'ruta_parada',
  'recorrido', 'recorrido_parada', 'recoleccion', 'control_calidad',
  'notificacion', 'asistencia', 'producto',
];

async function resumen() {
  const r = {};
  for (const t of TABLAS) {
    const [x] = await sequelize.query(`SELECT COUNT(*) AS n FROM \`${t}\``);
    r[t] = Number(x[0].n);
  }
  return r;
}

module.exports = { limpiar, resumen, sequelize, TABLAS };

if (require.main === module) {
  limpiar()
    .then(resumen)
    .then((r) => {
      console.log('BASE DE PRUEBAS LIMPIA');
      console.log('RESUMEN:', JSON.stringify(r));
      return sequelize.close();
    })
    .catch(async (e) => {
      console.log('ERR:', e.message);
      await sequelize.close();
      process.exit(1);
    });
}
