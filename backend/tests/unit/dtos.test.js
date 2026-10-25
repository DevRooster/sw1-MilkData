const DTO_MODULES = {
  proveedor: require('../../src/dtos/proveedor.dto'),
  recoleccion: require('../../src/dtos/recoleccion.dto'),
  calidad: require('../../src/dtos/calidad.dto'),
  notificacion: require('../../src/dtos/notificacion.dto'),
  asistencia: require('../../src/dtos/asistencia.dto'),
};

const RELACIONES = {
  zona: { id: 1, nombre: 'Zona', ruta: 'Ruta', horaInicio: '06:00:00', horaFin: '10:00:00', unidadId: 1, activo: true },
  unidad: { id: 1, nombre: 'Furgón 01', tipo: 'furgon', capacidad: 1500 },
  usuario: { id: 1, nombre: 'Ana', apellido: 'García', email: 'ana@test.com', rolId: 1, activo: true, ultimoAcceso: null },
  proveedor: { id: 1, nombre: 'Juan', apellido: 'Pérez', dni: '70000001', codigo: 'PROV-001' },
  recoleccion: { id: 1, proveedorId: 1, fecha: '2026-01-01', cantidad: 10 },
};

const ENTIDAD = {
  id: 1,
  nombre: 'Ana',
  apellido: 'García',
  email: 'ana@test.com',
  rolId: 1,
  dni: '70000001',
  telefono: '999999999',
  codigo: 'PROV-001',
  zonaId: 1,
  unidadId: 1,
  usuarioId: 1,
  proveedorId: 1,
  recoleccionId: 1,
  evento: 'reunión',
  fecha: '2026-01-01',
  registradoPor: 'manual',
  tipo: 'reunion',
  titulo: 'Título',
  mensaje: 'Mensaje',
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
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const ENTIDAD_CON_RELACIONES = { ...ENTIDAD, ...RELACIONES };

describe('DTOs', () => {
  test.each(Object.entries(DTO_MODULES))('%s devuelve null ante entidad nula', (nombre, { toDTO }) => {
    expect(toDTO(null)).toBeNull();
  });

  test.each(Object.entries(DTO_MODULES))('%s proyecta las relaciones cuando vienen cargadas', (nombre, { toDTO }) => {
    const dto = toDTO(ENTIDAD_CON_RELACIONES);
    expect(dto).toBeTruthy();
    expect(dto.id).toBe(1);
    expect(dto.createdAt).toBe(ENTIDAD.createdAt);
  });

  test.each(Object.entries(DTO_MODULES))('%s deja las relaciones en null si no vienen cargadas', (nombre, { toDTO }) => {
    const dto = toDTO(ENTIDAD);
    const relaciones = ['zona', 'unidad', 'usuario', 'proveedor', 'recoleccion', 'rol'];

    for (const relacion of relaciones) {
      if (relacion in dto) {
        expect(dto[relacion]).toBeNull();
      }
    }
  });

  // `direccion` estuvo en la entidad y fuera del DTO. Se podia escribir pero no
  // leer: quien abria a editar un proveedor veia el campo vacio aunque tuviera
  // algo, y al guardar de nuevo lo mandaba vacio. El segundo guardado borraba lo
  // que el primero habia escrito.
  test('proveedor.dto devuelve direccion, o null si no la tiene', () => {
    const { toDTO } = DTO_MODULES.proveedor;

    expect(toDTO({ ...ENTIDAD, direccion: 'Av. Los Alamos 123' }).direccion)
      .toBe('Av. Los Alamos 123');
    expect(toDTO(ENTIDAD).direccion).toBeNull();
  });

  // La direccion no era la unica: este comprueba que el DTO no se queda corto
  // con ninguna columna de la entidad que se pueda escribir.
  test('proveedor.dto trae todas las columnas que se pueden escribir', () => {
    const { toDTO } = DTO_MODULES.proveedor;
    const escribibles = ['nombre', 'apellido', 'dni', 'codigo', 'telefono', 'direccion', 'zonaId'];

    const dto = toDTO(ENTIDAD);

    for (const campo of escribibles) {
      expect(dto).toHaveProperty(campo);
    }
  });

  test('auth.dto nunca expone el password', () => {    const { toDTO } = require('../../src/dtos/auth.dto');
    const dto = toDTO({ ...ENTIDAD, password: 'hash-secreto' });

    expect(dto.password).toBeUndefined();
    expect(dto.email).toBe('ana@test.com');
    expect(dto.rolId).toBe(1);
  });

  test('auth.dto incluye rol y proveedor solo si existen', () => {
    const { toDTO } = require('../../src/dtos/auth.dto');

    expect(toDTO(ENTIDAD).rol).toBeUndefined();
    expect(toDTO(ENTIDAD).proveedor).toBeUndefined();

    const conRelaciones = toDTO({ ...ENTIDAD, rol: { id: 1, nombre: 'admin' }, proveedor: { id: 3 } });
    expect(conRelaciones.rol).toEqual({ id: 1, nombre: 'admin' });
    expect(conRelaciones.proveedor).toEqual({ id: 3 });
  });
});
