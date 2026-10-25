const { Op } = require('sequelize');
const BaseService = require('../../src/services/impl/base.service');

const CTX = { plantaId: 7 };

function repositoryMock(registros = [{ id: 1 }]) {
  return {
    registros,
    findAll: jest.fn().mockResolvedValue(registros),
    findAndCountAll: jest.fn().mockResolvedValue({ count: registros.length, rows: registros }),
    findOne: jest.fn().mockResolvedValue(registros[0] || null),
    create: jest.fn().mockImplementation(async (data) => ({ ...data, id: 99 })),
    update: jest.fn().mockResolvedValue(null),
    delete: jest.fn().mockResolvedValue(null),
    findByField: jest.fn().mockResolvedValue(registros[0] || null),
    findAllByField: jest.fn().mockResolvedValue(registros),
  };
}

describe('BaseService: aislamiento por planta', () => {
  let repository;
  let service;

  beforeEach(() => {
    repository = repositoryMock();
    service = new BaseService(repository);
  });

  test('list agrega plantaId al where y pagina', async () => {
    await service.list(CTX, [], { where: { activo: true } });

    expect(repository.findAndCountAll).toHaveBeenCalledWith(
      {
        where: { activo: true, plantaId: 7 },
        limit: 10,
        offset: 0,
      },
      expect.any(Array)
    );
  });

  test('list pagina en la pagina que se le pide', async () => {
    await service.list(CTX, [], { pagina: 3, limite: 25 });

    expect(repository.findAndCountAll).toHaveBeenCalledWith(
      expect.objectContaining({ limit: 25, offset: 50 }),
      expect.any(Array)
    );
  });

  test('list no pisa el where que le pasa quien la llama', async () => {
    // El `where` de `resto` no es un filtro de usuario: son condiciones internas
    // que pone un servicio. Antes de mezclarlo con los filtros declarados se
    // pisaba, y la condicion se perdia sin que nadie se enterara.
    await service.list(CTX, [], { where: { activo: true } });

    expect(repository.findAndCountAll).toHaveBeenCalledWith(
      expect.objectContaining({ where: { activo: true, plantaId: 7 } }),
      expect.any(Array)
    );
  });

  test('list ignora las claves que no son filtros en vez de fallar', async () => {
    // `include`, `order` y `attributes` son opciones de Sequelize, no filtros.
    // Confundirlas con un filtro desconocido hacia fallar a quien las pasa.
    await service.list(CTX, [], { include: [{ association: 'ruta' }] });

    expect(repository.findAndCountAll).toHaveBeenCalledWith(
      expect.objectContaining({ include: [{ association: 'ruta' }] }),
      expect.any(Array)
    );
  });

  test('list devuelve los items y el estado de la paginacion', async () => {
    repository.findAndCountAll.mockResolvedValue({ count: 42, rows: [{ id: 1 }, { id: 2 }] });

    const { items, paginacion } = await service.list(CTX, [], { limite: 10 });

    expect(items).toHaveLength(2);
    expect(paginacion).toEqual({
      pagina: 1,
      limite: 10,
      total: 42,
      totalPaginas: 5,
      tieneAnterior: false,
      tieneSiguiente: true,
    });
  });

  test('findById busca por id Y planta', async () => {
    await service.findById(CTX, 5);

    expect(repository.findOne).toHaveBeenCalledWith(
      { where: { id: 5, plantaId: 7 } },
      expect.any(Array)
    );
  });

  test('un registro de otra planta produce 404', async () => {
    repository.findOne.mockResolvedValue(null);

    await expect(service.findById(CTX, 5)).rejects.toMatchObject({ statusCode: 404 });
  });

  test('create impone el plantaId de la sesión sobre el del cuerpo', async () => {
    await service.create(CTX, { nombre: 'x', plantaId: 999 });

    expect(repository.create).toHaveBeenCalledWith(
      { nombre: 'x', plantaId: 7 },
      expect.any(Array)
    );
  });

  test('update descarta un plantaId enviado por el cliente', async () => {
    const registro = { update: jest.fn().mockResolvedValue({ id: 1 }) };
    repository.findOne.mockResolvedValue(registro);

    await service.update(CTX, 1, { nombre: 'y', plantaId: 999 });

    expect(registro.update).toHaveBeenCalledWith({ nombre: 'y' });
  });

  test('update y delete solo tocan registros de la planta', async () => {
    const registro = { update: jest.fn().mockResolvedValue({ id: 1 }), destroy: jest.fn() };
    repository.findOne.mockResolvedValue(registro);

    await service.update(CTX, 1, { nombre: 'y' });
    await service.delete(CTX, 1);

    for (const llamada of repository.findOne.mock.calls) {
      expect(llamada[0].where.plantaId).toBe(7);
    }
    expect(registro.destroy).toHaveBeenCalled();
  });

  test('delete de otra planta produce 404 y no borra nada', async () => {
    const registro = { destroy: jest.fn() };
    repository.findOne.mockResolvedValue(null);

    await expect(service.delete(CTX, 5)).rejects.toMatchObject({ statusCode: 404 });
    expect(registro.destroy).not.toHaveBeenCalled();
  });

  test('listByField y findOneByField también aíslan', async () => {
    await service.listByField(CTX, 'proveedorId', 3);
    await service.findOneByField(CTX, 'dni', '123', [], { where: { activo: true } });

    expect(repository.findAllByField).toHaveBeenCalledWith(
      'proveedorId', 3, { where: { plantaId: 7 } }
    );
    expect(repository.findByField).toHaveBeenCalledWith(
      'dni', '123', { where: { activo: true, plantaId: 7 } }
    );
  });

  test('sin plantaId en el contexto lanza un error explicito', async () => {
    await expect(service.list({})).rejects.toThrow(/plantaId/i);
    await expect(service.create({}, { nombre: 'x' })).rejects.toThrow(/plantaId/i);
    await expect(service.findById(undefined, 1)).rejects.toThrow(/plantaId/i);
  });
});

