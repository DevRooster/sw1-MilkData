const { sequelize, syncSchema } = require('../../src/config/database.config');
const entities = require('../../src/entities');
const { MIGRACIONES, TABLAS_CON_PLANTA } = require('../../src/migrations');
const { closeDatabase } = require('../helpers/auth');

afterAll(closeDatabase);

describe('Estado del esquema', () => {
  const esperadas = [
    'rol', 'planta', 'unidad', 'zona', 'usuario', 'proveedor',
    'recoleccion', 'control_calidad', 'notificacion', 'asistencia', 'producto',
  ];

  test('todas las tablas del modelo existen', async () => {
    const tablas = await sequelize.getQueryInterface().showAllTables();

    for (const tabla of esperadas) {
      expect(tablas).toContain(tabla);
    }
  });

  test('las renombradas ya no existen con el nombre viejo', async () => {
    const tablas = await sequelize.getQueryInterface().showAllTables();

    expect(tablas).not.toContain('entrega');
    expect(tablas).not.toContain('controlCalidad');
  });

  test('control_calidad usa recoleccion_id, no entrega_id', async () => {
    const columnas = Object.keys(await sequelize.getQueryInterface().describeTable('control_calidad'));

    expect(columnas).toContain('recoleccion_id');
    expect(columnas).not.toContain('entrega_id');
  });

  test('todas las tablas operativas tienen planta_id not null', async () => {
    for (const tabla of TABLAS_CON_PLANTA) {
      const columnas = await sequelize.getQueryInterface().describeTable(tabla);
      expect(columnas.planta_id).toBeTruthy();
      expect(columnas.planta_id.allowNull).toBe(false);
    }
  });

  test('rol no lleva planta_id porque es global', () => {
    expect(entities.Rol.rawAttributes.plantaId).toBeUndefined();
    expect(entities.Planta.rawAttributes.plantaId).toBeUndefined();
  });

  test('usuario no declara la clave foranea inversa a proveedor', () => {
    expect(entities.Usuario.rawAttributes.proveedorId).toBeUndefined();
    expect(entities.Proveedor.rawAttributes.usuarioId).toBeTruthy();
  });

  test('las columnas imagen existen y son opcionales', () => {
    for (const modelo of [entities.Usuario, entities.Proveedor, entities.Producto, entities.Planta]) {
      expect(modelo.rawAttributes.imagen.allowNull).toBe(true);
      expect(modelo.rawAttributes.imagen.defaultValue).toBeNull();
    }
  });

  test('syncSchema es idempotente', async () => {
    const resultado = await syncSchema({ log: () => {} });

    expect(resultado.created).toEqual([]);
  });
});

describe('Migraciones', () => {
  test('son idempotentes y ya estan aplicadas', async () => {
    const { runMigrations } = require('../../src/migrations');
    const resultado = await runMigrations({ sequelize, log: () => {} });

    expect(resultado.aplicadas).toEqual([]);
    expect(resultado.omitidas).toHaveLength(MIGRACIONES.length);
  });

  test('ninguna borra ni trunca datos', () => {
    for (const migracion of MIGRACIONES) {
      const codigo = migracion.run.toString();
      expect(codigo).not.toMatch(/\bTRUNCATE\b/i);
      expect(codigo).not.toMatch(/\bDROP\s+TABLE\b/i);
      expect(codigo).not.toMatch(/\bDELETE\s+FROM\b/i);
    }
  });

  test('cada migracion declara como decidir si aplica', () => {
    for (const migracion of MIGRACIONES) {
      expect(typeof migracion.nombre).toBe('string');
      expect(typeof migracion.antesDe).toBe('function');
      expect(typeof migracion.run).toBe('function');
    }
  });

  test('la columna imagen se agrega de forma aditiva, nunca destructiva', () => {
    const deImagen = MIGRACIONES.filter((m) => m.nombre.endsWith('agregar imagen'));

    expect(deImagen).toHaveLength(3);
    for (const migracion of deImagen) {
      expect(migracion.run.toString()).toMatch(/addColumn/);
    }
  });
});

describe('Asociaciones', () => {
  test('los 11 modelos estan registrados', () => {
    for (const nombre of Object.keys(entities)) {
      expect(typeof entities[nombre].findAll).toBe('function');
    }
  });

  test('cada entidad con plantaId tiene su asociacion con Planta', () => {
    const conPlanta = Object.entries(entities)
      .filter(([, modelo]) => modelo.rawAttributes.plantaId);

    expect(conPlanta.length).toBe(TABLAS_CON_PLANTA.length);

    for (const modelo of conPlanta.map(([, m]) => m)) {
      expect(modelo.associations.planta).toBeTruthy();
      expect(modelo.associations.planta.target).toBe(entities.Planta);
    }
  });

  test('las relaciones de Recoleccion resuelven con include', async () => {
    // Se arma la cadena completa para no depender de datos de otros tests.
    const marca = `assoc${Date.now().toString(36)}`;
    const planta = await entities.Planta.findOne({ where: { codigo: 'HUA' } });
    const usuario = await entities.Usuario.findOne({ where: { email: 'admin@milkdata.com' } });

    const unidad = await entities.Unidad.create({
      nombre: `U ${marca}`, tipo: 'furgon', capacidad: 1, plantaId: planta.id, activo: true,
    });
    const zona = await entities.Zona.create({
      nombre: `Z ${marca}`, ruta: 'R', unidadId: unidad.id, plantaId: planta.id, activo: true,
    });
    const proveedor = await entities.Proveedor.create({
      nombre: 'P', apellido: 'A', dni: marca, codigo: marca, zonaId: zona.id, plantaId: planta.id, activo: true,
    });
    const recoleccion = await entities.Recoleccion.create({
      plantaId: planta.id, proveedorId: proveedor.id, zonaId: zona.id, unidadId: unidad.id,
      usuarioId: usuario.id, cantidad: 5, fecha: '2026-10-01', registradoEn: 'campo',
    });

    try {
      const cargada = await entities.Recoleccion.findByPk(recoleccion.id, {
        include: [
          { association: 'proveedor' },
          { association: 'zona' },
          { association: 'unidad' },
          { association: 'usuario' },
          { association: 'planta' },
        ],
      });

      expect(cargada.proveedor).toBeTruthy();
      expect(cargada.zona).toBeTruthy();
      expect(cargada.unidad).toBeTruthy();
      expect(cargada.usuario).toBeTruthy();
      expect(cargada.planta.id).toBe(planta.id);
    } finally {
      await entities.Recoleccion.destroy({ where: { id: recoleccion.id } });
      await entities.Proveedor.destroy({ where: { id: proveedor.id } });
      await entities.Zona.destroy({ where: { id: zona.id } });
      await entities.Unidad.destroy({ where: { id: unidad.id } });
    }
  });

  test('ControlCalidad apunta a Recoleccion, ya no a Entrega', () => {
    expect(entities.ControlCalidad.associations.recoleccion).toBeTruthy();
    expect(entities.ControlCalidad.associations.entrega).toBeUndefined();
    expect(entities.Recoleccion.associations.controlCalidad).toBeTruthy();
  });

  test('producto solo se relaciona con planta por ahora', () => {
    // El módulo de ventas (V20) agregará ventas, inventario y producción.
    expect(Object.keys(entities.Producto.associations)).toEqual(['planta']);
  });
});

