const { toDTO: usuarioToDTO } = require('../../dtos/auth.dto');
const { toDTO: plantaToDTO } = require('../../dtos/planta.dto');
const securityAuthService = require('../../security/auth.service');
const usuarioRepository = require('../../repositories/usuario.repository');
const rolRepository = require('../../repositories/rol.repository');
const plantaRepository = require('../../repositories/planta.repository');
const { ROLES } = require('../../security/role-permissions.config');
const permissionsService = require('../../security/permissions.service');
const { httpError, unauthorized, notFound, badRequest } = require('../../utils/http-error');

class AuthService {
  /**
   * Registra un usuario dentro de una planta.
   *
   * Durante el bootstrap, si no existe ningún admin en la planta, solo se
   * permite crear el primero. Después, requiere rol admin.
   */
  async register({ nombre, apellido, email, password, rolId, plantaId }, trace = []) {
    trace.push('service');

    const planta = await plantaRepository.findById(plantaId);
    if (!planta) {
      throw httpError('La planta especificada no existe.');
    }

    const existing = await usuarioRepository.findOne({ where: { email } });
    if (existing) {
      throw httpError('El email ya está registrado.', 409);
    }

    const role = await rolRepository.findById(rolId);
    if (!role) {
      throw httpError('El rol especificado no existe.');
    }

    const adminRole = await rolRepository.findByNombre(ROLES.admin);
    if (!adminRole) {
      throw httpError('El rol admin no está configurado.');
    }

    // Autorización por planta: la resuelve `registerAccessMiddleware` antes de
    // llegar aquí. Aquí solo se valida el bootstrap, que solo aplica a la
    // primera planta del sistema: mientras no exista ningún admin en ninguna
    // parte, se puede crear el primero sin token.
    const adminEnElSistema = await usuarioRepository.findOne({ where: { rolId: adminRole.id } });
    if (!adminEnElSistema && Number(rolId) !== Number(adminRole.id)) {
      throw httpError('Debe existir un administrador antes de registrar otros roles.');
    }

    const hashedPassword = await securityAuthService.hashPassword(password);
    const usuario = await usuarioRepository.create({
      nombre,
      apellido,
      email,
      password: hashedPassword,
      rolId,
      plantaId: planta.id,
      activo: true,
    }, trace);

    return usuarioToDTO(usuario);
  }

  async login({ email, password }, trace = []) {
    trace.push('service');

    // Un correo ausente se rechaza antes de tocar la base. Sin este chequeo,
    // Sequelize lanza al recibir `undefined` dentro de un `where` y la peticion
    // termina en un 500 "error interno": un request mal formado no puede
    // reportarse como un fallo de nuestro servidor.
    if (!email || typeof email !== 'string' || !email.trim()) {
      throw httpError('El correo es obligatorio.', 400, ['email requerido']);
    }
    if (!password || typeof password !== 'string') {
      throw httpError('La contrasena es obligatoria.', 400, ['password requerido']);
    }

    const usuario = await usuarioRepository.findOne({
      where: { email: email.trim() },
      // `planta` además de `rol`: sin ella la sesión solo trae el `plantaId` y la
      // app no tiene forma de poner el nombre de la planta en ninguna pantalla.
      //
      // **No es una comodidad para quien entra.** Un recolector no tiene permiso
      // de `plantas: read`, así que no puede llamar a `/plantas` a averiguarlo: si
      // no viene aquí, no viene de ninguna parte. Y aunque lo tuviera, sería una
      // petición de más solo para pintar un título.
      include: [{ association: 'rol' }, { association: 'planta' }],
    }, trace);

    if (!usuario) {
      throw unauthorized('Credenciales inválidas.');
    }

    const passwordMatches = await securityAuthService.comparePassword(password, usuario.password);
    if (!passwordMatches) {
      throw unauthorized('Credenciales inválidas.');
    }

    if (!usuario.activo) {
      throw unauthorized('El usuario está inactivo.');
    }

    if (!usuario.plantaId) {
      throw unauthorized('El usuario no tiene planta asignada.');
    }

    const token = await securityAuthService.signToken({
      sub: usuario.id,
      email: usuario.email,
      rol: usuario.rol ? usuario.rol.nombre : null,
      rolId: usuario.rolId,
      plantaId: usuario.plantaId,
    });

    await usuarioRepository.update(usuario.id, { ultimoAcceso: new Date() });

    return {
      token,
      user: usuarioToDTO(usuario),
    };
  }

  /**
   * Plantas que el usuario autenticado puede supervisar.
   *
   * El superadmin ve todas: son las que puede revisar o escribir con
   * `POST /auth/planta`. Cualquier otro rol solo ve la suya, porque es la única
   * sobre la que tiene alcance.
   */
  async plantasDisponibles(usuario, trace = []) {
    trace.push('service');

    if (!permissionsService.isSuperadmin(usuario)) {
      const propia = await plantaRepository.findById(usuario.plantaId, {}, trace);

      const plantas = propia ? [propia] : [];
      return { total: plantas.length, plantas, alcance: 'PROPIA' };
    }

    const todas = await plantaRepository.findAll({ order: [['nombre', 'ASC']] }, trace);
    return { total: todas.length, plantas: todas.map(plantaToDTO), alcance: 'TODAS' };
  }

