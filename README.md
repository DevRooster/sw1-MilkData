# MilkData API

Backend REST para la gestion de proveedores, entregas y control de calidad.

## Requisitos

- Node.js 18 o superior
- pnpm
- MySQL 8

## Instalacion

```bash
pnpm install
```

Copia `.env.example` a `.env` y ajusta las credenciales de MySQL:

```bash
copy .env.example .env
```

Variables principales:

```text
PORT=3000
DB_NAME=milkdata
DB_USER=root
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=3306
JWT_SECRET=mi-secreto-super-seguro-para-milkdata-2026
JWT_EXPIRES_IN=7d
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100
```

## Base de datos

Crea la base de datos antes de sincronizar las entidades:

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS milkdata CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
node sync-entities.js
```

El comando de sincronizacion usa las credenciales de `.env`.

## Seed

El seed crea 5 roles, 4 unidades, 4 zonas, el usuario administrador y 5 proveedores:

```bash
pnpm run seed
```

Es idempotente: usa claves naturales (`nombre`, `email`, `dni`) y no duplica registros al ejecutarse varias veces.

Credenciales del administrador:

```text
email: admin@milkdata.com
password: Admin123!
```

## Servidor

Desarrollo con nodemon:

```bash
pnpm run dev
```

Produccion/local sin watcher:

```bash
pnpm start
```

El servidor escucha por defecto en `http://localhost:3000`.

## Tests

Suite completa con cobertura:

```bash
pnpm test
```

Pruebas unitarias:

```bash
pnpm run test:unit
```

Pruebas de integracion:

```bash
pnpm run test:integration
```

Las pruebas de reportes crean entregas y controles reales en MySQL, validan los calculos y limpian sus datos temporales.

## Endpoints principales

### Salud y documentacion

```text
GET  /health
GET  /api-docs/
GET  /api-docs.json
```

### Autenticacion

```text
POST /auth/register
POST /auth/login
```

Ejemplo de login:

```bash
curl -X POST http://localhost:3000/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"admin@milkdata.com\",\"password\":\"Admin123!\"}"
```

La respuesta contiene un token JWT. Usalo como `Authorization: Bearer <token>` en rutas protegidas.

### Recursos

```text
POST   /proveedores
PUT    /proveedores/:id
DELETE /proveedores/:id

GET    /unidades
POST   /unidades
PUT    /unidades/:id
DELETE /unidades/:id

GET    /zonas
POST   /zonas
GET    /entregas
POST   /entregas
GET    /calidad
POST   /calidad
GET    /notificaciones
POST   /notificaciones
POST   /notificaciones/enviar
GET    /asistencias
POST   /asistencias
```

### Reportes

```text
GET /reportes/contraste
GET /reportes/calidad
GET /reportes/calidad-proveedor
```

Las respuestas usan el formato:

```json
{
  "success": true,
  "data": {},
  "message": "Operacion exitosa",
  "errors": []
}
```

## Estado conocido

- Swagger documenta actualmente login, proveedores y reporte de calidad; los aproximadamente 37 endpoints restantes estan pendientes de documentacion.
- El circuit breaker y retry estan aplicados al envio de notificaciones.
- Logout devuelve confirmacion, pero no invalida JWT ya emitidos porque la autenticacion es stateless.
- Bulkhead, timeout, load balancer y rate limiter general estan omitidos hasta que exista un flujo externo que los necesite.
