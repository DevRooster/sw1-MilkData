const bcrypt = require('bcryptjs');
const { sequelize, syncSchema } = require('../src/config/database.config');
const {
  Rol, Planta, Unidad, Zona, Usuario, Proveedor, Ruta, RutaParada,
} = require('../src/entities');

const ROLES = [
  { nombre: 'superadmin', descripcion: 'Supervisa todas las plantas: puede operar en cualquiera de ellas', nivel: 6 },
  { nombre: 'admin', descripcion: 'Administrador de una planta', nivel: 5 },
  { nombre: 'supervisor', descripcion: 'Supervisor de operaciones', nivel: 4 },
  { nombre: 'acopiador', descripcion: 'Acopiador: chófer responsable de la unidad y la ruta', nivel: 3 },
  { nombre: 'operador', descripcion: 'Operador de planta', nivel: 3 },
  { nombre: 'laboratorio', descripcion: 'Analista de control de calidad', nivel: 2 },
  { nombre: 'proveedor', descripcion: 'Proveedor de leche', nivel: 1 },
];

const PLANTAS = [
  { nombre: 'Planta Ecológica Huata', codigo: 'HUA', direccion: 'Distrito de Huata' },
];

const UNIDADES = [
  { nombre: 'Unidad Furgón 01', tipo: 'furgon', capacidad: 1500 },
  { nombre: 'Unidad Furgón 02', tipo: 'furgon', capacidad: 1200 },
  { nombre: 'Unidad Motocarga 01', tipo: 'motocarga', capacidad: 300 },
  { nombre: 'Unidad Motocarga 02', tipo: 'motocarga', capacidad: 300 },
];

// Cada zona pertenece a una ruta. El texto `ruta` de la zona era el nombre
// de la ruta; ahora la ruta es una entidad con paradas ordenadas.
const ZONAS = [
  { nombre: 'Zona Norte', ruta: 'Ruta Norte', horaInicio: '06:00:00', horaFin: '10:00:00' },
  { nombre: 'Zona Sur', ruta: 'Ruta Sur', horaInicio: '06:00:00', horaFin: '10:00:00' },
  { nombre: 'Zona Este', ruta: 'Ruta Este', horaInicio: '07:00:00', horaFin: '11:00:00' },
  { nombre: 'Zona Oeste', ruta: 'Ruta Oeste', horaInicio: '07:00:00', horaFin: '11:00:00' },
];

// Paradas en el orden que ya conoce el acopiador. El orden define la ruta
// recomendada que devuelve la API.
const PARADAS = {
  'Ruta Norte': [
    { dni: '70000001', orden: 1, horaEstimada: '06:30:00' },
    { dni: '70000002', orden: 2, horaEstimada: '07:30:00' },
  ],
  'Ruta Sur': [
    { dni: '70000003', orden: 1, horaEstimada: '06:30:00' },
    { dni: '70000004', orden: 2, horaEstimada: '07:30:00' },
  ],
  'Ruta Este': [{ dni: '70000005', orden: 1, horaEstimada: '07:30:00' }],
  'Ruta Oeste': [],
};

const PROVEEDORES = [
  { nombre: 'Juan', apellido: 'Pérez', dni: '70000001', codigo: 'PROV-001' },
  { nombre: 'María', apellido: 'Quispe', dni: '70000002', codigo: 'PROV-002' },
  { nombre: 'Carlos', apellido: 'Mamani', dni: '70000003', codigo: 'PROV-003' },
  { nombre: 'Rosa', apellido: 'Condori', dni: '70000004', codigo: 'PROV-004' },
  { nombre: 'Luis', apellido: 'Huanca', dni: '70000005', codigo: 'PROV-005' },
];

/**
 * Seed idempotente por planta. Todo lo que crea lleva `plantaId`, así que
 * varias plantas conviven sin mezclarse.
 */
