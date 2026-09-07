const { Usuario, Rol } = require('../../entities');
const { toDTO } = require('../../dtos/auth.dto');
const securityAuthService = require('../../security/auth.service');
const usuarioRepository = require('../../repositories/usuario.repository');

class AuthService {
  async register({ nombre, apellido, email, password, rolId }, trace = []) {
    trace.push('service');
    const existing = await usuarioRepository.findOne({ where: { email } });
    if (existing) {
      const error = new Error('El email ya está registrado.');
      error.statusCode = 409;
      throw error;
    }

    const role = await Rol.findByPk(rolId);
    if (!role) {
      const error = new Error('El rol especificado no existe.');
      error.statusCode = 400;
      throw error;
    }

    const adminRole = await Rol.findOne({ where: { nombre: 'admin' } });
    if (!adminRole) {
      const error = new Error('El rol admin no está configurado.');
      error.statusCode = 400;
      throw error;
    }
    const adminExists = adminRole
      ? await Usuario.findOne({ where: { rolId: adminRole.id } })
      : null;
    if (!adminExists && Number(rolId) !== Number(adminRole.id)) {
      const error = new Error('Debe existir un administrador antes de registrar otros roles.');
      error.statusCode = 400;
      throw error;
    }

    const hashedPassword = await securityAuthService.hashPassword(password);
    const usuario = await usuarioRepository.create({
      nombre,
      apellido,
      email,
      password: hashedPassword,
      rolId,
      activo: true,
    }, trace);

    return toDTO(usuario);
  }

  async login({ email, password }, trace = []) {
    trace.push('service');
    const usuario = await usuarioRepository.findOne({
      where: { email },
      include: [{ association: 'rol' }],
    }, trace);

    if (!usuario) {
      const error = new Error('Credenciales inválidas.');
      error.statusCode = 401;
      throw error;
    }

    const passwordMatches = await securityAuthService.comparePassword(password, usuario.password);
    if (!passwordMatches) {
      const error = new Error('Credenciales inválidas.');
      error.statusCode = 401;
      throw error;
    }

    const payload = { sub: usuario.id, email: usuario.email, rol: usuario.rolId };
    const token = await securityAuthService.signToken(payload);

    return {
      token,
      user: toDTO(usuario),
    };
  }

  async verifyToken(token) {
    if (!token) {
      const error = new Error('Token requerido.');
      error.statusCode = 401;
      throw error;
    }

    try {
      return await securityAuthService.verifyToken(token);
    } catch (error) {
      throw error;
    }
  }

  async refreshToken(token) {
    const payload = await this.verifyToken(token);
    const newToken = await securityAuthService.signToken({ sub: payload.sub, email: payload.email, rol: payload.rol });
    return { token: newToken };
  }

  async logout() {
    return { success: true, message: 'Sesión cerrada correctamente.' };
  }
}

module.exports = new AuthService();
