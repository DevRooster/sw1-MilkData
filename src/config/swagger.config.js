const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'MilkData API',
    version: '1.0.0',
    description: 'API backend para la gestión de proveedores, entregas y control de calidad de MilkData.',
  },
  servers: [
    {
      url: `http://localhost:${process.env.PORT || 3000}`,
      description: 'Servidor local de desarrollo',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
    schemas: {
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
          password: { type: 'string', format: 'password', example: 'Admin123!' },
        },
      },
      RegisterRequest: {
        type: 'object',
        required: ['nombre', 'apellido', 'email', 'password', 'rolId'],
        properties: {
          nombre: { type: 'string', example: 'Ana' },
          apellido: { type: 'string', example: 'García' },
          email: { type: 'string', format: 'email', example: 'ana@milkdata.com' },
          password: { type: 'string', format: 'password', example: 'Admin123!' },
          rolId: { type: 'integer', example: 1 },
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
        },
      },
    },
  },
  paths: {
    '/auth/register': {
      post: {
        tags: ['Auth'],
        summary: 'Registrar usuario (bootstrap o admin autenticado)',
        description: 'Durante el bootstrap, cuando aún no existe ningún usuario admin, solo se permite crear el primer admin sin token. Después, la ruta requiere un JWT válido con rol admin. OpenAPI no modela esta condición dinámica; por eso se documentan 401 y 403 además de 201/400/409.',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/RegisterRequest' } } },
        },
        responses: {
          201: {
            description: 'Usuario creado sin exponer password',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/StandardResponse' } } },
          },
          400: { description: 'Payload inválido o rolId no válido' },
          401: { description: 'Token requerido después del bootstrap' },
          403: { description: 'El token pertenece a un usuario no admin' },
          409: { description: 'El email ya está registrado' },
        },
      },
    },
    '/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Autenticar usuario',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/LoginRequest' } } },
        },
        responses: {
          200: {
            description: 'Login exitoso',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/StandardResponse' } } },
          },
          401: { description: 'Credenciales inválidas' },
        },
      },
    },
    '/proveedores': {
      post: {
        tags: ['Proveedores'],
        summary: 'Crear proveedor',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/ProveedorRequest' } } },
        },
        responses: {
          201: {
            description: 'Proveedor creado',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/StandardResponse' } } },
          },
          400: { description: 'Datos inválidos' },
        },
      },
    },
    '/reportes/calidad': {
      get: {
        tags: ['Reportes'],
        summary: 'Obtener reporte de calidad',
        responses: {
          200: {
            description: 'Reporte generado',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/StandardResponse' } } },
          },
        },
      },
    },
  },
};

const requestSchemas = {
  UnidadRequest: {
    type: 'object', required: ['nombre', 'tipo'],
    properties: { nombre: { type: 'string' }, tipo: { type: 'string', enum: ['furgon', 'motocarga'] }, capacidad: { type: 'number' }, cerrado: { type: 'boolean' }, activo: { type: 'boolean' } },
  },
  ZonaRequest: {
    type: 'object', required: ['nombre', 'ruta'],
    properties: { nombre: { type: 'string' }, ruta: { type: 'string' }, horaInicio: { type: 'string', example: '06:00:00' }, horaFin: { type: 'string', example: '10:00:00' }, unidadId: { type: 'integer' }, activo: { type: 'boolean' } },
  },
  EntregaRequest: {
    type: 'object', required: ['proveedorId', 'zonaId', 'unidadId', 'usuarioId', 'cantidad', 'fecha', 'registradoEn'],
    properties: { proveedorId: { type: 'integer' }, zonaId: { type: 'integer' }, unidadId: { type: 'integer' }, usuarioId: { type: 'integer' }, cantidad: { type: 'number' }, fecha: { type: 'string', format: 'date' }, hora: { type: 'string' }, temperatura: { type: 'number' }, registradoEn: { type: 'string', enum: ['campo', 'planta'] }, sincronizado: { type: 'boolean' } },
  },
  CalidadRequest: {
    type: 'object', required: ['entregaId', 'usuarioId'],
    properties: { entregaId: { type: 'integer' }, usuarioId: { type: 'integer' }, grasa: { type: 'number' }, proteina: { type: 'number' }, lactosa: { type: 'number' }, densidad: { type: 'number' }, temperatura: { type: 'number' }, aguaAnadida: { type: 'number' }, ph: { type: 'number' }, resultado: { type: 'string', enum: ['pura', 'adulterada'] } },
  },
  NotificacionRequest: {
    type: 'object', required: ['tipo', 'titulo', 'mensaje'],
    properties: { proveedorId: { type: 'integer' }, usuarioId: { type: 'integer' }, tipo: { type: 'string', enum: ['adulteracion', 'reunion', 'capacitacion'] }, titulo: { type: 'string' }, mensaje: { type: 'string' }, leida: { type: 'boolean' }, enviada: { type: 'boolean' } },
  },
  AsistenciaRequest: {
    type: 'object', required: ['proveedorId', 'usuarioId', 'evento', 'fecha', 'registradoPor'],
    properties: { proveedorId: { type: 'integer' }, usuarioId: { type: 'integer' }, evento: { type: 'string' }, fecha: { type: 'string', format: 'date' }, registradoPor: { type: 'string', enum: ['QR', 'manual'] } },
  },
};

