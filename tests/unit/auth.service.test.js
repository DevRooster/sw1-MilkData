const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const authService = require('../../src/services/impl/auth.service');
const { Usuario } = require('../../src/entities');

jest.mock('../../src/entities', () => ({
  Usuario: {
    findOne: jest.fn(),
    create: jest.fn(),
  },
  Rol: {},
}));

describe('AuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('login exitoso devuelve token y usuario sin password', async () => {
    const usuario = {
      id: 10,
      nombre: 'Ana',
      apellido: 'García',
      email: 'ana@test.com',
      password: await bcrypt.hash('secret123', 10),
      rolId: 2,
      rol: { id: 2, nombre: 'admin' },
      activo: true,
      ultimoAcceso: null,
    };

    Usuario.findOne.mockResolvedValue(usuario);
    const result = await authService.login({ email: 'ana@test.com', password: 'secret123' });

    expect(result.token).toBeTruthy();
    expect(result.user.email).toBe('ana@test.com');
    expect(result.user.password).toBeUndefined();
    expect(jwt.decode(result.token).email).toBe('ana@test.com');
  });

  it('login con credenciales incorrectas lanza error controlado', async () => {
    Usuario.findOne.mockResolvedValue({
      id: 11,
      email: 'bad@test.com',
      password: await bcrypt.hash('correctpass', 10),
      rolId: 1,
      rol: { id: 1, nombre: 'admin' },
    });

    await expect(authService.login({ email: 'bad@test.com', password: 'wrongpass' })).rejects.toMatchObject({ statusCode: 401 });
  });
});
