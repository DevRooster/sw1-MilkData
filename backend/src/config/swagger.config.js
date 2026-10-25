const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');

const RESPONSE_STANDARD = { $ref: '#/components/schemas/StandardResponse' };

function jsonResponse(description, code = 200) {
  return {
    description,
    content: { 'application/json': { schema: RESPONSE_STANDARD } },
  };
}

function authResponse(description, code) {
  return {
    [code]: jsonResponse(description, code),
    400: jsonResponse('Datos inválidos o referencia inexistente', 400),
    401: jsonResponse('Token ausente, expirado o inválido', 401),
    403: jsonResponse('El rol no tiene permiso sobre este recurso', 403),
    404: jsonResponse('Recurso no encontrado', 404),
  };
}

const schemas = {
  StandardResponse: {
    type: 'object',
    properties: {
      success: { type: 'boolean' },
      data: { type: 'object', nullable: true },
      message: { type: 'string' },
      errors: { type: 'array', items: { type: 'string' } },
    },
    required: ['success', 'data', 'message', 'errors'],
  },
  LoginRequest: {
    type: 'object',
    required: ['email', 'password'],
    properties: {
      email: { type: 'string', format: 'email', example: 'admin@milkdata.com' },
      // La cuenta de arranque es el superadmin; la clave va en `Superadmin123!`.
      password: { type: 'string', format: 'password', example: 'Superadmin123!' },
    },
  },
  RegisterRequest: {
    type: 'object',
    required: ['nombre', 'apellido', 'email', 'password', 'rolId', 'plantaId'],
    properties: {
      nombre: { type: 'string', example: 'Ana' },
      apellido: { type: 'string', example: 'García' },
      email: { type: 'string', format: 'email', example: 'ana@milkdata.com' },
      password: { type: 'string', format: 'password', example: 'Admin123!' },
      // 1 = superadmin (solo un superadmin puede asignarlo), 2 = admin,
      // 3 = supervisor, 4 = acopiador, 5 = operador, 6 = laboratorio,
      // 7 = proveedor.
      rolId: { type: 'integer', example: 4 },
      // En qué planta queda el usuario. No es opcional: el registro nunca
      // adivina la planta, la indica quien llama. Un admin solo puede registrar
      // dentro de la suya; un superadmin, en cualquiera.
      plantaId: { type: 'integer', example: 1 },
      imagen: { type: 'string', nullable: true, description: 'URL de la foto de perfil' },
    },
  },
  ProveedorRequest: {
    type: 'object',
    required: ['nombre', 'apellido', 'dni', 'codigo'],
    properties: {
      nombre: { type: 'string', example: 'Ana' },
      apellido: { type: 'string', example: 'García' },
      dni: { type: 'string', example: '12345678' },
      telefono: { type: 'string', example: '999999999' },
      codigo: { type: 'string', example: 'PROV-001' },
      zonaId: { type: 'integer', nullable: true },
      usuarioId: { type: 'integer', nullable: true },
      imagen: { type: 'string', nullable: true, description: 'URL de la foto del proveedor' },
    },
  },
  UnidadRequest: {
    type: 'object',
    required: ['nombre', 'tipo'],
    properties: {
      nombre: { type: 'string' },
      tipo: { type: 'string', enum: ['furgon', 'motocarga'] },
      capacidad: { type: 'number' },
      cerrado: { type: 'boolean' },
      activo: { type: 'boolean' },
    },
  },
  ZonaRequest: {
    type: 'object',
    required: ['nombre'],
    properties: {
      nombre: { type: 'string' },
      rutaId: {
        type: 'integer',
        description: 'Ruta a la que pertenece la zona. Antes era el texto `ruta`.',
      },
      horaInicio: { type: 'string', example: '06:00:00' },
      horaFin: { type: 'string', example: '10:00:00' },
      unidadId: { type: 'integer' },
      activo: { type: 'boolean' },
    },
  },
  RutaRequest: {
    type: 'object',
    required: ['nombre', 'codigo'],
    properties: {
      nombre: { type: 'string', maxLength: 120 },
      codigo: { type: 'string', maxLength: 20, description: 'Único dentro de la planta' },
      descripcion: { type: 'string' },
      horaInicio: { type: 'string', example: '06:00:00' },
      horaFin: { type: 'string', example: '11:00:00' },
      activa: { type: 'boolean' },
    },
  },
  ParadaRequest: {
    type: 'object',
    required: ['proveedorId'],
    properties: {
      proveedorId: { type: 'integer' },
      orden: { type: 'integer', description: 'Si no se envía, va al final de la ruta' },
      horaEstimada: { type: 'string', example: '06:30:00' },
    },
  },
  RecorridoRequest: {
    type: 'object',
    required: ['rutaId', 'unidadId'],
    description:
      'El recorrido nace PLANIFICADO. No copia las paradas ni arranca la recolección: eso pasa al marcar EN RUTA.',
    properties: {
      rutaId: { type: 'integer' },
      unidadId: { type: 'integer' },
      acopiadorId: {
        type: 'integer',
        description: 'Quien conduce. Por defecto, el usuario autenticado.',
      },
      ayudanteUsuarioId: {
        type: 'integer',
        description: 'Ayudante interno: usuario de la misma planta. Excluye los campos de abajo.',
      },
      ayudanteNombre: { type: 'string', description: 'Ayudante externo' },
      ayudanteApellido: { type: 'string' },
      ayudanteDni: { type: 'string', description: 'Obligatorio si el ayudante es externo' },
      ayudanteCelular: { type: 'string' },
      fecha: { type: 'string', format: 'date', description: 'Por defecto, hoy' },
      observaciones: { type: 'string' },
    },
  },
  IniciarRecorridoRequest: {
    type: 'object',
    properties: {
      kilometrajeInicio: { type: 'number' },
    },
  },
  FinalizarRecorridoRequest: {
    type: 'object',
    properties: {
      kilometrajeFin: { type: 'number' },
      observaciones: { type: 'string' },
    },
  },
  AtenderParadaRequest: {
    type: 'object',
    properties: {
      estado: { type: 'string', enum: ['ATENDIDA', 'OMITIDA'], description: 'Por defecto ATENDIDA' },
      litros: { type: 'number' },
      horaLlegada: { type: 'string', example: '07:12:00' },
      horaSalida: { type: 'string', example: '07:25:00' },
      observaciones: { type: 'string' },
    },
  },
  RecolectarRequest: {
    type: 'object',
    required: ['cantidad'],
    properties: {
      cantidad: { type: 'number', description: 'Litros recogidos' },
      temperatura: { type: 'number' },
      zonaId: { type: 'integer', description: 'Por defecto, la zona del proveedor' },
      hora: { type: 'string' },
    },
  },
  OrdenParadasRequest: {
    type: 'object',
    required: ['ordenes'],
    properties: {
      ordenes: {
        type: 'array',
        items: {
          type: 'object',
          required: ['idParada', 'orden'],
          properties: {
            idParada: { type: 'integer' },
            orden: { type: 'integer' },
          },
        },
      },
    },
  },
  RecoleccionRequest: {
    type: 'object',
    required: ['proveedorId', 'zonaId', 'unidadId', 'usuarioId', 'cantidad', 'fecha', 'registradoEn'],
    properties: {
      proveedorId: { type: 'integer' },
      zonaId: { type: 'integer' },
      unidadId: { type: 'integer' },
      usuarioId: { type: 'integer' },
      cantidad: { type: 'number' },
      fecha: { type: 'string', format: 'date' },
      hora: { type: 'string' },
      temperatura: { type: 'number' },
      registradoEn: { type: 'string', enum: ['campo', 'planta'] },
      sincronizado: { type: 'boolean' },
    },
  },
  CalidadRequest: {
    type: 'object',
    required: ['recoleccionId', 'usuarioId'],
    properties: {
      recoleccionId: { type: 'integer' },
      usuarioId: { type: 'integer' },
      grasa: { type: 'number' },
      proteina: { type: 'number' },
      lactosa: { type: 'number' },
      densidad: { type: 'number' },
      temperatura: { type: 'number' },
      aguaAnadida: { type: 'number' },
      ph: { type: 'number' },
      resultado: { type: 'string', enum: ['pura', 'adulterada'] },
    },
  },
  PerfilRequest: {
    type: 'object',
    properties: {
      nombre: { type: 'string', example: 'Ana' },
      apellido: { type: 'string', example: 'García' },
      imagen: { type: 'string', nullable: true, description: 'URL de la foto de perfil' },
    },
  },
  ImagenRequest: {
    type: 'object',
    required: ['imagen'],
    properties: {
      imagen: {
        type: 'string',
        nullable: true,
        example: 'https://cdn.milkdata.com/productos/queso.png',
        description: 'URL de la imagen. `null` la elimina.',
      },
    },
  },
  PlantaRequest: {
    type: 'object',
    required: ['nombre', 'codigo'],
    properties: {
      nombre: { type: 'string', example: 'Planta Ecológica Huata' },
      codigo: { type: 'string', example: 'HUA' },
      direccion: { type: 'string', nullable: true },
      imagen: { type: 'string', nullable: true },
      activo: { type: 'boolean' },
    },
  },
  ProductoRequest: {
    type: 'object',
    required: ['nombre', 'precioVenta'],
    properties: {
      nombre: { type: 'string', example: 'Queso fresco' },
      descripcion: { type: 'string' },
      unidadMedida: { type: 'string', example: 'kg' },
      precioVenta: { type: 'number', example: 18.5 },
      imagen: { type: 'string', nullable: true, description: 'URL de la imagen del producto' },
      estado: { type: 'boolean' },
    },
  },
  NotificacionRequest: {
    type: 'object',
    required: ['tipo', 'titulo', 'mensaje'],
    properties: {
      proveedorId: { type: 'integer' },
      usuarioId: { type: 'integer' },
      tipo: { type: 'string', enum: ['adulteracion', 'reunion', 'capacitacion'] },
      titulo: { type: 'string' },
      mensaje: { type: 'string' },
      leida: { type: 'boolean' },
      enviada: { type: 'boolean' },
    },
  },
  AsistenciaRequest: {
    type: 'object',
    required: ['proveedorId', 'usuarioId', 'evento', 'fecha', 'registradoPor'],
    properties: {
      proveedorId: { type: 'integer' },
      usuarioId: { type: 'integer' },
      evento: { type: 'string' },
      fecha: { type: 'string', format: 'date' },
      registradoPor: { type: 'string', enum: ['QR', 'manual'] },
    },
  },
};

