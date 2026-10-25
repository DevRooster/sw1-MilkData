process.env.NODE_ENV = 'production';
const { sequelize } = require('../src/config/database.config');
const {
  Rol, Planta, Unidad, Zona, Usuario, Proveedor, Ruta, RutaParada, Recorrido, RecorridoParada, Recoleccion,
} = require('../src/entities');

(async () => {
  const filas = [];
  for (const [nombre, modelo] of [
    ['planta', Planta], ['rol', Rol], ['usuario', Usuario], ['unidad', Unidad], ['zona', Zona],
    ['proveedor', Proveedor], ['ruta', Ruta], ['ruta_parada', RutaParada],
    ['recorrido', Recorrido], ['recorrido_parada', RecorridoParada], ['recoleccion', Recoleccion],
  ]) {
    filas.push(`${nombre}=${await modelo.count()}`);
  }
  console.log('CUENTAS ' + filas.join(' '));
  console.log('USUARIOS ' + (await Usuario.findAll({ attributes: ['email'] })).map((u) => u.email).join(', '));
  for (const r of await Ruta.findAll()) {
    console.log(`RUTA ${r.id} ${r.nombre} codigo=${r.codigo} paradas=${await RutaParada.count({ where: { rutaId: r.id } })}`);
  }
  await sequelize.close();
})().catch((e) => { console.log('ERR ' + e.message); process.exit(1); });

