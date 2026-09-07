const BaseRepository = require('../../src/repositories/base.repository');
const dtoFiles = [
  '../../src/dtos/proveedor.dto',
  '../../src/dtos/entrega.dto',
  '../../src/dtos/calidad.dto',
  '../../src/dtos/notificacion.dto',
  '../../src/dtos/asistencia.dto',
];

describe('DTOs y BaseRepository', () => {
  test('todos los DTOs manejan entidad, relaciones y null', () => {
    const entity = {
      id: 1,
      nombre: 'A',
      apellido: 'B',
      dni: '12345678',
      telefono: '999999999',
      codigo: 'C1',
      zonaId: 1,
      usuarioId: 1,
      proveedorId: 1,
      unidadId: 1,
      entregaId: 1,
      evento: 'evento',
      fecha: '2026-01-01',
      registradoPor: 'manual',
      tipo: 'reunion',
      titulo: 'titulo',
      mensaje: 'mensaje',
      grasa: 3,
      proteina: 3,
      lactosa: 4,
      densidad: 1,
      temperatura: 4,
      aguaAnadida: 0,
      ph: 6,
      resultado: 'pura',
      cantidad: 10,
      hora: '08:00:00',
      registradoEn: 'campo',
      sincronizado: false,
      activo: true,
      leida: false,
      enviada: true,
      fechaEnvio: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      zona: { id: 1, nombre: 'Z', ruta: 'R', horaInicio: '06:00', horaFin: '10:00', unidadId: 1, activo: true },
      usuario: { id: 1, nombre: 'U', apellido: 'S', email: 'u@test.com', rolId: 1, proveedorId: null, activo: true, ultimoAcceso: null },
      proveedor: { id: 1, nombre: 'P', apellido: 'S', dni: '12345678', codigo: 'C1' },
      entrega: { id: 1, proveedorId: 1, fecha: '2026-01-01', cantidad: 10 },
    };
    dtoFiles.forEach((path) => {
      const dto = require(path);
      expect(dto.toDTO(entity)).toBeTruthy();
      expect(dto.toDTO(null)).toBeNull();
    });
  });

  test('BaseRepository cubre CRUD y búsquedas', async () => {
    const record = { update: jest.fn().mockResolvedValue({ id: 1 }), destroy: jest.fn() };
    const model = {
      findAll: jest.fn().mockResolvedValue([record]),
      findByPk: jest.fn().mockResolvedValue(record),
      findOne: jest.fn().mockResolvedValue(record),
      create: jest.fn().mockResolvedValue(record),
    };
    const repository = new BaseRepository(model);
    const trace = [];
    await repository.findAll({}, trace);
    await repository.findById(1);
    await repository.findOne({}, trace);
    await repository.create({}, trace);
    await repository.update(1, {});
    await repository.delete(1);
    await repository.findByField('id', 1);
    await repository.findAllByField('id', 1);
    expect(model.findAll).toHaveBeenCalled();
    expect(record.update).toHaveBeenCalled();
    expect(record.destroy).toHaveBeenCalled();
  });
});