const RECURSOS = [
  {
    path: 'proveedores',
    schema: 'ProveedorRequest',
    filtros: [
      { ruta: 'dni/{dni}', param: 'dni', type: 'string', descripcion: 'Buscar proveedor por DNI' },
      { ruta: 'zona/{zonaId}', param: 'zonaId', type: 'integer', descripcion: 'Listar proveedores de una zona' },
    ],
    imagen: true,
  },
  {
    path: 'unidades',
    schema: 'UnidadRequest',
    filtros: [
      { ruta: 'tipo/{tipo}', param: 'tipo', type: 'string', descripcion: 'Listar unidades por tipo' },
    ],
  },
  {
    path: 'zonas',
    schema: 'ZonaRequest',
    filtros: [
      { ruta: 'nombre/{nombre}', param: 'nombre', type: 'string', descripcion: 'Buscar zona por nombre' },
      { ruta: 'unidad/{unidadId}', param: 'unidadId', type: 'integer', descripcion: 'Listar zonas de una unidad' },
    ],
  },
  {
    path: 'recolecciones',
    schema: 'RecoleccionRequest',
    filtros: [
      { ruta: 'proveedor/{proveedorId}', param: 'proveedorId', type: 'integer', descripcion: 'Listar recolecciones de un proveedor' },
      { ruta: 'zona/{zonaId}', param: 'zonaId', type: 'integer', descripcion: 'Listar recolecciones de una zona' },
      { ruta: 'fecha/{fecha}', param: 'fecha', type: 'string', descripcion: 'Listar recolecciones de una fecha' },
    ],
  },
  {
    path: 'calidad',
    schema: 'CalidadRequest',
    filtros: [
      { ruta: 'recoleccion/{recoleccionId}', param: 'recoleccionId', type: 'integer', descripcion: 'Control de calidad de una recolección' },
    ],
  },
  {
    path: 'notificaciones',
    schema: 'NotificacionRequest',
    filtros: [
      { ruta: 'proveedor/{proveedorId}', param: 'proveedorId', type: 'integer', descripcion: 'Listar notificaciones de un proveedor' },
      { ruta: 'tipo/{tipo}', param: 'tipo', type: 'string', descripcion: 'Listar notificaciones por tipo' },
    ],
  },
  {
    path: 'productos',
    schema: 'ProductoRequest',
    filtros: [
      { ruta: 'nombre/{nombre}', param: 'nombre', type: 'string', descripcion: 'Buscar producto por nombre' },
    ],
    imagen: true,
  },
  {
    path: 'asistencias',
    schema: 'AsistenciaRequest',
    filtros: [
      { ruta: 'proveedor/{proveedorId}', param: 'proveedorId', type: 'integer', descripcion: 'Listar asistencias de un proveedor' },
      { ruta: 'evento/{evento}', param: 'evento', type: 'string', descripcion: 'Listar asistencias por evento' },
    ],
  },
  {
    path: 'rutas',
    schema: 'RutaRequest',
    filtros: [
      { ruta: 'codigo/{codigo}', param: 'codigo', type: 'string', descripcion: 'Buscar ruta por código' },
    ],
    extras: {
      '/proveedores/{proveedorId}/sugerencia': ['get'],
      '/{id}/recomendada': ['get'],
      '/{id}/paradas': ['post'],
      '/{id}/paradas/orden': ['put'],
      '/{id}/paradas/{paradaId}': ['delete'],
    },
  },
  {
    path: 'recorridos',
    schema: 'RecorridoRequest',
    filtros: [],
    extras: {
      // Va antes que /{id} en el enrutado, por eso no es un filtro más.
      '/actual': ['get'],
      '/{id}/iniciar': ['post'],
      '/{id}/finalizar': ['post'],
      '/{id}/cancelar': ['post'],
      '/{id}/paradas/{paradaId}/atender': ['post'],
      '/{id}/paradas/{paradaId}/recolectar': ['post'],
    },
  },
];

