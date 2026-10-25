/**
 * Migraciones de esquema. Son idempotentes: correrlas dos veces no cambia nada.
 *
 * `syncSchema()` crea las tablas que faltan con `alter: false`, así que todo lo
 * que sea cambiar una tabla existente vive aquí. Hay dos tipos:
 *
 * - `addColumn`   agrega una columna si falta.
 * - `run`         SQL arbitrario, con `antesDe` para decidir si aplica.
 *
 * Reglas: nunca se borra ni se truncan datos. Renombrar y cambiar tipos están
 * permitidos porque conservan el contenido.
 */

const { DataTypes } = require('sequelize');

/** Tablas que pertenecen a una planta, con la columna que las aísla. */
const TABLAS_CON_PLANTA = [
  'usuario',
  'proveedor',
  'unidad',
  'zona',
  'ruta',
  'ruta_parada',
  'recorrido',
  'recorrido_parada',
  'recoleccion',
  'control_calidad',
  'notificacion',
  'asistencia',
  'producto',
  'imagen',
  'evento',
];

/**
 * Código con el que se crea la planta principal en una base nueva.
 *
 * Solo sirve para el arranque en frío. En cuanto la base tiene plantas, este
 * valor deja de importar: buscar la planta principal por su código falla en
 * cuanto alguien edita ese código desde la app, y con él falla el arranque.
 */
const CODIGO_PLANTA_INICIAL = 'HUA';

/**
 * Tabla donde queda anotado qué migraciones ya corrieron.
 *
 * Sin ella, cada arranque volvía a preguntar a los datos si faltaba algo, y los
 * datos los edita la app desde el móvil.
 */
const TABLA_MIGRACIONES = 'migracion_aplicada';

/**
 * Id de la planta principal, sin depender del código.
 *
 * Primero busca el código de arranque y, si ya no está —porque se editó desde
 * la app— cae a la planta más antigua, que en una base creada por el seed es
 * justo la principal.
 *
 * Medido: con la planta inicial renombrada de `HUA` a `HUATA` desde la app, la
 * API dejaba de arrancar porque las migraciones buscaban `HUA` y no lo
 * encontraban. Aquí se resuelve por id y el arranque vuelve a funcionar.
 *
 * @param {import('sequelize').Sequelize} sequelize
 * @returns {Promise<number|null>} null si no hay ninguna planta.
 */
async function idDePlantaPrincipal(sequelize) {
  const [[porCodigo]] = await sequelize.query(
    'SELECT id FROM planta WHERE codigo = ? LIMIT 1',
    { replacements: [CODIGO_PLANTA_INICIAL] }
  );
  if (porCodigo) {
    return porCodigo.id;
  }

  const [[masAntigua]] = await sequelize.query('SELECT id FROM planta ORDER BY id LIMIT 1');

  return masAntigua ? masAntigua.id : null;
}

