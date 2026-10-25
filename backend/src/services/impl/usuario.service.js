const { Op } = require('sequelize');
const BaseService = require('./base.service');
const usuarioRepository = require('../../repositories/usuario.repository');
const { toDTO } = require('../../dtos/auth.dto');
const securityAuthService = require('../../security/auth.service');
const permissionsService = require('../../security/permissions.service');
const { httpError, badRequest, notFound } = require('../../utils/http-error');

/**
 * Usuarios de la planta.
 *
 * Hereda el CRUD de `BaseService`, con tres reglas que no son genéricas:
 *
 * - **La contraseña no se devuelve.** Nunca, ni al listar. El DTO no la incluye,
 *   y además la consulta no la trae para no tenerla en memoria sin necesidad.
 * - **Editar no cambia el rol ni la planta por la vía rápida.** Subir de rol o
 *   mover de planta cambia qué puede hacer la persona y sobre qué datos opera;
 *   dejar eso en un `PUT` de perfil sería un escalón de permisos accidental. Se
 *   exige `PUT /usuarios/:id/rol`, que comprueba quién lo pide.
 * - **No se borra a uno mismo ni al último admin de la planta.** Lo primero
 *   deja la sesión sin dueño; lo segundo deja la planta sin nadie que la
 *   administre.
 */
class UsuarioService extends BaseService {
  constructor() {
    super(usuarioRepository, toDTO);
  }


/**
   * Nombres de filtro que admite este listado.
   *
   * `list` está sobrescrito y construye su propio `where`, así que no usa
   * `_filtros()` de la base. Aun así declara qué admite, porque el controller
   * rechaza con un 400 lo que no reconoce: sin esto, `?rolId=3` — que este
   * servicio entiende de sobra — llegaría como filtro desconocido.
   */
  nombresDeFiltro() {
    return ['rolId', 'activo', 'busqueda'];
  }
  /** Columnas que se piden al listar: la contraseña se queda fuera. */
  _atributos() {
    return { exclude: ['password'] };
  }

  async list(contexto, trace = [], opciones = {}) {
    trace.push('service');
    const { pagina = 1, limite = 10, rolId, activo, busqueda, ...resto } = opciones || {};

    const where = {};
    if (rolId) {
      where.rolId = Number(rolId);
    }
    if (activo !== undefined && activo !== '') {
      where.activo = activo === 'true' || activo === true || activo === 1;
    }
    if (busqueda) {
      // Se busca en nombre, apellido y correo. Un `LIKE` con el texto tal cual:
      // escapar `%` y `_` de usuario daría resultados raros, pero no es un
      // problema de seguridad aquí porque el valor va como reemplazo.
      where[Op.or] = [
        { nombre: { [Op.like]: `%${busqueda}%` } },
        { apellido: { [Op.like]: `%${busqueda}%` } },
        { email: { [Op.like]: `%${busqueda}%` } },
      ];
    }

    const { count, rows } = await usuarioRepository.findAndCountAll({
      ...this._options(contexto, { ...resto, where: { ...where, ...resto.where } }),
      attributes: this._atributos(),
      include: [
        { association: 'rol' },
        { association: 'planta' },
      ],
      order: [['id', 'ASC']],
      limit: Number(limite),
      offset: (Number(pagina) - 1) * Number(limite),
    }, trace);

    return {
      items: rows.map((registro) => toDTO(registro)),
      paginacion: this._paginacion(Number(pagina), Number(limite), count),
    };
  }

  async findById(contexto, id, trace = []) {
    trace.push('service');
    const usuario = await usuarioRepository.findOne({
      where: this._where(contexto, { id }),
      attributes: this._atributos(),
      include: [
        { association: 'rol' },
        { association: 'planta' },
      ],
    }, trace);

    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    return toDTO(usuario);
  }

  async update(contexto, id, data, trace = []) {
    trace.push('service');
    const { rolId, plantaId, password, ...cambios } = data || {};

    if (rolId !== undefined || plantaId !== undefined) {
      throw badRequest(
        'El rol y la planta no se cambian con este endpoint. Usa PUT /usuarios/{id}/rol.'
      );
    }

    const usuario = await usuarioRepository.findOne({
      where: this._where(contexto, { id }),
    }, trace);
    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    // La contraseña cambia por su propio endpoint, para poder cifrarla y no
    // mezclarla con los datos de perfil.
    if (password) {
      cambios.password = await securityAuthService.hashPassword(password);
    }

    await usuario.update(cambios);
    return this.findById(contexto, id, trace);
  }