function idParameter() {
  return { name: 'id', in: 'path', required: true, schema: { type: 'integer' } };
}

function filtroParameter(filtro) {
  return { name: filtro.param, in: 'path', required: true, schema: { type: filtro.type } };
}

function requestBody(schema) {
  return {
    required: true,
    content: { 'application/json': { schema: { $ref: `#/components/schemas/${schema}` } } },
  };
}

function crudPaths({ path: base, schema, filtros, imagen = false, extras = {} }) {
  const security = [{ bearerAuth: [] }];
  const paths = {};

  paths[`/${base}`] = {
    get: {
      tags: [base],
      summary: `Listar ${base}`,
      description: `Paginado. \`?pagina=1&limite=10\`, con un máximo de 200 por página. La respuesta trae \`data.items\` y \`data.paginacion\`.`,
      security,
      parameters: [
        { name: 'pagina', in: 'query', schema: { type: 'integer', minimum: 1, default: 1 } },
        { name: 'limite', in: 'query', schema: { type: 'integer', minimum: 1, maximum: 200, default: 10 } },
      ],
      responses: authResponse('Consulta exitosa', 200),
    },
    post: {
      tags: [base],
      summary: `Crear ${base}`,
      security,
      requestBody: requestBody(schema),
      responses: authResponse('Registro creado', 201),
    },
  };

  if (imagen) {
    paths[`/${base}/{id}/imagen`] = {
      put: {
        tags: [base],
        summary: `Asignar la imagen de ${base}`,
        description: 'Recibe la URL de la imagen ya subida a un almacenamiento externo. Enviar `null` la quita.',
        security,
        parameters: [idParameter()],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/ImagenRequest' } } },
        },
        responses: authResponse('Imagen actualizada', 200),
      },
    };
  }

  paths[`/${base}/{id}`] = {
    get: {
      tags: [base],
      summary: `Obtener ${base} por ID`,
      security,
      parameters: [idParameter()],
      responses: authResponse('Consulta exitosa', 200),
    },
    put: {
      tags: [base],
      summary: `Actualizar ${base}`,
      security,
      parameters: [idParameter()],
      requestBody: requestBody(schema),
      responses: authResponse('Registro actualizado', 200),
    },
    delete: {
      tags: [base],
      summary: `Eliminar ${base}`,
      security,
      parameters: [idParameter()],
      responses: authResponse('Registro eliminado', 200),
    },
  };

  for (const filtro of filtros) {
    if (!filtro.param) {
      continue;
    }
    paths[`/${base}/${filtro.ruta}`] = {
      get: {
        tags: [base],
        summary: filtro.descripcion,
        security,
        parameters: [filtroParameter(filtro)],
        responses: authResponse('Consulta exitosa', 200),
      },
    };
  }

  // Endpoints propios del recurso, que no encajan en el CRUD ni en un filtro.
  for (const [sufijo, metodos] of Object.entries(extras)) {
    const ruta = `/${base}${sufijo}`;
    const parametros = [...sufijo.matchAll(/\{(\w+)\}/g)].map((m) => ({
      name: m[1],
      in: 'path',
      required: true,
      schema: { type: /Id$/.test(m[1]) ? 'integer' : 'string' },
    }));
    const esquemaBody = ESQUEMA_DE_ENDPOINT[ruta];

    paths[ruta] = paths[ruta] || {};
    for (const metodo of metodos) {
      const resumen = RESUMEN_POR_RUTA[ruta] || `${metodo.toUpperCase()} ${ruta}`;
      paths[ruta][metodo] = {
        tags: [base],
        summary: resumen,
        security,
        parameters: parametros,
        ...(esquemaBody ? { requestBody: requestBody(esquemaBody) } : {}),
        responses: authResponse(resumen, metodo === 'post' ? 201 : 200),
      };
    }
  }

  return paths;
}

