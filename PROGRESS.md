# Progreso del proyecto MilkData API

## Fase 0: Setup del proyecto
- [x] Inicializado el proyecto base.
- [x] Dependencias y scripts definidos.
- [x] Archivos de entorno y estructura creados.
- [x] Verificación de instalación exitosa.

## Fase 1: Config + utilidades base
- [x] Configuración de base de datos creada.
- [x] Configuración JWT creada.
- [x] Configuración de rate limiting creada.
- [x] Configuración Swagger base creada.
- [x] Utilidades de respuesta, validación y log creada.
- [x] Verificación de conexión e importación confirmada con `DB_CONNECTION_OK`.

## Fase 12: Tests
- [x] Probar los tres endpoints de reporte con datos reales de entrega y control de calidad.
- [x] Validar el cálculo de contraste campo-vs-planta y los promedios de calidad con resultados esperados.
- [x] `pnpm test` pasa con cobertura real superior al 80%.
- [x] Verificar update/delete inexistente en repositories y respuestas HTTP 404.
- [x] Verificar tokens expirados/manipulados, refreshToken y comportamiento stateless de logout.

## Fase 9: Swagger
- [x] Documentar las rutas solicitadas, parámetros, schemas, seguridad y respuestas en `swagger.config.js`.
- [x] Verificar `/api-docs.json`, Swagger UI y tres ejecuciones reales desde “Try it out”.

## Fase 10: Resilience
- [x] Verificar circuit breaker y retry en el envío de notificaciones.
- [ ] Evaluar `bulkhead.js`, `timeout.js`, `loadBalancer.js` y un rate limiter general si aparecen nuevos flujos externos que los requieran.
- [x] Actualmente omitidos: no existen otros flujos externos en el proyecto que justifiquen aplicarlos.

## Fase 11: Seeders
- [x] Crear y verificar seed idempotente con roles, unidades, zonas, admin y proveedores.

## Pendientes fuera de alcance
- [ ] Completar los handlers Express que aún no existen para algunas rutas CRUD documentadas (filtros y GET/PUT/DELETE adicionales); el spec ya está preparado para ellas.
- [ ] Conectar `auth.middleware.js` y `permissions.service.js` a las rutas y definir whitelist real por rol; actualmente no existe autorización RBAC ni aislamiento por proveedor.
- [ ] Implementar bulkhead, timeout, load balancer y rate limiter general si aparecen nuevos flujos externos.
- [ ] Reforzar branch/function coverage de repositories y services si se exige un umbral adicional al 80% global de statements/lines.