  /**
   * Cambia el rol de un usuario.
   *
   * Separado del `PUT` de perfil a propósito: subir o bajar de rol es un cambio
   * de poder y tiene reglas propias.
   */
  async cambiarRol(contexto, id, rolId, trace = []) {
    trace.push('service');
    const nuevoRolId = Number(rolId);
    const actor = contexto && contexto.actor;

    const usuario = await usuarioRepository.findOne({
      where: this._where(contexto, { id }),
    }, trace);
    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    const { Rol } = require('../../entities');
    const rol = await Rol.findByPk(nuevoRolId);
    if (!rol) {
      throw badRequest('El rol especificado no existe.');
    }

    // Solo el superadmin puede dar o quitar superadmin. Sin esto, un admin de
    // planta podría ascender a alguien y saltarse el filtro que ya se puso en el
    // registro de usuarios nuevos.
    const { ROLES } = require('../../security/role-permissions.config');
    const actualEsSuper = usuario.rolId === (await this._idDeSuperadmin());
    const nuevoEsSuper = rol.nombre === ROLES.superadmin;

    if ((actualEsSuper || nuevoEsSuper) && !permissionsService.isSuperadmin(actor)) {
      throw httpError(
        'Solo un superadmin puede crear, ascender o degradar a un superadmin.',
        403,
        ['Forbidden']
      );
    }

    // No dejar la planta sin admins.
    if (actualEsSuper && !nuevoEsSuper) {
      await this._comprobarQuedanAdmins(contexto, trace);
    }

    await usuario.update({ rolId: nuevoRolId });
    return this.findById(contexto, id, trace);
  }

  async delete(contexto, id, trace = []) {
    trace.push('service');
    const actor = contexto && contexto.actor;

    const usuario = await usuarioRepository.findOne({
      where: this._where(contexto, { id }),
    }, trace);
    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    // Borrarse a uno mismo deja la sesión sin dueño: el token sigue siendo válido
    // pero el usuario ya no existe.
    if (actor && Number(actor.sub) === Number(usuario.id)) {
      throw httpError('No puedes eliminar tu propia cuenta.', 400);
    }

    if (usuario.rolId === (await this._idDeSuperadmin())) {
      throw httpError(
        'No se puede eliminar a un superadmin. Desactívalo con PUT /usuarios/{id}/activo.',
        400
      );
    }

    if (usuario.rolId === (await this._idDeAdmin())) {
      await this._comprobarQuedanAdmins(contexto, trace);
    }

    await usuario.destroy();
    return true;
  }

  /** Activa o desactiva un usuario, sin borrarlo. */
  async cambiarActivo(contexto, id, activo, trace = []) {
    trace.push('service');
    const usuario = await usuarioRepository.findOne({
      where: this._where(contexto, { id }),
    }, trace);
    if (!usuario) {
      throw notFound('Usuario no encontrado.');
    }

    // Desactivar al último admin dejaría la planta sin nadie que la administre.
    if (!activo && usuario.rolId === (await this._idDeAdmin())) {
      await this._comprobarQuedanAdmins(contexto, trace);
    }

    await usuario.update({ activo: Boolean(activo) });
    return this.findById(contexto, id, trace);
  }

  async _idDeSuperadmin() {
    const { Rol } = require('../../entities');
    const { ROLES } = require('../../security/role-permissions.config');
    const rol = await Rol.findOne({ where: { nombre: ROLES.superadmin } });
    return rol ? rol.id : null;
  }

  async _idDeAdmin() {
    const { Rol } = require('../../entities');
    const { ROLES } = require('../../security/role-permissions.config');
    const rol = await Rol.findOne({ where: { nombre: ROLES.admin } });
    return rol ? rol.id : null;
  }

  /** Falla si la planta se quedaría sin ningún admin activo. */
  async _comprobarQuedanAdmins(contexto, trace) {
    const { Rol } = require('../../entities');
    const { ROLES } = require('../../security/role-permissions.config');
    const rolAdmin = await Rol.findOne({ where: { nombre: ROLES.admin } });
    if (!rolAdmin) {
      return;
    }

    // El repositorio base no expone `count`, así que se cuenta sobre el modelo.
    const total = await this.repository.model.count({
      where: { ...this._where(contexto), rolId: rolAdmin.id, activo: true },
    });

    if (total <= 1) {
      throw httpError(
        'La planta quedaría sin ningún administrador activo.',
        400
      );
    }
  }
}

module.exports = new UsuarioService();
module.exports.UsuarioService = UsuarioService;