/** Textos de los endpoints propios, que si no quedarían como la ruta en crudo. */
const RESUMEN_POR_RUTA = {
  '/rutas/proveedores/{proveedorId}/sugerencia':
    'Sugerir la ruta de un proveedor que todavía no tiene una',
  '/rutas/{id}/recomendada':
    'Ruta recomendada: paradas en orden con el estado de cada una en el recorrido',
  '/rutas/{id}/paradas': 'Agregar un proveedor a la ruta',
  '/rutas/{id}/paradas/orden': 'Reordenar las paradas de la ruta',
  '/rutas/{id}/paradas/{paradaId}': 'Quitar una parada de la ruta',
  '/recorridos/actual': 'Recorrido EN RUTA del acopiador autenticado',
  '/recorridos/{id}/iniciar':
    'Marcar EN RUTA: sella las paradas y arranca la recolección',
  '/recorridos/{id}/finalizar':
    'Finalizar el recorrido: las paradas pendientes pasan a OMITIDA',
  '/recorridos/{id}/cancelar': 'Cancelar un recorrido que no llegó a arrancar',
  '/recorridos/{id}/paradas/{paradaId}/atender':
    'Registrar la parada como ATENDIDA u OMITIDA',
  '/recorridos/{id}/paradas/{paradaId}/recolectar':
    'Registrar la recolección de la parada, enlazada al recorrido',
};