const MIGRACIONES = [
  // ------------------------------------------------------------------
  // Renombres. Van antes de `sync` a propósito: si `sync` corriera primero,
  // crearía la tabla `recoleccion` vacía y el RENAME de `entrega` fallaría
  // por colisión de nombre.
  //
  // Las migraciones de columna solo corren sobre tablas que ya existen. Las
  // que faltan las crea `sync`, ya completas con `planta_id` en el modelo.
  // ------------------------------------------------------------------
  {
    nombre: 'entrega: renombrar tabla a recoleccion',
    antesDeSync: true,
    async run({ sequelize }) {
      await sequelize.query('RENAME TABLE entrega TO recoleccion');
    },
    antesDe: async ({ tablas }) => tablas.has('entrega'),
  },

  {
    nombre: 'control_calidad: renombrar entrega_id a recoleccion_id',
    antesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.renameColumn('control_calidad', 'entrega_id', 'recoleccion_id');
    },
    antesDe: async ({ columnas }) => {
      const controlCalidad = columnas.get('control_calidad');
      return Boolean(controlCalidad && controlCalidad.has('entrega_id'));
    },
  },

  // ------------------------------------------------------------------
  // Imagenes. Columnas opcionales que se anaden a las tablas que ya existen.
  // ------------------------------------------------------------------
  ...['usuario', 'proveedor', 'producto'].map((tabla) => ({
    nombre: `${tabla}: agregar imagen`,
    async run({ queryInterface }) {
      await queryInterface.addColumn(tabla, 'imagen', {
        type: DataTypes.STRING(255),
        allowNull: true,
        defaultValue: null,
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has(tabla)) {
        return false;
      }
      return !(columnas.get(tabla) || new Set()).has('imagen');
    },
  })),

  // ------------------------------------------------------------------
  // Eventos
  //
  // `evento` la crea `sync` porque es una tabla nueva del modelo. La columna
  // `asistencia.evento_id` sí necesita migración: `asistencia` ya existe y
  // `sync` va con `alter: false`, así que sin esto la columna no aparecería
  // nunca en una base que ya tenga asistencias.
  //
  // Va `despuesDeSync` y es **nullable sin valor por defecto**: las asistencias
  // que ya están escritas no tienen evento del catálogo y no hay forma de
  // adivinar a cuál se refiere cada texto libre. Rellenarlas de mentira sería
  // peor que dejarlas a null.
  // ------------------------------------------------------------------
  {
    nombre: 'asistencia: agregar evento_id',
    despuesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.addColumn('asistencia', 'evento_id', {
        type: DataTypes.INTEGER,
        allowNull: true,
        defaultValue: null,
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('asistencia')) {
        return false;
      }
      return !(columnas.get('asistencia') || new Set()).has('evento_id');
    },
  },

  // ------------------------------------------------------------------
  // Rutas y recorridos
  //
  // Estas van `despuesDeSync` porque agregan columnas que referencian tablas
  // nuevas (ruta, recorrido_parada). En una base ya creada esas tablas las
  // genera `sync`, y la migración solo tiene sentido sobre ellas.
  // ------------------------------------------------------------------
  {
    nombre: 'zona: convertir el texto ruta en ruta_id',
    despuesDeSync: true,
    async run({ sequelize, queryInterface }) {
      const columnas = await queryInterface.describeTable('zona');

      // En una base creada desde el modelo actual, `zona` nunca tuvo la columna
      // de texto `ruta`: el modelo solo declara `ruta_id`, que `sync` ya dejó en
      // su sitio. No hay nada que convertir ni que relajar, y seguir adelante
      // solo produciría un error de columna inexistente.
      if (!columnas.ruta) {
        return;
      }

      if (!columnas.ruta_id) {
        await queryInterface.addColumn('zona', 'ruta_id', {
          type: DataTypes.INTEGER,
          allowNull: true,
        });
      }

      // Cada valor distinto de `zona.ruta` se convierte en una ruta de la misma
      // planta, y la zona queda apuntando a ella. El texto no se borra: pasa a
      // ser opcional y la app ya no lo lee.
      const [datos] = await sequelize.query(
        `SELECT DISTINCT ruta, planta_id AS idPlanta FROM zona
         WHERE ruta_id IS NULL AND ruta IS NOT NULL AND ruta <> ''`
      );

      for (const { ruta: nombreRuta, idPlanta: plantaId } of datos) {
        const [existentes] = await sequelize.query(
          'SELECT id FROM ruta WHERE nombre = ? AND planta_id = ?',
          { replacements: [nombreRuta, plantaId] }
        );

        let rutaId = existentes.length ? existentes[0].id : null;
        if (!rutaId) {
          // `ruta.planta_id` es NOT NULL: se hereda de la zona que la nombra.
          const base = String(nombreRuta).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 16) || 'RUTA';
          let codigo = base;
          for (let intento = 1; intento < 100; intento += 1) {
            const [choques] = await sequelize.query(
              'SELECT id FROM ruta WHERE codigo = ? AND planta_id = ?',
              { replacements: [codigo, plantaId] }
            );
            if (!choques.length) break;
            codigo = `${base}${intento}`.slice(0, 20);
          }

          await sequelize.query(
            `INSERT INTO ruta (planta_id, nombre, codigo, activa, created_at, updated_at)
             VALUES (:idPlanta, :nombreRuta, :codigoRuta, 1, :momento, :momento)`,
            {
              replacements: {
                idPlanta: plantaId,
                nombreRuta,
                codigoRuta: codigo,
                momento: new Date(),
              },
            }
          );
          // El id generado se pide con LAST_INSERT_ID() en lugar de leer el
          // paquete de MySQL: la forma de ese paquete es un detalle del
          // driver y no merece la pena depender de ella.
          const [[generado]] = await sequelize.query('SELECT LAST_INSERT_ID() AS id');
          rutaId = generado.id;
        }

        await sequelize.query(
          `UPDATE zona SET ruta_id = :idRuta
           WHERE ruta = :nombreRuta AND planta_id = :idPlanta`,
          { replacements: { idRuta: rutaId, nombreRuta, idPlanta: plantaId } }
        );
      }

      await queryInterface.changeColumn('zona', 'ruta', {
        type: DataTypes.STRING(255),
        allowNull: true,
      });
    },
    /**
     * El guard mira el resultado, no solo la columna: si una corrida anterior
     * agregó la columna pero falló antes de convertir los datos, esta migración
     * tiene que volver a ejecutarse para completarla.
     *
     * Si la columna ni siquiera existe todavía, la migración está pendiente
     * siempre: el `run` la crea y luego convierte.
     *
     * Y si la columna de texto `ruta` no existe, no hay nada pendiente: en una
     * base creada desde el modelo actual esa columna jamás existió, y dar por
     * hecha su presencia rompía el arranque en una instalación limpia.
     */
    antesDe: async ({ sequelize, tablas, columnas }) => {
      if (!tablas.has('zona')) {
        return false;
      }

      const columnasZona = columnas.get('zona') || new Set();
      if (!columnasZona.has('ruta')) {
        return false;
      }

      if (!columnasZona.has('ruta_id')) {
        return true;
      }

      const [conteo] = await sequelize.query(
        `SELECT COUNT(*) AS pendientes FROM zona
         WHERE ruta_id IS NULL AND ruta IS NOT NULL AND ruta <> ''`
      );
      return Number(conteo[0].pendientes) > 0;
    },
  },

  {
    nombre: 'unidad: agregar acopiador_id',
    despuesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.addColumn('unidad', 'acopiador_id', {
        type: DataTypes.INTEGER,
        allowNull: true,
      });
      await queryInterface.addConstraint('unidad', {
        fields: ['acopiador_id'],
        type: 'foreign key',
        name: 'fk_unidad_acopiador',
        references: { table: 'usuario', field: 'id' },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('unidad')) {
        return false;
      }
      return !(columnas.get('unidad') || new Set()).has('acopiador_id');
    },
  },

  // ------------------------------------------------------------------
  // La cuenta de arranque pasa a ser el superadmin
  //
  // Antes el seed creaba `admin@milkdata.com` con rol admin y una cuenta
  // aparte, `superadmin@milkdata.com`, con el superadmin. Ahora la cuenta de
  // arranque ES el superadmin, porque es la única que puede crear plantas y
  // fundar el primer admin de cada una.
  //
  // Va como migración y no solo en el seed por una razón concreta: el seed usa
  // `findOrCreate`, que respeta el usuario si ya existe. Sobre una base que ya
  // tenía `admin@milkdata.com` como admin, volver a correr el seed no lo
  // ascendía, y la cuenta se quedaba sin poder crear plantas.
  // ------------------------------------------------------------------
  {
    nombre: 'usuario: admin@milkdata.com es el superadmin',
    despuesDeSync: true,
    async run({ sequelize }) {
      const [rolSuperadmin] = await sequelize.query(
        "SELECT id FROM rol WHERE nombre = 'superadmin' LIMIT 1"
      );

      const [usuario] = await sequelize.query(
        "SELECT id, rol_id FROM usuario WHERE email = 'admin@milkdata.com' LIMIT 1"
      );

      if (!rolSuperadmin || !usuario) {
        return;
      }

      if (String(usuario.rol_id) !== String(rolSuperadmin.id)) {
        await sequelize.query(
          'UPDATE usuario SET rol_id = :rolSuperadmin WHERE id = :id',
          { replacements: { rolSuperadmin: rolSuperadmin.id, id: usuario.id } }
        );
      }

      // La cuenta antigua se retira, pero desactivada y no borrada.
      //
      // `database.test.js` vigila que ninguna migracion borre filas, y con
      // razon: una migracion que destruye datos es irreversible. Aquí tampoco
      // hay motivo, porque el usuario conserva su fila y sus referencias. Con
      // `activo = 0` deja de poder entrar y sus datos siguen ahí por si hay que
      // revisar algo.
      await sequelize.query(
        "UPDATE usuario SET activo = 0 WHERE email = 'superadmin@milkdata.com'"
      );
    },
    antesDe: async ({ tablas, sequelize }) => {
      if (!tablas.has('usuario') || !tablas.has('rol')) {
        return false;
      }

      // Si el rol superadmin todavia no existe no hay nada que promover, y quedarnos
      // pendientes no haria mas que reaplicar en cada corrida.
      const [rolSuperadmin] = await sequelize.query(
        "SELECT id FROM rol WHERE nombre = 'superadmin' LIMIT 1"
      );
      if (!rolSuperadmin) {
        return false;
      }

      const [usuario] = await sequelize.query(
        "SELECT id, rol_id FROM usuario WHERE email = 'admin@milkdata.com' LIMIT 1"
      );

      // Sin la cuenta de arranque tampoco hay nada que hacer.
      if (!usuario) {
        return false;
      }

      // Solo cuenta como pendiente la cuenta antigua mientras siga activa. Si ya
      // esta desactivada, correrla de nuevo no cambiaria nada.
      const [antigua] = await sequelize.query(
        "SELECT id, activo FROM usuario WHERE email = 'superadmin@milkdata.com' LIMIT 1"
      );

      const pendiente =
        String(usuario.rol_id) !== String(rolSuperadmin.id) ||
        Boolean(antigua && antigua.activo);

      return Boolean(pendiente);
    },
  },

  {
    nombre: 'proveedor: agregar ruta_id',
    despuesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.addColumn('proveedor', 'ruta_id', {
        type: DataTypes.INTEGER,
        allowNull: true,
      });
      await queryInterface.addConstraint('proveedor', {
        fields: ['ruta_id'],
        type: 'foreign key',
        name: 'fk_proveedor_ruta',
        references: { table: 'ruta', field: 'id' },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      });
      await queryInterface.addIndex('proveedor', ['ruta_id'], { name: 'idx_proveedor_ruta' });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('proveedor') || !tablas.has('ruta')) {
        return false;
      }
      return !(columnas.get('proveedor') || new Set()).has('ruta_id');
    },
  },

  {
    nombre: 'recorrido: fecha_inicio y fecha_fin a DATE',
    despuesDeSync: true,
    async run({ sequelize, queryInterface }) {
      // Se declararon como DATE y MySQL los creó como DATETIME. La hora
      // exacta ya está en hora_inicio / hora_fin; estas solo llevan fecha.
      for (const columna of ['fecha_inicio', 'fecha_fin']) {
        const descripcion = await queryInterface.describeTable('recorrido');
        if (descripcion[columna] && descripcion[columna].type.toLowerCase() !== 'dateonly') {
          await queryInterface.changeColumn('recorrido', columna, {
            type: DataTypes.DATEONLY,
            allowNull: true,
          });
        }
      }
      void sequelize;
    },
    antesDe: async ({ sequelize, tablas }) => {
      if (!tablas.has('recorrido')) {
        return false;
      }
      const [filas] = await sequelize.query(
        `SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'recorrido'
            AND COLUMN_NAME IN ('fecha_inicio', 'fecha_fin') AND DATA_TYPE <> 'date'`
      );
      return filas.length > 0;
    },
  },

  {
    nombre: 'proveedor: agregar direccion',
    despuesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.addColumn('proveedor', 'direccion', {
        type: DataTypes.STRING(255),
        allowNull: true,
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('proveedor')) {
        return false;
      }
      return !(columnas.get('proveedor') || new Set()).has('direccion');
    },
  },

  {
    nombre: 'recoleccion: agregar recorrido_parada_id',
    despuesDeSync: true,
    async run({ queryInterface }) {
      await queryInterface.addColumn('recoleccion', 'recorrido_parada_id', {
        type: DataTypes.INTEGER,
        allowNull: true,
        unique: true,
      });
      await queryInterface.addConstraint('recoleccion', {
        fields: ['recorrido_parada_id'],
        type: 'foreign key',
        name: 'fk_recoleccion_parada',
        references: { table: 'recorrido_parada', field: 'id' },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('recoleccion') || !tablas.has('recorrido_parada')) {
        return false;
      }
      return !(columnas.get('recoleccion') || new Set()).has('recorrido_parada_id');
    },
  },

  // ------------------------------------------------------------------
  // Multi-planta
  // ------------------------------------------------------------------
  {
    nombre: 'planta: crear tabla',
    async run({ queryInterface }) {
      await queryInterface.createTable('planta', {
        id: {
          type: DataTypes.INTEGER,
          primaryKey: true,
          autoIncrement: true,
          allowNull: false,
        },
        nombre: { type: DataTypes.STRING(120), allowNull: false, unique: true },
        codigo: { type: DataTypes.STRING(20), allowNull: false, unique: true },
        direccion: { type: DataTypes.STRING(255), allowNull: true },
        imagen: { type: DataTypes.STRING(255), allowNull: true, defaultValue: null },
        activo: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        created_at: { type: DataTypes.DATE, allowNull: false },
        updated_at: { type: DataTypes.DATE, allowNull: false },
      });
    },
    antesDe: async ({ tablas }) => !tablas.has('planta'),
  },

  {
    nombre: 'planta: registrar la planta principal',
    async run({ sequelize }) {
      const ahora = new Date();
      await sequelize.query(
        `INSERT INTO planta (nombre, codigo, direccion, activo, created_at, updated_at)
         VALUES ('Planta Ecológica Huata', :codigo, 'Distrito de Huata', true, :ahora, :ahora)`,
        { replacements: { ahora, codigo: CODIGO_PLANTA_INICIAL } }
      );
    },
    /**
     * Solo en una base **sin ninguna planta**.
     *
     * Antes miraba `codigo = 'HUA'`, y eso rompía el arranque: si la planta
     * inicial se renombraba desde la app —el código es editable—, el código
     * `HUA` desaparecía y la migración Corvette a insertarla otra vez. Chocaba
     * con el índice único de `nombre` y el servidor no arrancaba, dejando la
     * app entera sin conexión.
     *
     * Ahora da igual cómo se llame la planta: si hay alguna, ya se registró.
     */
    antesDe: async ({ sequelize }) => {
      const [[{ total }]] = await sequelize.query('SELECT COUNT(*) AS total FROM planta');

      return Number(total) === 0;
    },
  },

  // La planta principal se crea más arriba, pero las tablas operativas aún no
  // tienen la columna. Por eso su id se resuelve en tiempo de ejecución.
  ...TABLAS_CON_PLANTA.map((tabla) => ({
    nombre: `${tabla}: agregar planta_id`,
    async run({ sequelize, queryInterface }) {
      const plantaId = await idDePlantaPrincipal(sequelize);
      if (!plantaId) {
        throw new Error(`No se puede agregar planta_id a ${tabla}: no hay ninguna planta.`);
      }

      await queryInterface.addColumn(tabla, 'planta_id', {
        type: DataTypes.INTEGER,
        allowNull: true,
      });

      // Los registros previos se asignan a la planta principal para no
      // dejarlos huerfanos ni perderlos.
      await sequelize.query(`UPDATE ${tabla} SET planta_id = :plantaId WHERE planta_id IS NULL`, {
        replacements: { plantaId },
      });

      await queryInterface.changeColumn(tabla, 'planta_id', {
        type: DataTypes.INTEGER,
        allowNull: false,
      });

      await queryInterface.addConstraint(tabla, {
        fields: ['planta_id'],
        type: 'foreign key',
        name: `fk_${tabla}_planta`,
        references: { table: 'planta', field: 'id' },
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      });

      await queryInterface.addIndex(tabla, ['planta_id'], {
        name: `idx_${tabla}_planta`,
      });
    },
    antesDe: async ({ tablas, columnas }) => {
      if (!tablas.has('planta')) {
        return false;
      }
      // Si la tabla aún no existe, `sync` la creará completa y con
      // `planta_id` included. Agregarla aquí sería redundante.
      if (!tablas.has(tabla)) {
        return false;
      }
      const existentes = columnas.get(tabla) || new Set();
      return !existentes.has('planta_id');
    },
  })),

];

