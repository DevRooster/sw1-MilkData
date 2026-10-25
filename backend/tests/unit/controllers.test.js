const BaseController = require('../../src/controllers/base.controller');
const { badRequest } = require('../../src/utils/http-error');

function responseMock() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

function reqMock(extra = {}) {
  return { layerTrace: ['routes'], contexto: { plantaId: 7 }, ...extra };
}

/** Controller de pruebas sobre BaseController, con un service simulado. */
function buildController(nombresDeFiltro = []) {
  const controller = new BaseController();
  controller.service = {
    list: jest.fn().mockResolvedValue({
      items: [{ id: 1 }],
      paginacion: { pagina: 1, limite: 10, total: 1, totalPaginas: 1, tieneAnterior: false, tieneSiguiente: false },
    }),
    // El controller consulta esto para rechazar lo que no reconoce. Sin él en
    // el doble, `list` reventaría con un TypeError antes de llegar al service,
    // y la prueba mediría el fallo del doble en vez de lo que quiere medir.
    nombresDeFiltro: jest.fn().mockReturnValue(nombresDeFiltro),
    findById: jest.fn().mockResolvedValue({ id: 1 }),
    create: jest.fn().mockResolvedValue({ id: 1 }),
    update: jest.fn().mockResolvedValue({ id: 1 }),
    delete: jest.fn().mockResolvedValue(true),
    findByProveedor: jest.fn().mockResolvedValue([{ id: 5 }]),
    findByNombre: jest.fn().mockResolvedValue({ id: 6 }),
  };
  controller.filterMethod = 'findByProveedor';
  controller.filterField = 'proveedorId';
  return controller;
}

