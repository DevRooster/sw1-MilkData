# MilkData API: guía de flujo y pruebas

## 2. Matriz real de permisos

### Código verificado

`src/security/permissions.service.js` contiene exactamente:

```js
class PermissionsService {
  canAccess(user, requiredRole) {
    if (!user) {
      return false;
    }

    if (!requiredRole) {
      return true;
    }

    const roles = Array.isArray(requiredRole) ? requiredRole : [requiredRole];
    return roles.includes(user.rol) || roles.includes(user.role) || roles.includes(user.rolId);
  }
}

module.exports = new PermissionsService();
```

`src/middlewares/auth.middleware.js` solo valida el header Bearer y verifica la firma JWT. No importa `permissions.service.js`, no llama `canAccess()` y no devuelve 403:

```js
const { verifyToken } = require('../security/auth.service');
const { errorResponse } = require('../utils/response');

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return errorResponse(res, 'Token de autorización requerido.', 401, ['Unauthorized']);
    }

    const payload = await verifyToken(token);
    req.user = payload;
    return next();
  } catch (error) {
    const statusCode = error && error.statusCode ? error.statusCode : 401;
    return errorResponse(res, error.message || 'Token inválido.', statusCode, [error.message || 'Token inválido.']);
  }
}
```

Las rutas usan únicamente `route-layer.js`, que inicializa `layerTrace`; no usan `authMiddleware` ni un middleware de permisos. Por tanto, la política efectiva no es whitelist ni blacklist de roles: no hay autorización de roles aplicada y las rutas ni siquiera exigen JWT.

### Matriz efectiva

Leyenda:

- `✅`: la operación existe y no tiene restricción de rol; funciona incluso sin token en las rutas probadas.
- `N/I`: ruta/operación no implementada actualmente en Express, aunque pueda aparecer en Swagger.
- `403`: no se observó ningún caso porque no existe middleware que produzca 403.

| Recurso | Acción | admin | ingeniero | acopiador | calidad | proveedor |
|---|---|---:|---:|---:|---:|---:|
| Proveedores | GET | N/I | N/I | N/I | N/I | N/I |
| Proveedores | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Proveedores | PUT | ✅ | ✅ | ✅ | ✅ | ✅ |
| Proveedores | DELETE | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unidades | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unidades | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unidades | PUT | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unidades | DELETE | ✅ | ✅ | ✅ | ✅ | ✅ |
| Zonas | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Zonas | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Zonas | PUT | N/I | N/I | N/I | N/I | N/I |
| Zonas | DELETE | N/I | N/I | N/I | N/I | N/I |
| Entregas | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Entregas | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Entregas | PUT | N/I | N/I | N/I | N/I | N/I |
| Entregas | DELETE | N/I | N/I | N/I | N/I | N/I |
| Calidad | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Calidad | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Calidad | PUT | N/I | N/I | N/I | N/I | N/I |
| Calidad | DELETE | N/I | N/I | N/I | N/I | N/I |
| Notificaciones | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Notificaciones | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Notificaciones | PUT | N/I | N/I | N/I | N/I | N/I |
| Notificaciones | DELETE | N/I | N/I | N/I | N/I | N/I |
| Asistencia | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Asistencia | POST | ✅ | ✅ | ✅ | ✅ | ✅ |
| Asistencia | PUT | N/I | N/I | N/I | N/I | N/I |
| Asistencia | DELETE | N/I | N/I | N/I | N/I | N/I |
| Reportes | GET | ✅ | ✅ | ✅ | ✅ | ✅ |
| Reportes | POST | N/I | N/I | N/I | N/I | N/I |
| Reportes | PUT | N/I | N/I | N/I | N/I | N/I |
| Reportes | DELETE | N/I | N/I | N/I | N/I | N/I |
| Usuarios/Auth | GET | N/I | N/I | N/I | N/I | N/I |
| Usuarios/Auth | POST register/login/verify | ✅ | ✅ | ✅ | ✅ | ✅ |
| Usuarios/Auth | PUT | N/I | N/I | N/I | N/I | N/I |
| Usuarios/Auth | DELETE/logout | N/I | N/I | N/I | N/I | N/I |