/**
 * Corre las migraciones en tres fases. `fase` permite ejecutar solo un grupo:
 *
 *  - `antes`    `antesDeSync` (renombres) y las que no llevan marca, que solo
 *               tocan tablas que ya existen.
 *  - `despues`  las que agregan columnas referenciando tablas nuevas, porque
 *               esas las crea `sync` y todavía no existen.
 *  - `todas`    las tres, en orden. Útil en tests y scripts.
 *
 * @param {object} deps
 * @param {object} deps.sequelize
 * @param {'antes'|'despues'|'todas'} [deps.fase='todas']
 * @param {Function} [deps.log]
 * @returns {Promise<{aplicadas: string[], omitidas: string[]}>}
 */
async function runMigrations({ sequelize, log = () => {}, fase = 'todas' } = {}) {
  const queryInterface = sequelize.getQueryInterface();

  const contexto = async () => {
    const tablas = new Set(await queryInterface.showAllTables());
    const columnas = new Map();
    for (const tabla of tablas) {
      const descripcion = await queryInterface.describeTable(tabla);
      columnas.set(tabla, new Set(Object.keys(descripcion)));
    }
    return { sequelize, queryInterface, tablas, columnas };
  };

  await queryInterface.createTable(
    TABLA_MIGRACIONES,
    {
      nombre: { type: DataTypes.STRING(190), allowNull: false, primaryKey: true },
      aplicada_en: { type: DataTypes.DATE, allowNull: false },
    },
    { ifNotExists: true }
  );

  const [registros] = await sequelize.query(`SELECT nombre FROM ${TABLA_MIGRACIONES}`);
  const yaAplicadas = new Set(registros.map((r) => r.nombre));

  const aplicadas = [];
  const omitidas = [];

  const antes = MIGRACIONES.filter((m) => m.antesDeSync || !m.despuesDeSync);
  const despues = MIGRACIONES.filter((m) => m.despuesDeSync);
  const fases = fase === 'antes' ? [antes] : fase === 'despues' ? [despues] : [antes, despues];

  for (const migracion of fases.flat()) {
    /**
     * **Primero el registro, y solo después `antesDe`.**
     *
     * `antesDe` decide mirando los datos, y los datos cambian: la app deja
     * editar el nombre y el código de una planta, así que la planta inicial
     * puede dejar de llamarse `HUA` y las preguntas que hacían las migraciones
     * empiezan a dar una respuesta distinta. Cuando eso pasó, la migración
     * `planta: registrar la planta principal` creyó que faltaba, intentó
     * insertarla otra vez y reventó contra el índice único de `nombre`: el
     * servidor no arrancaba y la app se quedaba sin conexión.
     *
     * Una migración que ya corrió una vez no vuelve a correr, diga lo que diga
     * la tabla. El registro es la verdad; `antesDe` solo decide de las que
     * aún no se han visto nunca.
     */
    if (yaAplicadas.has(migracion.nombre)) {
      omitidas.push(migracion.nombre);
      continue;
    }

    const ctx = await contexto();
    if (!(await migracion.antesDe(ctx))) {
      omitidas.push(migracion.nombre);
      continue;
    }

    await migracion.run(ctx);
    await sequelize.query(
      `INSERT IGNORE INTO ${TABLA_MIGRACIONES} (nombre, aplicada_en) VALUES (:nombre, :ahora)`,
      { replacements: { nombre: migracion.nombre, ahora: new Date() } }
    );
    yaAplicadas.add(migracion.nombre);
    aplicadas.push(migracion.nombre);
  }

  if (aplicadas.length) {
    log(`Migraciones aplicadas: ${aplicadas.length}`);
    for (const nombre of aplicadas) {
      log(`  + ${nombre}`);
    }
  }
  if (omitidas.length) {
    log(`Migraciones omitidas (ya aplicadas): ${omitidas.length}`);
  }

  return { aplicadas, omitidas };
}

module.exports = {
  MIGRACIONES,
  TABLAS_CON_PLANTA,
  runMigrations,
  TABLA_MIGRACIONES,
  CODIGO_PLANTA_INICIAL,
  idDePlantaPrincipal,
};