async function seed({ log = console.log } = {}) {
  await syncSchema({ log: () => {} });

  const roleRecords = {};
  for (const rol of ROLES) {
    const [record] = await Rol.findOrCreate({
      where: { nombre: rol.nombre },
      defaults: { ...rol, activo: true },
    });
    roleRecords[rol.nombre] = record;
  }

  const resumen = {};

  for (const datosPlanta of PLANTAS) {
    const [planta] = await Planta.findOrCreate({
      where: { codigo: datosPlanta.codigo },
      defaults: { ...datosPlanta, activo: true },
    });

    // Rutas antes que zonas: las zonas apuntan a su ruta.
    const rutasPorNombre = {};
    for (const nombre of [...new Set(ZONAS.map((z) => z.ruta))]) {
      const codigo = nombre.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 20);
      const [ruta] = await Ruta.findOrCreate({
        where: { codigo, plantaId: planta.id },
        defaults: {
          plantaId: planta.id,
          nombre,
          codigo,
          descripcion: `Ruta de recolección ${nombre}`,
          horaInicio: '06:00:00',
          horaFin: '11:00:00',
          activa: true,
        },
      });
      rutasPorNombre[nombre] = ruta;
    }

    const unidades = [];
    for (const unidad of UNIDADES) {
      const [record] = await Unidad.findOrCreate({
        where: { nombre: unidad.nombre, plantaId: planta.id },
        defaults: { ...unidad, plantaId: planta.id, cerrado: false, activo: true },
      });
      unidades.push(record);
    }

    for (let i = 0; i < ZONAS.length; i += 1) {
      const zona = ZONAS[i];
      const { ruta, ...datosZona } = zona;
      await Zona.findOrCreate({
        where: { nombre: datosZona.nombre, plantaId: planta.id },
        defaults: {
          ...datosZona,
          plantaId: planta.id,
          rutaId: rutasPorNombre[ruta].id,
          unidadId: unidades[i].id,
          activo: true,
        },
      });
    }

    // La cuenta de arranque es el superadmin.
    //
    // Es la única que puede crear plantas (`POST /plantas` es privativo del
    // superadmin) y fundar el primer admin de cada una, así que quien la use
    // tiene que poder gobernar todas. Por eso `admin@milkdata.com` lleva el rol
    // superadmin y no el de admin de planta: es la cuenta con la que se arranca,
    // no una a la que haya que ascender despues.
    const [superadmin] = await Usuario.findOrCreate({
      where: { email: 'admin@milkdata.com', plantaId: planta.id },
      defaults: {
        nombre: 'Super',
        apellido: 'Administrador',
        email: 'admin@milkdata.com',
        password: await bcrypt.hash('Superadmin123!', 10),
        rolId: roleRecords.superadmin.id,
        plantaId: planta.id,
        activo: true,
      },
    });

    // Admin de la planta principal. La crea el superadmin una vez que este
    // existe, que es la única forma de llegar aquí.
    const [admin] = await Usuario.findOrCreate({
      where: { email: 'admin.huata@milkdata.com', plantaId: planta.id },
      defaults: {
        nombre: 'Administrador',
        apellido: 'MilkData',
        email: 'admin.huata@milkdata.com',
        password: await bcrypt.hash('Admin123!', 10),
        rolId: roleRecords.admin.id,
        plantaId: planta.id,
        activo: true,
      },
    });

    // Un acopiador de ejemplo, para que las rutas tengan un chófer asignado.
    const [acopiador] = await Usuario.findOrCreate({
      where: { email: 'acopiador@milkdata.com', plantaId: planta.id },
      defaults: {
        nombre: 'Acopiador',
        apellido: 'Demo',
        email: 'acopiador@milkdata.com',
        password: await bcrypt.hash('Acopiador123!', 10),
        rolId: roleRecords.acopiador.id,
        plantaId: planta.id,
        activo: true,
      },
    });

    // Cada proveedor va a la ruta que lo tiene en PARADAS, y a la zona de esa
    // ruta. Así la ruta recomendada y las zonas quedan coherentes.
    const rutaDeProveedor = new Map();
    for (const [nombreRuta, paradas] of Object.entries(PARADAS)) {
      for (const parada of paradas) {
        rutaDeProveedor.set(parada.dni, nombreRuta);
      }
    }

    const zonasPorRuta = new Map();
    for (let i = 0; i < ZONAS.length; i += 1) {
      const nombre = ZONAS[i].nombre;
      const zona = await Zona.findOne({ where: { nombre, plantaId: planta.id } });
      if (zona) {
        zonasPorRuta.set(ZONAS[i].ruta, zona);
      }
    }

    for (const proveedor of PROVEEDORES) {
      const nombreRuta = rutaDeProveedor.get(proveedor.dni) || null;
      const ruta = nombreRuta ? rutasPorNombre[nombreRuta] : null;
      const zona = nombreRuta ? zonasPorRuta.get(nombreRuta) : null;

      await Proveedor.findOrCreate({
        where: { dni: proveedor.dni, plantaId: planta.id },
        defaults: {
          ...proveedor,
          plantaId: planta.id,
          zonaId: zona ? zona.id : null,
          rutaId: ruta ? ruta.id : null,
          activo: true,
        },
      });
    }

    // El primer vehículo queda con acopiador asignado.
    if (unidades[0]) {
      await unidades[0].update({ acopiadorId: acopiador.id });
    }

    // Paradas ordenadas de cada ruta.
    for (const [nombreRuta, paradas] of Object.entries(PARADAS)) {
      const ruta = rutasPorNombre[nombreRuta];
      if (!ruta) continue;

      for (const parada of paradas) {
        const proveedor = await Proveedor.findOne({
          where: { dni: parada.dni, plantaId: planta.id },
        });
        if (!proveedor) continue;

        await RutaParada.findOrCreate({
          where: { rutaId: ruta.id, proveedorId: proveedor.id },
          defaults: {
            plantaId: planta.id,
            rutaId: ruta.id,
            proveedorId: proveedor.id,
            orden: parada.orden,
            horaEstimada: parada.horaEstimada,
            activa: true,
          },
        });
        await proveedor.update({ rutaId: ruta.id });
      }
    }

    resumen[datosPlanta.codigo] = {
      planta: planta.nombre,
      rutas: await Ruta.count({ where: { plantaId: planta.id } }),
      paradas: await RutaParada.count({ where: { plantaId: planta.id } }),
      unidades: await Unidad.count({ where: { plantaId: planta.id } }),
      zonas: await Zona.count({ where: { plantaId: planta.id } }),
      usuarios: await Usuario.count({ where: { plantaId: planta.id } }),
      proveedores: await Proveedor.count({ where: { plantaId: planta.id } }),
    };
    void admin;
    void superadmin;
  }

  log('Seed completado:', JSON.stringify(resumen, null, 2));
  log('Superadmin (cuenta de arranque): admin@milkdata.com / Superadmin123!');
  log('Admin de la planta principal: admin.huata@milkdata.com / Admin123!');
  return resumen;
}

if (require.main === module) {
  seed()
    .then(() => sequelize.close())
    .catch(async (error) => {
      console.error('Seed fallido:', error.message);
      await sequelize.close();
      process.exitCode = 1;
    });
}

/**
 * Los datos del seed se exportan para que `tests/helpers/limpiar-base.js`
 * pueda conservar exactamente estas filas y borrar todo lo demás. Así la
 * limpieza no se desincroniza cuando se agrega una zona, ruta o rol nuevo.
 */
module.exports = {
  seed,
  ROLES,
  PLANTAS,
  UNIDADES,
  ZONAS,
  PARADAS,
  PROVEEDORES,
  EMAILS_DE_SEMILLA: [
    'admin@milkdata.com',
    'admin.huata@milkdata.com',
    'acopiador@milkdata.com',
  ],
};
