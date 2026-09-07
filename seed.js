const bcrypt = require('bcryptjs');
const { sequelize } = require('./src/config/database.config');
const { Rol, Unidad, Zona, Usuario, Proveedor } = require('./src/entities');

const roles = [
  { nombre: 'admin', descripcion: 'Administrador del sistema', nivel: 5 },
  { nombre: 'supervisor', descripcion: 'Supervisor de operaciones', nivel: 4 },
  { nombre: 'operador', descripcion: 'Operador de planta', nivel: 3 },
  { nombre: 'laboratorio', descripcion: 'Analista de control de calidad', nivel: 2 },
  { nombre: 'proveedor', descripcion: 'Proveedor de leche', nivel: 1 },
];

const unidades = [
  { nombre: 'Unidad Furgón 01', tipo: 'furgon', capacidad: 1500 },
  { nombre: 'Unidad Furgón 02', tipo: 'furgon', capacidad: 1200 },
  { nombre: 'Unidad Motocarga 01', tipo: 'motocarga', capacidad: 300 },
  { nombre: 'Unidad Motocarga 02', tipo: 'motocarga', capacidad: 300 },
];

const zonas = [
  { nombre: 'Zona Norte', ruta: 'Ruta Norte', horaInicio: '06:00:00', horaFin: '10:00:00' },
  { nombre: 'Zona Sur', ruta: 'Ruta Sur', horaInicio: '06:00:00', horaFin: '10:00:00' },
  { nombre: 'Zona Este', ruta: 'Ruta Este', horaInicio: '07:00:00', horaFin: '11:00:00' },
  { nombre: 'Zona Oeste', ruta: 'Ruta Oeste', horaInicio: '07:00:00', horaFin: '11:00:00' },
];

const proveedores = [
  { nombre: 'Juan', apellido: 'Pérez', dni: '70000001', codigo: 'PROV-001' },
  { nombre: 'María', apellido: 'Quispe', dni: '70000002', codigo: 'PROV-002' },
  { nombre: 'Carlos', apellido: 'Mamani', dni: '70000003', codigo: 'PROV-003' },
  { nombre: 'Rosa', apellido: 'Condori', dni: '70000004', codigo: 'PROV-004' },
  { nombre: 'Luis', apellido: 'Huanca', dni: '70000005', codigo: 'PROV-005' },
];

async function seed() {
  await sequelize.authenticate();

  const roleRecords = {};
  for (const role of roles) {
    const [record] = await Rol.findOrCreate({ where: { nombre: role.nombre }, defaults: { ...role, activo: true } });
    roleRecords[role.nombre] = record;
  }

  const unitRecords = [];
  for (const unit of unidades) {
    const [record] = await Unidad.findOrCreate({ where: { nombre: unit.nombre }, defaults: { ...unit, cerrado: false, activo: true } });
    unitRecords.push(record);
  }

  for (let index = 0; index < zonas.length; index += 1) {
    const zone = zonas[index];
    await Zona.findOrCreate({
      where: { nombre: zone.nombre },
      defaults: { ...zone, unidadId: unitRecords[index].id, activo: true },
    });
  }

  const password = await bcrypt.hash('Admin123!', 10);
  await Usuario.findOrCreate({
    where: { email: 'admin@milkdata.com' },
    defaults: {
      nombre: 'Administrador',
      apellido: 'MilkData',
      email: 'admin@milkdata.com',
      password,
      rolId: roleRecords.admin.id,
      activo: true,
    },
  });

  for (const provider of proveedores) {
    await Proveedor.findOrCreate({ where: { dni: provider.dni }, defaults: { ...provider, activo: true } });
  }

  const counts = {
    roles: await Rol.count(),
    unidades: await Unidad.count(),
    zonas: await Zona.count(),
    usuarios: await Usuario.count(),
    proveedores: await Proveedor.count(),
  };
  console.log('SEED_COUNTS:', JSON.stringify(counts));
  return counts;
}

if (require.main === module) {
  seed()
    .then(() => sequelize.close())
    .catch(async (error) => {
      console.error('SEED_ERROR:', error.message);
      await sequelize.close();
      process.exitCode = 1;
    });
}

module.exports = { seed };
