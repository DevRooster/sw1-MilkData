# PROMPT OPTIMIZADO — MilkData API (backend Node.js/Express)

> **Cómo usar este prompt**: pégalo completo como primer mensaje al agente. El agente debe ejecutar **una fase a la vez**, mostrar los archivos creados, y esperar tu "ok" o "continúa" antes de pasar a la siguiente fase. Esto evita que el agente trunque código o se salte archivos, algo que pasa casi siempre cuando se pide todo un backend en un solo turno.

---

## 0. ROL Y REGLAS DE EJECUCIÓN

Eres un agente de desarrollo backend trabajando dentro de VSCode con acceso al sistema de archivos y terminal del proyecto. Vas a construir el backend **MilkData API** siguiendo las fases descritas más abajo, EN ORDEN.

Reglas obligatorias:

1. **No avances de fase sin completar y verificar la anterior.** Al final de cada fase, lista los archivos creados/modificados y confirma que el proyecto sigue corriendo (`npm run dev` o equivalente) sin errores de importación.
2. **No generes código de fases futuras "adelantado".** Si una fase depende de algo que aún no existe, créalo como stub mínimo y complétalo en su fase correspondiente.
3. **Usa siempre las decisiones técnicas fijas de la sección 1.** No preguntes si usar ESM o CommonJS, ni qué ORM usar: ya está decidido.
4. Todo el código debe llevar **comentarios en español**, ser funcional (no pseudocódigo) y seguir el patrón: `routes → controllers → services → repositories → entities`.
5. Todas las respuestas HTTP deben usar el formato estándar definido en `src/utils/response.js` (ver Fase 1): `{ success, data, message, errors }`.
6. Si detectas una inconsistencia entre este prompt y algo que ya generaste, dilo explícitamente y pregunta cómo resolverla, en vez de improvisar en silencio.
7. Al terminar cada fase, genera (o actualiza) un archivo `PROGRESS.md` en la raíz marcando qué fases están completas.

---

## 1. DECISIONES TÉCNICAS FIJAS (no negociables, para evitar ambigüedad)

| Decisión | Valor |
|---|---|
| Módulos | **CommonJS** (`require`/`module.exports`) |
| Gestor de paquetes | `pnpm` |
| Base de datos | MySQL 8 + Sequelize (ORM) |
| Autenticación | JWT (`jsonwebtoken`) + `bcryptjs` para hash de passwords |
| Validación | `express-validator` |
| Documentación API | `swagger-jsdoc` + `swagger-ui-express` en `/api-docs` |
| Testing | Jest + Supertest, cobertura mínima 80% |
| Node.js | v18 o superior |

---

## 2. CONTEXTO DEL NEGOCIO (para que el agente entienda el dominio, no para que lo repita en el código)

- **Cliente**: Planta Ecológica Huata (Municipalidad de Huata).
- **Operación**: 390 proveedores de leche, 5,500 L/día, acopio 4:30–5:30 AM, 4 zonas, 4 unidades de acopio (3 furgones cerrados + 1 motocarga).
- **Roles de usuario**: Admin, Ingeniero, Acopiador, Calidad, Proveedor.
- **Procesos clave**: registro de entregas (campo/planta), control de calidad con lactoescáner (7 parámetros), notificaciones a proveedores, asistencia a capacitaciones (QR/manual), reportes de contraste campo-vs-planta.

---

## 3. ESTRUCTURA DE CARPETAS FINAL (objetivo, no crear todo de golpe)

```
milkdata-backend/
├── src/
│   ├── controllers/
│   ├── dtos/
│   ├── entities/
│   ├── repositories/
│   ├── services/
│   │   ├── interfaces/
│   │   └── impl/
│   ├── config/
│   ├── middlewares/
│   ├── security/
│   ├── resilience/
│   ├── utils/
│   ├── routes/
│   └── app.js
├── tests/
│   ├── unit/
│   ├── integration/
│   └── setup.js
├── docs/
├── .env
├── .env.example
├── .gitignore
├── package.json
└── server.js
```

---

## 4. PLAN DE EJECUCIÓN POR FASES

### FASE 0 — Setup del proyecto
- Inicializar `package.json`, instalar dependencias de producción y desarrollo (lista abajo).
- Crear `.env`, `.env.example`, `.gitignore`.
- Crear estructura completa de carpetas vacías (con `.gitkeep` si es necesario).
- Configurar scripts en `package.json`: `dev`, `start`, `test`, `test:watch`, `test:unit`, `test:integration`.

