const mysql = require('mysql2/promise');

/**
 * Levanta una base con el esquema ANTERIOR a multi-planta y con datos, para
 * comprobar que la migración los conserva.
 */
const ESQUEMA_VIEJO = {
  rol: `CREATE TABLE rol (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT, nivel INT NOT NULL DEFAULT 1, activo TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL)`,
  unidad: `CREATE TABLE unidad (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL,
    tipo ENUM('furgon','motocarga') NOT NULL, capacidad FLOAT NOT NULL DEFAULT 0,
    cerrado TINYINT(1) NOT NULL DEFAULT 0, activo TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL)`,
  zona: `CREATE TABLE zona (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL,
    ruta VARCHAR(255) NOT NULL, hora_inicio TIME, hora_fin TIME, unidad_id INT,
    activo TINYINT(1) NOT NULL DEFAULT 1, created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
    CONSTRAINT fk_zona_unidad FOREIGN KEY (unidad_id) REFERENCES unidad(id) ON DELETE SET NULL)`,
  usuario: `CREATE TABLE usuario (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE, password VARCHAR(255) NOT NULL,
    rol_id INT NOT NULL, proveedor_id INT, activo TINYINT(1) NOT NULL DEFAULT 1,
    ultimo_acceso DATETIME, created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES rol(id) ON DELETE CASCADE)`,
  proveedor: `CREATE TABLE proveedor (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL, dni VARCHAR(20) NOT NULL UNIQUE, telefono VARCHAR(30),
    codigo VARCHAR(50) NOT NULL UNIQUE, zona_id INT, usuario_id INT UNIQUE,
    activo TINYINT(1) NOT NULL DEFAULT 1, created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
    CONSTRAINT fk_prov_zona FOREIGN KEY (zona_id) REFERENCES zona(id) ON DELETE SET NULL,
    CONSTRAINT fk_prov_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE SET NULL)`,
  entrega: `CREATE TABLE entrega (id INT AUTO_INCREMENT PRIMARY KEY, proveedor_id INT NOT NULL,
    zona_id INT NOT NULL, unidad_id INT NOT NULL, usuario_id INT NOT NULL,
    cantidad FLOAT NOT NULL DEFAULT 0, fecha DATE NOT NULL, hora TIME, temperatura FLOAT,
    registrado_en ENUM('campo','planta') NOT NULL, sincronizado TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
    CONSTRAINT fk_ent_prov FOREIGN KEY (proveedor_id) REFERENCES proveedor(id),
    CONSTRAINT fk_ent_zona FOREIGN KEY (zona_id) REFERENCES zona(id),
    CONSTRAINT fk_ent_unidad FOREIGN KEY (unidad_id) REFERENCES unidad(id),
    CONSTRAINT fk_ent_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id))`,
  control_calidad: `CREATE TABLE control_calidad (id INT AUTO_INCREMENT PRIMARY KEY,
    entrega_id INT NOT NULL UNIQUE, usuario_id INT NOT NULL, grasa FLOAT, proteina FLOAT,
    lactosa FLOAT, densidad FLOAT, temperatura FLOAT, agua_anadida FLOAT, ph FLOAT,
    resultado ENUM('pura','adulterada') NOT NULL DEFAULT 'pura',
    created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
    CONSTRAINT fk_cc_entrega FOREIGN KEY (entrega_id) REFERENCES entrega(id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id))`,
};

/**
 * Conexion administrativa para crear y tirar bases de prueba.
 *
 * Los valores vienen del entorno y no estan fijos: dentro de Docker el servidor
 * no esta en `localhost` y no es `root` sin clave, asi que con literales la
 * suite no podia ni crear la base vieja que esta migracion debe probar.
 *
 * `TEST_DB_ADMIN_USER` y `TEST_DB_ADMIN_PASSWORD` son aparte de `DB_USER` a
 * proposito: el usuario de la aplicacion no tiene permiso para `CREATE DATABASE`,
 * que es justo lo que necesita este helper.
 */
async function conexion() {
  return mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.TEST_DB_ADMIN_USER || process.env.DB_USER || 'root',
    password: process.env.TEST_DB_ADMIN_PASSWORD ?? (process.env.DB_PASSWORD || ''),
    multipleStatements: false,
  });
}

/** Crea una base con el esquema viejo y algunos datos de prueba. */
async function crearBaseConDatosViejos(nombre) {
  const c = await conexion();
  await c.query(`DROP DATABASE IF EXISTS \`${nombre}\``);
  await c.query(`CREATE DATABASE \`${nombre}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await c.query(`USE \`${nombre}\``);

  for (const sql of Object.values(ESQUEMA_VIEJO)) {
    await c.query(sql);
  }

  const ahora = "'2026-01-01 08:00:00'";
  await c.query(`INSERT INTO rol (nombre, nivel, created_at, updated_at) VALUES ('admin', 5, ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO unidad (nombre, tipo, capacidad, created_at, updated_at)
                 VALUES ('Furgón Legacy', 'furgon', 900, ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO zona (nombre, ruta, unidad_id, created_at, updated_at)
                 VALUES ('Zona Legacy', 'Ruta Legacy', 1, ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO usuario (nombre, apellido, email, password, rol_id, created_at, updated_at)
                 VALUES ('Admin', 'Legacy', 'legacy@test.com', 'hash', 1, ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO proveedor (nombre, apellido, dni, codigo, zona_id, created_at, updated_at)
                 VALUES ('Proveedor', 'Legacy', '80000001', 'LEG-001', 1, ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO entrega (proveedor_id, zona_id, unidad_id, usuario_id, cantidad, fecha,
                 registrado_en, created_at, updated_at)
                 VALUES (1, 1, 1, 1, 42, '2026-01-01', 'campo', ${ahora}, ${ahora})`);
  await c.query(`INSERT INTO control_calidad (entrega_id, usuario_id, grasa, created_at, updated_at)
                 VALUES (1, 1, 3.5, ${ahora}, ${ahora})`);

  await c.end();
  return nombre;
}

async function eliminarBase(nombre) {
  const c = await conexion();
  await c.query(`DROP DATABASE IF EXISTS \`${nombre}\``);
  await c.end();
}

module.exports = { crearBaseConDatosViejos, eliminarBase, conexion, ESQUEMA_VIEJO };