describe('BaseController', () => {
  let controller;

  beforeEach(() => {
    controller = buildController();
  });

  test('todas las operaciones reciben el contexto de planta', async () => {
    const ctx = { plantaId: 7 };
    const req = reqMock({ params: { id: '1' }, body: { nombre: 'x' }, params2: null });

    await controller.list(req, responseMock(), jest.fn());
    await controller.findById({ ...req, params: { id: '1' } }, responseMock(), jest.fn());
    await controller.create(req, responseMock(), jest.fn());
    await controller.update({ ...req, params: { id: '1' } }, responseMock(), jest.fn());
    await controller.delete({ ...req, params: { id: '1' } }, responseMock(), jest.fn());
    await controller.filter({ ...req, params: { value: '3' } }, responseMock(), jest.fn());

    expect(controller.service.list).toHaveBeenCalledWith(
      ctx, expect.any(Array), { pagina: 1, limite: 10 }
    );
    expect(controller.service.findById).toHaveBeenCalledWith(ctx, '1', expect.any(Array));
    expect(controller.service.create).toHaveBeenCalledWith(ctx, { nombre: 'x' }, expect.any(Array));
    expect(controller.service.update).toHaveBeenCalledWith(ctx, '1', { nombre: 'x' }, expect.any(Array));
    expect(controller.service.delete).toHaveBeenCalledWith(ctx, '1', expect.any(Array));
    expect(controller.service.findByProveedor).toHaveBeenCalledWith(ctx, '3', expect.any(Array));
  });

  test('sin contexto lanza un error, no ejecuta el service', async () => {
    const next = jest.fn();
    await controller.list({ layerTrace: ['routes'] }, responseMock(), next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({
      message: expect.stringMatching(/contexto de planta/i),
    }));
    expect(controller.service.list).not.toHaveBeenCalled();
  });

  test('list responde 200 con items', async () => {
    const res = responseMock();
    await controller.list(reqMock(), res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json.mock.calls[0][0].data.items).toEqual([{ id: 1 }]);
  });

  test('create responde 201', async () => {
    const res = responseMock();
    await controller.create(reqMock({ body: {} }), res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(201);
  });

  test('update y delete usan el mensaje correcto', async () => {
    const resUpdate = responseMock();
    await controller.update(reqMock({ params: { id: '1' } }), resUpdate, jest.fn());
    expect(resUpdate.json.mock.calls[0][0].message).toBe('Registro actualizado');

    const resDelete = responseMock();
    await controller.delete(reqMock({ params: { id: '1' } }), resDelete, jest.fn());
    expect(resDelete.json.mock.calls[0][0].data.deleted).toBe(true);
  });

  test('filter devuelve el filtro aplicado y envuelve en items', async () => {
    const res = responseMock();
    await controller.filter(reqMock({ params: { value: '3' } }), res, jest.fn());

    expect(res.json.mock.calls[0][0].data.filtro).toEqual({ campo: 'proveedorId', valor: '3' });
    expect(res.json.mock.calls[0][0].data.items).toEqual([{ id: 5 }]);
  });

  test('filter con resultado unico lo devuelve en item, no en items', async () => {
    controller.filterMethod = 'findByNombre';
    const res = responseMock();
    await controller.filter(reqMock({ params: { value: 'Queso' } }), res, jest.fn());

    expect(res.json.mock.calls[0][0].data.item).toEqual({ id: 6 });
    expect(res.json.mock.calls[0][0].data.items).toBeUndefined();
  });

  test('filter sin resultado devuelve item null', async () => {
    controller.service.findByProveedor.mockResolvedValue(null);
    const res = responseMock();
    await controller.filter(reqMock({ params: { value: 'x' } }), res, jest.fn());

    expect(res.json.mock.calls[0][0].data.item).toBeNull();
  });

  test('un filtro con varios resultados pagina', async () => {
    controller.service.findByProveedor.mockResolvedValue(
      Array.from({ length: 25 }, (_, i) => ({ id: i + 1 }))
    );

    const res = responseMock();
    await controller.filter(reqMock({ params: { value: '3' }, query: { pagina: '2', limite: '10' } }), res, jest.fn());
    const { items, paginacion } = res.json.mock.calls[0][0].data;

    expect(items).toHaveLength(10);
    expect(items[0].id).toBe(11);
    expect(paginacion).toEqual({
      pagina: 2,
      limite: 10,
      total: 25,
      totalPaginas: 3,
      tieneAnterior: true,
      tieneSiguiente: true,
    });
  });

  test('setImagen envia solo la imagen al service', async () => {
    const res = responseMock();
    await controller.setImagen(
      reqMock({ params: { id: '1' }, body: { imagen: 'https://cdn/x.png' } }),
      res, jest.fn()
    );

    expect(controller.service.update).toHaveBeenCalledWith(
      { plantaId: 7 }, '1', { imagen: 'https://cdn/x.png' }, expect.any(Array)
    );
    expect(res.json.mock.calls[0][0].message).toBe('Imagen actualizada');
  });

  test('setImagen acepta null para borrar', async () => {
    const res = responseMock();
    await controller.setImagen(
      reqMock({ params: { id: '1' }, body: { imagen: null } }),
      res, jest.fn()
    );

    expect(controller.service.update).toHaveBeenCalledWith(
      { plantaId: 7 }, '1', { imagen: null }, expect.any(Array)
    );
  });

  test('setImagen sin el campo imagen responde 400', async () => {
    const next = jest.fn();
    await controller.setImagen(reqMock({ params: { id: '1' }, body: {} }), responseMock(), next);

    expect(next).toHaveBeenCalledWith(badRequest('El campo imagen es obligatorio.'));
  });

  test('los errores del service llegan a next', async () => {
    const next = jest.fn();
    controller.service.list.mockRejectedValue(new Error('falló'));

    await controller.list(reqMock(), responseMock(), next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ message: 'falló' }));
  });

  // El rechazo de filtros desconocidos vive en el controller y no en el
  // servicio a propósito: hay servicios que sobrescriben `list` y nunca
  // pasarían por el filtro de la base. Con el guardián solo en la base,
  // `GET /rutas?busqueda=zzzz` devolvía las seis rutas sin avisar.
  describe('filtros desconocidos', () => {
    test('los rechaza con un 400 que dice qué admite', async () => {
      const next = jest.fn();
      controller = buildController(['busqueda', 'activo']);

      await controller.list(reqMock({ query: { busqueda: 'x', inventado: 'y' } }), responseMock(), next);

      expect(next).toHaveBeenCalledWith(expect.objectContaining({
        statusCode: 400,
        message: expect.stringContaining('inventado'),
      }));
      // Y el mensaje dice qué sí admite, para que quien lo ve sepa qué escribir.
      expect(next.mock.calls[0][0].message).toContain('busqueda');
      expect(next.mock.calls[0][0].message).toContain('activo');
      // Y el service no llega a ejecutarse: no tiene sentido filtrar lo que ya
      // se sabe que es una consulta mal formada.
      expect(controller.service.list).not.toHaveBeenCalled();
    });

    test('deja pasar los que el servicio declara', async () => {
      const res = responseMock();
      controller = buildController(['busqueda', 'activo']);

      await controller.list(reqMock({ query: { busqueda: 'x' } }), res, jest.fn());

      expect(res.status).toHaveBeenCalledWith(200);
      expect(controller.service.list).toHaveBeenCalledWith(
        expect.anything(), expect.any(Array), expect.objectContaining({ busqueda: 'x' })
      );
    });

    test('pagina y limite no cuentan como filtros', async () => {
      const res = responseMock();
      controller = buildController(['busqueda']);

      await controller.list(reqMock({ query: { pagina: '2', limite: '5' } }), res, jest.fn());

      // Si se contaran, `?pagina=2` sería un filtro desconocido y no se podría
      // paginar, que es justo lo que hacen todas las listas.
      expect(res.status).toHaveBeenCalledWith(200);
    });

    test('si el recurso no admite ninguno, lo dice', async () => {
      const next = jest.fn();
      controller = buildController([]);

      await controller.list(reqMock({ query: { cualquiera: 'x' } }), responseMock(), next);

      expect(next.mock.calls[0][0].message).toContain('ninguno');
    });
  });
});