/** Esquema del body de cada endpoint propio. */
const ESQUEMA_DE_ENDPOINT = {
  '/rutas/{id}/paradas': 'ParadaRequest',
  '/rutas/{id}/paradas/orden': 'OrdenParadasRequest',
  '/recorridos/{id}/iniciar': 'IniciarRecorridoRequest',
  '/recorridos/{id}/finalizar': 'FinalizarRecorridoRequest',
  '/recorridos/{id}/paradas/{paradaId}/atender': 'AtenderParadaRequest',
  '/recorridos/{id}/paradas/{paradaId}/recolectar': 'RecolectarRequest',
};

const paths = {
  '/auth/register': {
    post: {
      tags: ['Auth'],
      summary: 'Registrar usuario',
      description:
        'Durante el bootstrap, cuando aún no existe ningún usuario admin, solo se permite crear el primer admin sin token. Después, la ruta exige un JWT con rol admin.',
      requestBody: requestBody('RegisterRequest'),
      responses: {
        201: jsonResponse('Usuario creado sin exponer password', 201),
        400: jsonResponse('Payload inválido o rol inexistente', 400),
        401: jsonResponse('Token requerido después del bootstrap', 401),
        403: jsonResponse('El token no pertenece a un admin', 403),
        409: jsonResponse('El email ya está registrado', 409),
      },
    },
  },
  '/auth/login': {
    post: {
      tags: ['Auth'],
      summary: 'Autenticar usuario',
      requestBody: requestBody('LoginRequest'),
      responses: {
        200: jsonResponse('Login exitoso', 200),
        401: jsonResponse('Credenciales inválidas', 401),
        429: jsonResponse('Demasiadas peticiones', 429),
      },
    },
  },
  '/auth/verify': {
    post: {
      tags: ['Auth'],
      summary: 'Verificar JWT',
      security: [{ bearerAuth: [] }],
      responses: {
        200: jsonResponse('Token válido', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
      },
    },
  },
  '/auth/refresh': {
    post: {
      tags: ['Auth'],
      summary: 'Renovar JWT',
      security: [{ bearerAuth: [] }],
      responses: {
        200: jsonResponse('Token renovado', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
      },
    },
  },
  '/auth/logout': {
    post: {
      tags: ['Auth'],
      summary: 'Cerrar sesión',
      description: 'El JWT es stateless, por lo que el cierre es del lado del cliente.',
      security: [{ bearerAuth: [] }],
      responses: {
        200: jsonResponse('Sesión cerrada', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
      },
    },
  },
  '/reportes/contraste': {
    get: {
      tags: ['Reportes'],
      summary: 'Contraste de cantidades campo vs planta',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Reporte generado', 200),
    },
  },
  '/reportes/calidad': {
    get: {
      tags: ['Reportes'],
      summary: 'Promedios de calidad globales',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Reporte generado', 200),
    },
  },
  '/reportes/calidad-proveedor': {
    get: {
      tags: ['Reportes'],
      summary: 'Promedios de calidad agrupados por proveedor',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Reporte generado', 200),
    },
  },
  '/reportes/calidad/proveedor/{proveedorId}': {
    get: {
      tags: ['Reportes'],
      summary: 'Promedios de calidad de un proveedor',
      security: [{ bearerAuth: [] }],
      parameters: [{ name: 'proveedorId', in: 'path', required: true, schema: { type: 'integer' } }],
      responses: authResponse('Reporte generado', 200),
    },
  },
  '/notificaciones/enviar': {
    post: {
      tags: ['Notificaciones'],
      summary: 'Enviar notificación con retry y circuit breaker',
      security: [{ bearerAuth: [] }],
      requestBody: requestBody('NotificacionRequest'),
      responses: {
        201: jsonResponse('Notificación enviada y persistida', 201),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('El rol no tiene permiso de escritura', 403),
        400: jsonResponse('Datos inválidos', 400),
        502: jsonResponse('Servicio externo no disponible (circuito abierto)', 502),
      },
    },
  },
  '/auth/perfil': {
    get: {
      tags: ['Auth'],
      summary: 'Obtener el perfil del usuario autenticado',
      security: [{ bearerAuth: [] }],
      responses: {
        200: jsonResponse('Perfil del usuario autenticado', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
      },
    },
    put: {
      tags: ['Auth'],
      summary: 'Actualizar el perfil del usuario autenticado',
      description: 'Permite cambiar nombre, apellido, telefono, ultimoAcceso e imagen. No cambia email, password ni rol.',
      security: [{ bearerAuth: [] }],
      requestBody: {
        required: true,
        content: { 'application/json': { schema: { $ref: '#/components/schemas/PerfilRequest' } } },
      },
      responses: {
        200: jsonResponse('Perfil actualizado', 200),
        400: jsonResponse('Datos inválidos', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        404: jsonResponse('Usuario no encontrado', 404),
      },
    },
  },
  '/uploads/api': {
    get: {
      tags: ['Imágenes'],
      summary: 'Configuración de imágenes',
      description:
        'Devuelve la carpeta, la URL base, los tipos y tamaños aceptados y el patrón de nombres. Sirve para que el cliente valide antes de subir.',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Consulta exitosa', 200),
    },
    post: {
      tags: ['Imágenes'],
      summary: 'Subir una imagen',
      description:
        'multipart/form-data. Campos: `archivo` (binario, obligatorio), `recurso` (planta|usuario|proveedor|producto) y `id` opcional.\n\n'
        + 'El archivo se guarda en `uploads/<plantaId>/<recurso>/<uuid>.<ext>` dentro de la raíz del proyecto y la columna `imagen` guarda la ruta `/uploads/...`, que se sirve desde el mismo origen.\n\n'
        + 'Con `id` la operación es atómica: guarda el archivo y actualiza el registro. Si el registro no existe o es de otra planta, responde 404 y no queda el archivo en disco.',
      security: [{ bearerAuth: [] }],
      requestBody: {
        required: true,
        content: {
          'multipart/form-data': {
            schema: {
              type: 'object',
              required: ['archivo', 'recurso'],
              properties: {
                archivo: { type: 'string', format: 'binary' },
                recurso: { type: 'string', enum: ['planta', 'usuario', 'proveedor', 'producto'] },
                id: { type: 'integer', description: 'Registro al que se adjunta la imagen' },
              },
            },
          },
        },
      },
      responses: {
        200: jsonResponse('Imagen adjunta al registro', 200),
        201: jsonResponse('Imagen almacenada', 201),
        400: jsonResponse('Falta el archivo, el tipo no se permite o el recurso no existe', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        404: jsonResponse('El registro no existe en la planta', 404),
      },
    },
    delete: {
      tags: ['Imágenes'],
      summary: 'Borrar una imagen',
      description:
        'Body: `{ imagen, recurso?, id? }`. Con `recurso` e `id` desvincula la imagen del registro antes de borrar el archivo.\n\n'
        + 'Solo borra archivos que la propia API almacenó: una URL externa se rechaza con 400.',
      security: [{ bearerAuth: [] }],
      requestBody: {
        required: true,
        content: { 'application/json': { schema: { $ref: '#/components/schemas/ImagenRequest' } } },
      },
      responses: {
        200: jsonResponse('Imagen eliminada', 200),
        400: jsonResponse('Falta la imagen o no la gestionó la API', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('Sin permiso de escritura', 403),
      },
    },
  },
  '/uploads/api/{recurso}/{id}': {
    get: {
      tags: ['Imágenes'],
      summary: 'Listar las imágenes de un registro',
      description:
        'Devuelve la galería completa, con la principal primero.\n\n'
        + 'La columna `imagen` de cada registro sigue siendo la principal: es un dato desnormalizado a propósito, para que las listas no tengan que consultar esta tabla. '
        + 'Esta tabla es la que permite tener más de una imagen por registro.',
      security: [{ bearerAuth: [] }],
      parameters: [
        { name: 'recurso', in: 'path', required: true, schema: { type: 'string', enum: ['planta', 'usuario', 'proveedor', 'producto'] } },
        { name: 'id', in: 'path', required: true, schema: { type: 'integer' } },
      ],
      responses: {
        200: jsonResponse('Imágenes del registro', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        404: jsonResponse('El registro no existe en la planta', 404),
      },
    },
    post: {
      tags: ['Imágenes'],
      summary: 'Añadir una imagen a la galería de un registro',
      description:
        'multipart/form-data con `archivo` (binario, obligatorio).\n\n'
        + 'La primera imagen que llega es la principal. Las siguientes se agregan al final y no la quitan del sitio, '
        + 'para que subir una foto nueva no robe el lugar a la que ya estaba; para cambiar cuál es la principal hay '
        + 'que usar `PUT /uploads/api/imagen/{id}/principal`.\n\n'
        + 'La operación es atómica: si el registro no existe o es de otra planta, se responde 404 y el archivo no queda en disco.',
      security: [{ bearerAuth: [] }],
      parameters: [
        { name: 'recurso', in: 'path', required: true, schema: { type: 'string', enum: ['planta', 'usuario', 'proveedor', 'producto'] } },
        { name: 'id', in: 'path', required: true, schema: { type: 'integer' } },
      ],
      requestBody: {
        required: true,
        content: {
          'multipart/form-data': {
            schema: {
              type: 'object',
              required: ['archivo'],
              properties: { archivo: { type: 'string', format: 'binary' } },
            },
          },
        },
      },
      responses: {
        201: jsonResponse('Imagen agregada', 201),
        400: jsonResponse('Falta el archivo, el tipo no se permite o se alcanzó el máximo', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        404: jsonResponse('El registro no existe en la planta', 404),
      },
    },
  },
  '/uploads/api/imagen/{id}': {
    delete: {
      tags: ['Imágenes'],
      summary: 'Quitar una imagen de la galería',
      description:
        'Quita la imagen del registro y borra el archivo.\n\n'
        + 'Si era la principal, la siguiente pasa a serlo: el registro nunca queda apuntando a un archivo que ya no existe.',
      security: [{ bearerAuth: [] }],
      parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'integer' } }],
      responses: {
        200: jsonResponse('Imagen quitada', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('Sin permiso de escritura', 403),
        404: jsonResponse('La imagen no existe en la planta', 404),
      },
    },
  },
  '/uploads/api/imagen/{id}/principal': {
    put: {
      tags: ['Imágenes'],
      summary: 'Cambiar la imagen principal',
      description:
        'Marca esta imagen como la principal del registro y actualiza la columna `imagen` para que las listas la muestren.\n\n'
        + 'Solo una imagen por registro puede ser la principal: al marcar una, se le quita la marca a la que lo era.',
      security: [{ bearerAuth: [] }],
      parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'integer' } }],
      // Este PUT no recibe datos: la imagen a promover va en la ruta. El cuerpo
      // vacío se declara igual, y no por cuadrar con una regla, sino para que
      // quien genere un cliente desde este documento sepa que no tiene que
      // inventar un payload que la API no lee.
      requestBody: {
        required: false,
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: {},
              description: 'Sin datos: basta con el id de la imagen en la ruta.',
            },
          },
        },
      },
      responses: {
        200: jsonResponse('Imagen principal actualizada', 200),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('Sin permiso de escritura', 403),
        404: jsonResponse('La imagen no existe en la planta', 404),
      },
    },
  },
  '/auth/plantas': {
    get: {
      tags: ['Auth'],
      summary: 'Plantas que puedo supervisar',
      description:
        'Devuelve las plantas disponibles y cuántas son.\n\n'
        + 'El superadmin las ve todas (`alcance: TODAS`) y es el que puede revisar o escribir en cualquiera. '
        + 'Cualquier otro rol solo ve la suya (`alcance: PROPIA`), porque es la única sobre la que tiene alcance.',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Consulta exitosa', 200),
    },
  },
  '/auth/permisos': {
    get: {
      tags: ['Auth'],
      summary: 'Recursos que puedo usar con este token',
      description:
        'Qué recursos puede leer y escribir el token actual, y con qué operaciones.\n\n'
        + 'Devuelve la misma matriz que aplica `authorizeMiddleware` en el resto de endpoints, no una copia: '
        + 'así el menú del móvil se dibuja con lo que la API va a responderle. Si aquí aparece un recurso, aparece; '
        + 'si no aparece, es porque la API lo rechazaría con 403.\n\n'
        + 'Un recurso sin ningún permiso no viene en la lista, en vez de venir con las operaciones vacías.',
      security: [{ bearerAuth: [] }],
      responses: {
        200: {
          description: 'Permisos obtenidos',
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  rol: { type: 'string', example: 'supervisor' },
                  superadmin: { type: 'boolean', example: false },
                  multiplanta: { type: 'boolean', example: false },
                  plantaId: { type: 'integer', example: 1 },
                  recursos: {
                    type: 'object',
                    description: 'Clave: nombre del recurso. Valor: operaciones permitidas.',
                    additionalProperties: {
                      type: 'array',
                      items: { type: 'string', enum: ['read', 'write'] },
                    },
                    example: {
                      proveedores: ['read', 'write'],
                      rutas: ['read', 'write'],
                      usuarios: ['read', 'write'],
                    },
                  },
                },
              },
            },
          },
        },
        401: jsonResponse('Token ausente, expirado o inválido', 401),
      },
    },
  },
  '/auth/planta': {
    post: {
      tags: ['Auth'],
      summary: 'Cambiar de planta (solo superadmin)',
      description:
        'Devuelve un token nuevo con la planta indicada. A partir de ahí opera en esa planta con los mismos permisos que su admin.\n\n'
        + 'No es una excepción al aislamiento: el token sigue llevando un único `plantaId` y los servicios siguen filtrando por él. Lo único que cambia es cuál es la planta de trabajo. '
        + 'Acepta `plantaId` o `codigo`.',
      security: [{ bearerAuth: [] }],
      requestBody: {
        required: true,
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: {
                plantaId: { type: 'integer' },
                codigo: { type: 'string', example: 'HUA' },
              },
            },
          },
        },
      },
      responses: {
        200: jsonResponse('Planta activa cambiada', 200),
        400: jsonResponse('Falta plantaId o codigo', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('Solo el superadmin cambia de planta', 403),
        404: jsonResponse('La planta no existe o está inactiva', 404),
      },
    },
  },
  '/plantas': {
    get: {
      tags: ['Plantas'],
      summary: 'Listar plantas',
      description: 'No se aísla por planta: cualquier rol con permiso de lectura puede verlas, por ejemplo para mostrar su planta en el perfil.',
      security: [{ bearerAuth: [] }],
      responses: authResponse('Consulta exitosa', 200),
    },
    post: {
      tags: ['Plantas'],
      summary: 'Crear planta',
      security: [{ bearerAuth: [] }],
      requestBody: requestBody('PlantaRequest'),
      responses: {
        201: jsonResponse('Planta creada', 201),
        400: jsonResponse('Datos inválidos', 400),
        401: jsonResponse('Token ausente, expirado o inválido', 401),
        403: jsonResponse('Solo el admin crea plantas', 403),
      },
    },
  },
  '/plantas/codigo/{codigo}': {
    get: {
      tags: ['Plantas'],
      summary: 'Buscar planta por código',
      security: [{ bearerAuth: [] }],
      parameters: [{ name: 'codigo', in: 'path', required: true, schema: { type: 'string' } }],
      responses: authResponse('Consulta exitosa', 200),
    },
  },
  '/health': {
    get: {
      tags: ['Sistema'],
      summary: 'Estado del servicio',
      responses: { 200: jsonResponse('Servicio disponible', 200) },
    },
  },
};

for (const recurso of RECURSOS) {
  Object.assign(paths, crudPaths(recurso));
}

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'MilkData API',
    version: '1.0.0',
    description: 'API de gestión de proveedores, recolecciones y control de calidad de MilkData. Planta Ecológica Huata.',
  },
  servers: [
    { url: `http://localhost:${process.env.PORT || 3000}`, description: 'Servidor local de desarrollo' },
  ],
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
    },
    schemas,
  },
  paths,
};

const swaggerSpec = swaggerJsdoc({
  definition: swaggerDefinition,
  apis: [
    path.join(__dirname, '../routes/**/*.js'),
    path.join(__dirname, '../controllers/**/*.js'),
  ],
});

module.exports = {
  swaggerDefinition,
  swaggerSpec,
};