describe('BaseService: sin aislamiento', () => {
  test('las tablas globales ignoran el plantaId', async () => {
    const repository = repositoryMock();
    const service = new BaseService(repository, undefined, { aislarPorPlanta: false });

    await service.list({});
    await service.create({}, { nombre: 'x', plantaId: 4 });

    expect(repository.findAndCountAll).toHaveBeenCalledWith(
      { limit: 10, offset: 0 },
      ['service']
    );
    expect(repository.create).toHaveBeenCalledWith({ nombre: 'x', plantaId: 4 }, ['service']);
  });
});

describe('BaseService: filtros', () => {
    /**
     * Un servicio que declara un rango de fechas, como hace `calidad`.
     */
    class ConRango extends BaseService {
      _filtros() {
        return {
          estado: (valor) => ({ estado: valor }),
          desde: (valor) => ({ fecha: { [Op.gte]: valor } }),
          hasta: (valor) => ({ fecha: { [Op.lte]: valor } }),
        };
      }
    }

    test('dos filtros sobre la MISMA columna se acumulan en vez de pisarse', async () => {
      const repository = repositoryMock();
      repository.findAndCountAll.mockResolvedValue({ count: 0, rows: [] });

      const service = new ConRango(repository);
      await service.list(CTX, [], { desde: '2020-01-01', hasta: '2020-12-31' });

      const { where } = repository.findAndCountAll.mock.calls[0][0];

      // Los dos operadoresconviven: `Op.gte` para el desde y `Op.lte` para el
      // hasta.
      //
      // Con `Object.assign` el segundo machacaba al primero y el rango se
      // convertía solo en su mitad `hasta`, sin error: `?desde=2027&hasta=2027`
      // devolvía los registros de cualquier año anterior. Medido contra la API.
      expect(where.fecha[Op.gte]).toBe('2020-01-01');
      expect(where.fecha[Op.lte]).toBe('2020-12-31');
    });

    test('un filtro suelto sigue funcionando', async () => {
      const repository = repositoryMock();
      repository.findAndCountAll.mockResolvedValue({ count: 0, rows: [] });

      const service = new ConRango(repository);
      await service.list(CTX, [], { estado: 'pura' });

      const { where } = repository.findAndCountAll.mock.calls[0][0];
      expect(where.estado).toBe('pura');
      expect(where.fecha).toBeUndefined();
    });

    test('los otros filtros del mismo servicio siguen ahí', async () => {
      const repository = repositoryMock();
      repository.findAndCountAll.mockResolvedValue({ count: 0, rows: [] });

      const service = new ConRango(repository);
      await service.list(CTX, [], { estado: 'pura', desde: '2020-01-01' });

      const { where } = repository.findAndCountAll.mock.calls[0][0];
      expect(where.estado).toBe('pura');
      expect(where.fecha[Op.gte]).toBe('2020-01-01');
    });
  });

  describe('BaseService: DTO por defecto', () => {
  test('convierte instancias de Sequelize con toJSON', async () => {
    const instancia = { id: 1, toJSON: () => ({ id: 1, nombre: 'x' }) };
    const repository = repositoryMock();
    repository.findAndCountAll.mockResolvedValue({ count: 1, rows: [instancia] });
    repository.findOne.mockResolvedValue(instancia);

    const service = new BaseService(repository);
    await expect(service.list(CTX)).resolves.toMatchObject({ items: [{ id: 1, nombre: 'x' }] });
    await expect(service.findById(CTX, 1)).resolves.toEqual({ id: 1, nombre: 'x' });
  });

  test('acepta objetos planos sin toJSON', async () => {
    const repository = repositoryMock();
    repository.findAndCountAll.mockResolvedValue({ count: 1, rows: [{ id: 1, nombre: 'y' }] });

    const service = new BaseService(repository);
    await expect(service.list(CTX)).resolves.toMatchObject({ items: [{ id: 1, nombre: 'y' }] });
  });
});