describe('Controllers de recursos', () => {
  const RESOURCES = {
    planta: require('../../src/controllers/planta.controller'),
    proveedor: require('../../src/controllers/proveedor.controller'),
    unidad: require('../../src/controllers/unidad.controller'),
    zona: require('../../src/controllers/zona.controller'),
    recoleccion: require('../../src/controllers/recoleccion.controller'),
    calidad: require('../../src/controllers/calidad.controller'),
    notificacion: require('../../src/controllers/notificacion.controller'),
    producto: require('../../src/controllers/producto.controller'),
    asistencia: require('../../src/controllers/asistencia.controller'),
  };

  test.each(Object.entries(RESOURCES))('%s tiene los handlers CRUD', (nombre, controller) => {
    for (const handler of ['list', 'findById', 'create', 'update', 'delete']) {
      expect(typeof controller[handler]).toBe('function');
    }
  });

  test('los filtros especificos estan expuestos', () => {
    expect(typeof RESOURCES.proveedor.findByDni).toBe('function');
    expect(typeof RESOURCES.proveedor.findByCodigo).toBe('function');
    expect(typeof RESOURCES.proveedor.filterByZona).toBe('function');
    expect(typeof RESOURCES.unidad.filterByTipo).toBe('function');
    expect(typeof RESOURCES.unidad.filterByNombre).toBe('function');
    expect(typeof RESOURCES.zona.filterByNombre).toBe('function');
    expect(typeof RESOURCES.zona.filterByUnidad).toBe('function');
    expect(typeof RESOURCES.recoleccion.filterByProveedor).toBe('function');
    expect(typeof RESOURCES.recoleccion.filterByZona).toBe('function');
    expect(typeof RESOURCES.recoleccion.filterByFecha).toBe('function');
    expect(typeof RESOURCES.calidad.filterByRecoleccion).toBe('function');
    expect(typeof RESOURCES.notificacion.filterByProveedor).toBe('function');
    expect(typeof RESOURCES.notificacion.filterByTipo).toBe('function');
    expect(typeof RESOURCES.asistencia.filterByProveedor).toBe('function');
    expect(typeof RESOURCES.asistencia.filterByEvento).toBe('function');
    expect(typeof RESOURCES.producto.findByNombre).toBe('function');
  });

  test('setImagen viene de BaseController y solo se enruta donde aplica', () => {
    expect(typeof RESOURCES.proveedor.setImagen).toBe('function');
    expect(typeof RESOURCES.producto.setImagen).toBe('function');

    const rutasConImagen = ['proveedor.routes', 'producto.routes'];
    for (const recurso of ['recoleccion', 'calidad', 'asistencia', 'notificacion', 'unidad', 'zona', 'planta']) {
      const rutas = require(`../../src/routes/${recurso}.routes`);
      const rutasMontadas = rutas.stack.map((capa) => capa.route && capa.route.path);
      expect(rutasMontadas.some((p) => String(p).includes('imagen'))).toBe(
        rutasConImagen.includes(`${recurso}.routes`)
      );
    }
  });
});