  /**
   * Matriz de permisos del token actual.
   *
   * No consulta la base: se resuelve con la matriz de
   * `role-permissions.config`, la misma que aplica `authorizeMiddleware`. Es la
   * misma información por la que pasan todas las peticiones, devuelta para que
   * el móvil pueda dibujar su menú sin adivinarlo.
   */
  async permisos(usuario, trace = []) {
    trace.push('service');

    return {
      rol: usuario.rol,
      superadmin: permissionsService.isSuperadmin(usuario),
      multiplanta: permissionsService.isSuperadmin(usuario),
      plantaId: usuario.plantaId,
      recursos: permissionsService.recursosDe(usuario),
    };
  }

  /**
   * Emite un token para otra planta. Solo el superadmin.
   *
   * El aislamiento sigue siendo el de siempre: el token lleva un `plantaId` y
   * los servicios filtran por él. Lo que cambia es que el superadmin puede
   * decidir cuál es su planta de trabajo, en vez de tenerla fija.
   */
  async cambiarPlanta(payload, usuario, trace = []) {
    trace.push('service');

    if (!permissionsService.isSuperadmin(usuario)) {
      throw httpError('Solo el superadmin puede cambiar de planta.', 403, ['Forbidden']);
    }

    const { plantaId, codigo } = payload || {};
    if (!plantaId && !codigo) {
      throw badRequest('Indica plantaId o codigo de la planta.');
    }

    const planta = await plantaRepository.findOne({
      where: codigo ? { codigo } : { id: plantaId },
    }, trace);

    if (!planta || !planta.activo) {
      throw notFound('Planta no encontrada.');
    }

    const token = await securityAuthService.signToken({
      sub: usuario.sub,
      email: usuario.email,
      rol: usuario.rol,
      rolId: usuario.rolId,
      plantaId: planta.id,
    });

    return { token, planta: plantaToDTO(planta) };
  }

  /**
 * Perfil del usuario autenticado, con su rol, planta y proveedor.
 *
 * `plantaId` es el de la **sesión**, no el de la fila del usuario. Son cosas
 * distintas: `usuario.planta_id` es la planta de origen, la "casa" del usuario,
 * y no cambia nunca; la del token sí cambia cuando un superadmin pide un token
 * para otra planta con `POST /auth/planta`.
 *
 * Devolver la de origen hacía que el perfil contradijera al token: la sesión
 * operaba sobre una planta mientras la app mostraba otra, y cualquier decisión
 * de interfaz basada en este campo tomaba la planta equivocada.
 *
 * @param {number} usuarioId
 * @param {number} [plantaIdDeSesion] Planta del token, la que manda.
 */
  async perfil(usuarioId, plantaIdDeSesion, trace = []) {
    trace.push('service');
    const usuario = await usuarioRepository.findById(usuarioId, {
      include: [
        { association: 'rol' },
        { association: 'planta' },
        { association: 'proveedor' },
      ],
    }, trace);

    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    const dto = usuarioToDTO(usuario);

    if (plantaIdDeSesion) {
      dto.plantaId = Number(plantaIdDeSesion);
      dto.planta = plantaIdDeSesion === usuario.plantaId
        ? dto.planta
        : await this.plantaPorId(plantaIdDeSesion, trace);
    }

    return dto;
  }

  /** Planta por su id, en DTO. */
  async plantaPorId(plantaId, trace = []) {
    // `findById` recibe `(id, options, trace)`: sin opciones se pasa `{}`, o el
    // trace acaba interpretado como objeto de opciones y Sequelize se queja.
    const planta = await plantaRepository.findById(plantaId, {}, trace);
    return planta ? plantaToDTO(planta) : null;
  }

  /**
   * Actualiza el perfil del usuario autenticado.
   * Email, password, rol y planta quedan fuera: no se cambian por esta vía.
   */
  async actualizarPerfil(usuarioId, { nombre, apellido, imagen }, trace = []) {
    trace.push('service');

    const cambios = {};
    if (nombre !== undefined) cambios.nombre = nombre;
    if (apellido !== undefined) cambios.apellido = apellido;
    if (imagen !== undefined) cambios.imagen = imagen;

    if (!Object.keys(cambios).length) {
      throw badRequest('No se envió ningún campo actualizable.');
    }

    const usuario = await usuarioRepository.update(usuarioId, cambios, trace);
    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    return usuarioToDTO(usuario);
  }

  async verifyToken(token) {
    if (!token) {
      throw unauthorized();
    }
    return securityAuthService.verifyToken(token);
  }

  async refreshToken(token) {
    const payload = await this.verifyToken(token);
    const nuevo = await securityAuthService.signToken({
      sub: payload.sub,
      email: payload.email,
      rol: payload.rol,
      rolId: payload.rolId,
      plantaId: payload.plantaId,
    });
    return { token: nuevo };
  }

  async logout() {
    return { success: true, message: 'Sesión cerrada correctamente.' };
  }
}

module.exports = new AuthService();
module.exports.AuthService = AuthService;