**Dependencias producción:**
```bash
pnpm add express cors helmet morgan dotenv sequelize mysql2 jsonwebtoken bcryptjs express-validator express-rate-limit swagger-jsdoc swagger-ui-express opossum p-retry winston
```
**Dependencias desarrollo:**
```bash
pnpm add -D nodemon jest supertest
```

**Criterio de "hecho"**: `pnpm install` corre sin errores; estructura de carpetas creada; `.env` con las variables de la sección 6.

---

### FASE 1 — Config + utilidades base
Archivos:
- `src/config/database.config.js` — conexión Sequelize a MySQL.
- `src/config/auth.config.js` — `JWT_SECRET`, `JWT_EXPIRES_IN`.
- `src/config/rateLimit.config.js`
- `src/config/swagger.config.js` — setup base de OpenAPI 3.0 (se completa en Fase 9).
- `src/utils/response.js` — `successResponse`, `errorResponse`, `paginatedResponse`.
- `src/utils/validators.js` — validación DNI, email, teléfono.
- `src/utils/helpers.js`
- `src/utils/logger.js` — Winston.

**Criterio de "hecho"**: se puede importar `database.config.js` y conectar a MySQL sin lanzar excepción (usar `sequelize.authenticate()` en un script de prueba temporal).

---

### FASE 2 — Entities (modelos Sequelize) + relaciones
Crear las 9 entidades exactamente con estos campos:

| Entidad | Campos clave |
|---|---|
| `usuario` | id, nombre, apellido, email(unique), password, rolId, proveedorId, activo, ultimoAcceso |
| `rol` | id, nombre(unique), descripcion, nivel, activo |
| `proveedor` | id, nombre, apellido, dni(unique), telefono, codigo(unique), zonaId, usuarioId(unique), activo |
| `zona` | id, nombre, ruta, horaInicio, horaFin, unidadId, activo |
| `unidad` | id, nombre, tipo(furgon/motocarga), capacidad, cerrado, activo |
| `entrega` | id, proveedorId, zonaId, unidadId, usuarioId, cantidad, fecha, hora, temperatura, registradoEn(campo/planta), sincronizado |
| `controlCalidad` | id, entregaId(unique), usuarioId, grasa, proteina, lactosa, densidad, temperatura, aguaAnadida, ph, resultado(pura/adulterada) |
| `notificacion` | id, proveedorId, usuarioId, tipo(adulteracion/reunion/capacitacion), titulo, mensaje, leida, enviada, fechaEnvio |
| `asistencia` | id, proveedorId, usuarioId, evento, fecha, registradoPor(QR/manual) |

Todas con `createdAt`/`updatedAt` (timestamps de Sequelize).

Relaciones a definir en `src/entities/index.js`:
- Usuario↔Rol (N:1), Usuario↔Proveedor (1:1)
- Proveedor↔Zona (N:1), Zona↔Unidad (N:1)
- Entrega↔Proveedor/Zona/Unidad/Usuario (N:1 cada una)
- ControlCalidad↔Entrega (1:1), ControlCalidad↔Usuario (N:1)
- Notificacion↔Proveedor/Usuario (N:1)
- Asistencia↔Proveedor/Usuario (N:1)

**Criterio de "hecho"**: `sequelize.sync()` corre sin errores y crea las 9 tablas con sus FKs correctas en MySQL.

---

### FASE 3 — Repositories
- `base.repository.js` (CRUD genérico: findAll, findById, create, update, delete, findByField).
- Un repositorio por entidad (8 en total, `usuario` incluido) que extienda el base y agregue métodos específicos (ej. `findByDNI`, `findByZona`, `findByFecha`, etc. — ver lista completa en el prompt original si necesitas el detalle método por método).

**Criterio de "hecho"**: un test manual rápido (script temporal) puede crear y leer un registro de cada tabla vía repositorio.

---

### FASE 4 — DTOs
Crear DTOs que transformen entidades → JSON de respuesta (anidando objetos relacionados, ej. `proveedor.dto.js` incluye el objeto `zona` completo, no solo `zonaId`):
- `proveedor.dto.js`, `entrega.dto.js`, `calidad.dto.js`, `notificacion.dto.js`, `asistencia.dto.js`, `auth.dto.js`.

**Criterio de "hecho"**: cada DTO tiene una función `toDTO(entidadSequelize)` pura, sin lógica de negocio ni acceso a BD.

---

