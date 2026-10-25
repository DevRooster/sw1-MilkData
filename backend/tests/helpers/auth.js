const request = require('supertest');
const { Op } = require('sequelize');
const app = require('../../src/app');
const { sequelize } = require('../../src/config/database.config');
const { Usuario, Rol, Planta } = require('../../src/entities');
const securityAuthService = require('../../src/security/auth.service');

let contador = 0;

/** Planta principal del seed. */
async function plantaPrincipal() {
  const planta = await Planta.findOne({ where: { codigo: 'HUA' } });
  if (!planta) {
    throw new Error('No existe la planta HUA. Ejecuta el seed primero: pnpm run seed');
  }
  return planta;
}

/** Crea un usuario con el rol indicado dentro de una planta y devuelve su token. */
async function tokenForRole(rolNombre, suffix, plantaId) {
  const rol = await Rol.findOne({ where: { nombre: rolNombre } });
  if (!rol) {
    throw new Error(`El rol ${rolNombre} no existe. Ejecuta el seed primero.`);
  }

  const planta = plantaId ? await Planta.findByPk(plantaId) : await plantaPrincipal();

  // El contador evita choques de email si un test pide el mismo rol dos veces
  // dentro de la misma suite.
  contador += 1;
  const email = `${rolNombre}.${suffix}.${contador}@test.com`;
  const usuario = await Usuario.create({
    nombre: 'Test',
    apellido: rolNombre,
    email,
    password: await securityAuthService.hashPassword('Test123!'),
    rolId: rol.id,
    plantaId: planta.id,
    activo: true,
  });

  return securityAuthService.signToken({
    sub: usuario.id,
    email: usuario.email,
    rol: rolNombre,
    rolId: rol.id,
    plantaId: planta.id,
  });
}

/**
 * Credenciales de la cuenta de arranque, tal como las crea el seed.
 *
 * `admin@milkdata.com` es el superadmin: es la única que puede crear plantas,
 * así que es la que el seed deja lista para empezar. El helper no repite estas
 * cadenas para que un cambio en el seed no rompa las pruebas en silencio.
 */
const CREDENCIALES_INICIO = {
  email: 'admin@milkdata.com',
  password: 'Superadmin123!',
};

/** Credenciales del admin de la planta principal. */
const CREDENCIALES_ADMIN_HUATA = {
  email: 'admin.huata@milkdata.com',
  password: 'Admin123!',
};

/** Login real contra la API. Por defecto entra con la cuenta de arranque. */
async function login(email = CREDENCIALES_INICIO.email, password = CREDENCIALES_INICIO.password) {
  const response = await request(app).post('/auth/login').send({ email, password });
  if (response.statusCode !== 200) {
    throw new Error(`Login fallido (${response.statusCode}): ${JSON.stringify(response.body)}`);
  }
  return response.body.data.token;
}

function auth(token) {
  return { Authorization: `Bearer ${token}` };
}

/**
 * Borra los usuarios creados por una suite. El patrón es `rol.sufijo.N@test.com`,
 * así que el sufijo no queda pegado al dominio.
 */
async function cleanupTestUsers(suffix) {
  await Usuario.destroy({ where: { email: { [Op.like]: `%${suffix}%` } } });
}

/** Cambia la contraseña de la cuenta de arranque y devuelve la nueva. */
async function setAdminPassword(password) {
  await Usuario.update(
    { password: await securityAuthService.hashPassword(password) },
    { where: { email: CREDENCIALES_INICIO.email } }
  );
  return password;
}

function closeDatabase() {
  return sequelize.close();
}

module.exports = {
  app,
  request,
  tokenForRole,
  login,
  auth,
  cleanupTestUsers,
  setAdminPassword,
  plantaPrincipal,
  closeDatabase,
  CREDENCIALES_INICIO,
  CREDENCIALES_ADMIN_HUATA,
};