function auth(security = true) {
  return security ? [{ bearerAuth: [] }] : undefined;
}

function response(description, code = 200) {
  return { [code]: { description, content: { 'application/json': { schema: { $ref: '#/components/schemas/StandardResponse' } } } }, 401: { description: 'Token ausente o inválido' }, 404: { description: 'Recurso no encontrado' } };
}

function crudPaths(resource, schema, filters = []) {
  const paths = {};
  paths[`/${resource}`] = {
    get: { tags: [resource], summary: `Listar ${resource}`, security: auth(), parameters: [{ name: 'page', in: 'query', schema: { type: 'integer' } }, { name: 'limit', in: 'query', schema: { type: 'integer' } }], responses: response('Consulta exitosa') },
    post: { tags: [resource], summary: `Crear ${resource}`, security: auth(), requestBody: { required: true, content: { 'application/json': { schema: { $ref: `#/components/schemas/${schema}` } } } }, responses: response('Registro creado', 201) },
  };
  paths[`/${resource}/{id}`] = {
    get: { tags: [resource], summary: `Obtener ${resource} por ID`, security: auth(), parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'integer' } }], responses: response('Consulta exitosa') },
    put: { tags: [resource], summary: `Actualizar ${resource}`, security: auth(), parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'integer' } }], requestBody: { required: true, content: { 'application/json': { schema: { $ref: `#/components/schemas/${schema}` } } } }, responses: response('Registro actualizado') },
    delete: { tags: [resource], summary: `Eliminar ${resource}`, security: auth(), parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'integer' } }], responses: response('Registro eliminado') },
  };
  for (const filter of filters) {
    const routeName = filter.routeName || filter.name;
    paths[`/${resource}/${routeName}/{${filter.name}}`] = { get: { tags: [resource], summary: `Filtrar ${resource} por ${filter.name}`, security: auth(), parameters: [{ name: filter.name, in: 'path', required: true, schema: { type: filter.type || 'string' } }], responses: response('Consulta exitosa') } };
  }
  return paths;
}

Object.assign(swaggerDefinition.components.schemas, requestSchemas);
Object.assign(swaggerDefinition.paths,
  crudPaths('proveedores', 'ProveedorRequest', [{ name: 'dni' }, { name: 'zonaId', routeName: 'zona', type: 'integer' }]),
  crudPaths('unidades', 'UnidadRequest', [{ name: 'tipo' }]),
  crudPaths('zonas', 'ZonaRequest', [{ name: 'unidadId', routeName: 'unidad', type: 'integer' }]),
  crudPaths('entregas', 'EntregaRequest', [{ name: 'proveedorId', routeName: 'proveedor', type: 'integer' }, { name: 'zonaId', routeName: 'zona', type: 'integer' }, { name: 'fecha' }]),
  crudPaths('calidad', 'CalidadRequest', [{ name: 'entregaId', routeName: 'entrega', type: 'integer' }]),
  crudPaths('notificaciones', 'NotificacionRequest', [{ name: 'proveedorId', routeName: 'proveedor', type: 'integer' }]),
  crudPaths('asistencias', 'AsistenciaRequest', [{ name: 'proveedorId', routeName: 'proveedor', type: 'integer' }, { name: 'evento' }]),
  {
    '/auth/verify': { post: { tags: ['Auth'], summary: 'Verificar JWT', security: auth(), responses: response('Token válido') } },
    '/reportes/contraste': { get: { tags: ['Reportes'], summary: 'Reporte de contraste campo/planta', security: auth(), responses: response('Reporte generado') } },
    '/reportes/calidad/proveedor/{proveedorId}': { get: { tags: ['Reportes'], summary: 'Reporte de calidad por proveedor', security: auth(), parameters: [{ name: 'proveedorId', in: 'path', required: true, schema: { type: 'integer' } }], responses: response('Reporte generado') } },
    '/notificaciones/enviar': { post: { tags: ['Notificaciones'], summary: 'Enviar notificación con retry y circuit breaker', security: auth(), requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/NotificacionRequest' } } } }, responses: { ...response('Notificación enviada', 201), 502: { description: 'Servicio externo no disponible' } } } },
    '/reportes/calidad': { get: { ...swaggerDefinition.paths['/reportes/calidad'].get, security: auth() } },
  }
);

const swaggerOptions = {
  definition: swaggerDefinition,
  apis: [
    path.join(__dirname, '../routes/**/*.js'),
    path.join(__dirname, '../controllers/**/*.js'),
  ],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

module.exports = {
  swaggerDefinition,
  swaggerOptions,
  swaggerSpec,
};