### FASE 5 — Services (interfaces + implementación)
- Crear interfaces en `src/services/interfaces/` (documentan el contrato con JSDoc; en CommonJS esto es una clase/objeto que lanza `not implemented` o simplemente un comentario JSDoc — decide y sé consistente).
- Implementar en `src/services/impl/` la lógica de negocio real: validaciones (DNI único, código único, etc.), uso de repositorios y DTOs.
- Incluye `auth.service.js` con `login`, `register`, `verifyToken`, `logout`, `refreshToken`.

**Criterio de "hecho"**: cada service tiene al menos un test unitario básico con mocks de su repositorio (puede ser un placeholder que se completa en Fase 12).

---

### FASE 6 — Security + Middlewares
- `src/security/jwt.service.js`, `auth.service.js`, `permissions.service.js`.
- `src/middlewares/auth.middleware.js` (verifica JWT), `error.middleware.js` (manejo centralizado), `validation.middleware.js` (express-validator), `rateLimit.middleware.js`.

**Criterio de "hecho"**: una ruta protegida de prueba rechaza peticiones sin token (401) y acepta con token válido.

---

### FASE 7 — Controllers
- `base.controller.js` + un controller por entidad + `reporte.controller.js` (reporteContraste, reporteCalidad, reporteCalidadProveedor).
- Los controllers solo orquestan: reciben request → llaman al service → responden con `response.js`. Sin lógica de negocio aquí.

**Criterio de "hecho"**: cada controller maneja errores con `try/catch` y los pasa a `error.middleware.js` (o usa un wrapper `asyncHandler`).

---

### FASE 8 — Routes + app.js + server.js
- Un archivo de rutas por recurso + `index.routes.js` que las agrupa.
- `app.js`: configuración de Express (cors, helmet, morgan, rutas, error middleware, swagger).
- `server.js`: arranque del servidor + conexión a BD.

**Criterio de "hecho"**: `pnpm run dev` levanta el servidor y todos los endpoints listados responden (aunque sea con datos vacíos).

---

### FASE 9 — Swagger
- Completar `swagger.config.js` con esquemas OpenAPI 3.0 de todas las entidades y endpoints.
- Exponer en `/api-docs`.

**Criterio de "hecho"**: `/api-docs` carga en el navegador y permite probar al menos 3 endpoints distintos (uno de auth, uno de CRUD, uno de reporte).

---

### FASE 10 — Resilience (opcional/producción)
- `circuitBreaker.js` (opossum), `retry.js` (p-retry), `rateLimiter.js`, `bulkhead.js`, `timeout.js`, `loadBalancer.js`.
- Aplicar solo donde haya llamadas a servicios externos o recursos compartidos críticos (ej. envío de notificaciones).

**Criterio de "hecho"**: al menos un flujo (ej. envío de notificación) usa circuit breaker + retry, demostrable con un test que simula fallo.

---

### FASE 11 — Seeders (datos de prueba)
- 5 roles, 4 unidades, 4 zonas, 1 usuario admin (`admin@milkdata.com` / `Admin123!`), proveedores de ejemplo (mínimo 5).

**Criterio de "hecho"**: script `pnpm run seed` (agregar este script) puebla la BD sin duplicar si se corre dos veces.

---

### FASE 12 — Tests
- Unit tests por service (con mocks de repository).
- Integration tests por ruta (con supertest, BD de test separada o en memoria).
- Configurar Jest con cobertura mínima 80% (`jest.config.js` o sección en `package.json`).

**Criterio de "hecho"**: `pnpm test` pasa en verde y el reporte de cobertura alcanza ≥80%.

---

## 5. VARIABLES DE ENTORNO (.env)

```
PORT=3000
NODE_ENV=development

# Base de datos
DB_NAME=milkdata
DB_USER=root
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=3306

# JWT
JWT_SECRET=mi-secreto-super-seguro-para-milkdata-2026
JWT_EXPIRES_IN=7d

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100

# Empresa
EMPRESA_NOMBRE=Ecológica Huata
EMPRESA_UBICACION=Distrito de Huata
NOTIFICACION_PREFIJO=[PLANTA HUATA]
```

---

## 6. CÓMO EMPEZAR

Empieza ahora mismo por la **FASE 0**. Al terminarla, muéstrame:
1. La estructura de carpetas creada.
2. El `package.json` resultante.
3. Confirmación de que `pnpm install` corrió sin errores.

Luego espera mi confirmación antes de continuar con la FASE 1.