La tabla describe el código actual, no la matriz esperada por negocio. En particular, un JWT válido no cambia el resultado de autorización porque las rutas no ejecutan `authMiddleware`.

### Evidencia HTTP real

Se crearon usuarios temporales con roles `admin`, `ingeniero`, `acopiador`, `calidad` y `proveedor`, se hizo login real con cada uno y se probaron acciones con sus tokens.

#### Proveedor intentando crear entrega

```text
proveedor intenta crear entrega [proveedor] POST /entregas STATUS: 201
```

Respuesta literal:

```json
{"success":true,"data":{"item":{"id":15,"proveedorId":20,"zonaId":12,"unidadId":13,"usuarioId":18,"cantidad":11,"fecha":"2026-09-07","registradoEn":"campo","sincronizado":false},"layerTrace":["routes","controller","service","repository"]},"message":"Registro creado","errors":[]}
```

Debería haber sido 403 si existiera una restricción de rol, pero el resultado real fue 201.

#### Admin creando entrega

```text
admin crea entrega [admin] POST /entregas STATUS: 201
```

#### Proveedor intentando crear control de calidad

```text
proveedor intenta crear calidad [proveedor] POST /calidad STATUS: 201
```

Respuesta literal:

```json
{"success":true,"data":{"item":{"id":13,"entregaId":13,"usuarioId":21,"grasa":3,"proteina":3,"lactosa":4,"densidad":1,"temperatura":4,"aguaAnadida":0,"ph":6,"resultado":"pura"},"layerTrace":["routes","controller","service","repository"]},"message":"Registro creado","errors":[]}
```

#### Proveedor intentando crear notificación

```text
proveedor intenta crear notificacion [proveedor] POST /notificaciones STATUS: 201
```

Respuesta literal:

```json
{"success":true,"data":{"item":{"id":5,"proveedorId":20,"usuarioId":18,"tipo":"reunion","titulo":"Permisos","mensaje":"Prueba temporal","leida":false,"enviada":false},"layerTrace":["routes","controller","service","repository"]},"message":"Registro creado","errors":[]}
```

#### Calidad consultando reportes

```text
calidad consulta reportes [calidad] GET /reportes/contraste STATUS: 200
```

#### Sin token consultando reportes

```text
sin token consulta reportes [ninguno] GET /reportes/contraste STATUS: 200
```

Este último resultado confirma que las rutas no exigen autenticación.

El script de evidencia fue `verify-permissions-real.js` y terminó con limpieza completa de datos temporales.

### Casos ambiguos

#### Alcance de entregas de un proveedor

Se creó un usuario con proveedor propio y otro proveedor distinto. Se intentó:

```text
GET /entregas/proveedor/22
```

Resultado real:

```text
OTHER_PROVIDER_ID: 22
OWN_PROVIDER_ID: 21
OTHER_PROVIDER_DELIVERY_ID: 17
GET_OTHER_PROVIDER_STATUS: 404
GET_OTHER_PROVIDER_JSON: {}
SCOPE_ENFORCED: false
```

La respuesta 404 no demuestra aislamiento por proveedor: la ruta `/entregas/proveedor/:proveedorId` no está implementada en Express. No existe filtrado automático ni autorización de ownership verificable.

#### Política por defecto

No hay whitelist ni blacklist aplicada. El resultado efectivo es ausencia de control:

- sin token en reportes: 200;
- proveedor creando entrega: 201;
- proveedor creando calidad: 201;
- proveedor creando notificación: 201;
- no se produce 403.

La línea `permissions.service.js` queda como código no conectado al flujo HTTP actual.
