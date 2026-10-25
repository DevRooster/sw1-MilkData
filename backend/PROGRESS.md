# Progreso del proyecto MilkData API

## Multi-planta
- [x] Tabla `planta` (nombre, codigo único, direccion, imagen, activo).
- [x] `planta_id NOT NULL` con índice y FK en las 13 tablas operativas.
- [x] Migración aditiva que agrega la columna, asigna los registros previos a la planta
      principal y la vuelve NOT NULL, sin perder datos.
- [x] `plantaId` viaja en el JWT; `authMiddleware` arma `req.contexto`.
- [x] `BaseService` inyecta el filtro de planta en cada lectura y escritura, e ignora el
      `plantaId` que llegue en el cuerpo de la petición.
- [x] `ReporteService` también se acota por planta.
- [x] Un registro de otra planta responde 404, no 403.
- [x] Seed por planta: agregar una segunda a `PLANTAS` le da su propio juego de datos.
- [x] Bootstrap sin token limitado a la primera planta del sistema.
- [x] Un admin puede fundar una planta nueva creando su primer admin; después, cada
      planta solo registra en la suya.
- [x] `productos` agregado a la matriz de permisos; `plantas` solo la escribe el admin.
- [x] 31 pruebas de integración dedicated verifican el aislamiento, incluidas rutas y recorridos.

## Renombre entrega → recoleccion
- [x] Tabla `entrega` → `recoleccion` con `RENAME TABLE`, conservando datos y FKs.
- [x] `control_calidad.entrega_id` → `recoleccion_id`.
- [x] Archivos renombrados en las 5 capas: entity, repository, service, controller, route, dto.
- [x] Rutas `/entregas` → `/recolecciones`; filtro `/calidad/entrega/{id}` → `/calidad/recoleccion/{id}`.
- [x] Matriz de permisos y Swagger actualizados.
- [x] Prueba de migración real sobre una base con el esquema anterior y datos.

## Imagen: de URL a archivo
- [x] `defaultValue: null` en las columnas `imagen`: el atributo ya no viene `undefined`.
- [x] `usuario.imagen`, `proveedor.imagen`, `producto.imagen`, `planta.imagen`.
- [x] `GET /auth/perfil` y `PUT /auth/perfil` (ignora email, password, rol y planta).
- [x] `PUT /proveedores/:id/imagen` y `PUT /productos/:id/imagen` (aceptan ruta o URL externa).
- [x] `POST /uploads/api` con multer: `uploads/<plantaId>/<recurso>/<uuid>.<ext>`, servido
      desde el mismo origen en `/uploads/...`.
- [x] Con `id` la subida es atómica: si el registro no existe o es de otra planta responde 404
      y no deja el archivo huérfano en disco.
- [x] `DELETE /uploads/api` desvincula y borra; solo toca archivos que la API almacenó.
- [x] El nombre del archivo lo genera la API con un UUID, nunca el cliente.
- [x] Se corrigió la CSP de helmet: las claves van en kebab-case (`img-src`), y de paso el
      `connectSrc` anterior nunca aplicó porque `connect-src` no estaba en los defaults.
- [x] `uploads/` en `.gitignore` conservando la carpeta vacía.

## Rutas de recolección
- [x] `ruta` (nombre, código único por planta, horas, activa) y `ruta_parada`
      (orden único por ruta, hora estimada, proveedor único).
- [x] `zona.ruta` (texto) → `zona.ruta_id`. La migración convierte cada valor distinto en una
      ruta y apunta la zona a ella; **no borra la columna**, queda opcional.
- [x] `proveedor.ruta_id`: un proveedor pertenece a una sola ruta activa.
- [x] `GET /rutas/:id/recomendada`: paradas en orden con el estado de cada una en el recorrido.
- [x] `GET /rutas/proveedores/:id/sugerencia`: prioriza la ruta que ya atiende la zona del
      proveedor y, entre varias, la que tiene menos paradas.
- [x] Alta, baja y reordenamiento de paradas. Agregar mueve al proveedor de ruta; quitar
      compacta el orden y lo libera si ya no está en ninguna.
- [x] El reordenamiento renumera al final, para que las paradas no incluidas no queden con el
      número grande de apartamiento.

## Recorridos
- [x] `recorrido` con estados `PLANIFICADO` → `EN_RUTA` → `FINALIZADO`, más `CANCELADO`.
- [x] Las paradas se sellan al arrancar, no al crear: el plan refleja la ruta tal como está.
- [x] `recorrido_parada` con estado, hora de llegada y salida, litros y recolección enlazada.
- [x] Rol `acopiador`: es el chófer de la unidad (`unidad.acopiador_id`) y el único que arranca
      y finaliza un recorrido. El supervisor y el admin pueden hacerlo en nombre de él.
- [x] Ayudante opcional: interno (`ayudanteUsuarioId`) o externo (nombre, apellido, dni y
      celular). Un externo incompleto responde 400 con la lista de lo que falta.
- [x] `POST /recorridos/:id/paradas/:paradaId/recolectar` crea la recolección con
      `recoleccion.recorrido_parada_id`, y la zona se hereda del proveedor.
- [x] Al finalizar, las paradas pendientes pasan a `OMITIDA` para que el reporte cuadre.
- [x] `GET /recorridos/actual` devuelve el EN RUTA del acopiador autenticado.
- [x] `proveedor.direccion`: el acopiador la necesita para llegar.
- [x] `fecha_inicio` y `fecha_fin` son `DATE`, no `DATETIME`: la hora va en `hora_inicio`.

## Correcciones encontradas al reescribir los tests
- [x] `ReporteService` pasaba el filtro sin envolver en `where`, así que Sequelize ignoraba la
      condición y los reportes leián **todas** las plantas.
- [x] `average()` contaba `null` como `0`, bajando artificialmente los promedios de calidad.
- [x] Las 9 tablas con `planta_id` no declaraban `belongsTo(Planta)`, así que `include` no
      resolvia la planta.
- [x] `rutaEnDisco` trataba una URL externa como archivo local: `path.resolve` construía
      `<uploads>/https:/...` y la API aceptaba borrar algo que no le pertenece.
- [x] El `INSERT` de la migración leía `insertId` de la posición equivocada del resultado de
      MySQL, así que `ruta_id` quedaba sin valor en las bases con el esquema anterior.
- [x] El detalle de rutas y recorridos usaba el `findById` genérico, que no carga
      asociaciones: las paradas no llegaban al móvil.
- [x] `BaseController.list` reenviaba solo la paginación y descartaba el resto de la query, así
      que `?estado=` y `?fecha=` llegaban nulos al servicio.
- [x] Al unificar `list` en `BaseService` quedaron sin usarse los `list` propios de rutas y
      recorridos, que contaban paradas y filtraban por estado.
- [x] La rama del superadmin en `registerAccessMiddleware` se llevó por delante el guard
      `adminDeLaPlanta &&`, y el registro del primer admin de una planta nueva dejó de
      funcionar con 403.
- [x] `plantasDisponibles` proyectaba con el DTO de usuario, así que `codigo` salíA
      `undefined`. Se creó `src/dtos/planta.dto.js`.

## Paginación
- [x] `?pagina=` y `?limite=` en todos los listados. 10 por página, máximo 200.
- [x] `data.paginacion` con `pagina`, `limite`, `total`, `totalPaginas`, `tieneAnterior` y
      `tieneSiguiente`.
- [x] `findAndCountAll`: el total y las filas salen de la misma consulta, así que el total
      siempre corresponde a los datos devueltos.
- [x] Valores inválidos (`0`, negativos, no enteros, límite mayor al máximo) responden 400 en
      vez de ignorarse en silencio.
- [x] Los filtros por ruta también paginan; los de un solo registro van en `data.item`.
- [x] `RutaService.list` y `RecorridoService.list` sobrescriben `list` respetando la firma
      `{ items, paginacion }` para poder agregar conteos y filtros.
- [x] `findAndCountAll` vive en el repositorio: los servicios no tocan el modelo.
- [x] Configurable con `PAGINACION_POR_PAGINA` y `PAGINACION_LIMITE_MAXIMO`.

## Referencias cruzadas entre plantas
- [x] `src/config/referencias.config.js`: mapa `campo -> tabla referenciada` por modelo.
- [x] Toda escritura (create y update) comprueba que las referencias existan y sean de la misma
      planta. Responde 400 con un texto que no distingue "no existe" de "es de otra planta".
- [x] `planta_id` no se valida (viene de la sesión) y `rol_id` solo por existencia, porque `rol`
      es global por diseño.
- [x] Las comprobaciones se agrupan por tabla destino: un registro con cinco referencias cuesta
      cinco consultas, no una por campo.
- [x] Al actualizar solo se revalidan los campos presentes en el cuerpo.
- [x] Prueba que recorre las asociaciones de todos los modelos y falla si una `belongsTo` con
      `planta_id` no está declarada: una clave foránea nueva no puede escaparse por omisión.

## Superadmin multi-planta
- [x] Rol `superadmin` con la matriz completa de permisos.
- [x] `GET /auth/plantas` devuelve las plantas disponibles y cuántas son, con
      `alcance: TODAS` o `PROPIA`.
- [x] `POST /auth/planta` emite un token para otra planta, por `plantaId` o `codigo`.
- [x] Sin excepciones al aislamiento: el token sigue llevando un `plantaId` y los servicios
      siguen filtrando por él. Cambia el token, no las reglas.
- [x] Crear plantas es privativo del superadmin; el admin solo consulta la lista.
- [x] El superadmin puede fundar una planta creando su primer admin, igual que antes podía
      hacerlo un admin de otra planta.
- [x] `req.contexto.superadmin` para que el código de abajo sepa el alcance.

## Tests
- [x] 494 tests en 24 suites.
- [x] `jest.config.js` con umbrales de 80% global.
- [x] Migración probada contra el esquema anterior en una base separada.
- [x] `swagger.test.js` comprueba que cada ruta documentada existe de verdad.
- [x] La suite **no deja residuos**: cada una borra solo sus filas, por sufijo y acotadas a su
      planta. `limpiar()` se niega a correr sin sufijo para que nadie repita el borrado accidental
      que vació la base del seed.
- [x] `pnpm run db:clean` devuelve la base al estado del seed y deriva sus listas de
      `scripts/seed.js`, así que no se desincroniza al agregar datos.
- [x] `pnpm run db:counts` y `pnpm run db:spec` para inspeccionar la base y la documentación.

## Documentación
- [x] Swagger con 65 rutas, incluidos `/rutas`, `/recorridos`, `/uploads/api`,
      `/auth/plantas` y `/auth/planta`.
- [x] README con arranque automático, migraciones, aislamiento por planta, imágenes en disco,
      rutas, recorridos, paginación, referencias cruzadas, superadmin y matriz de permisos.

## Pendientes
- [ ] Módulo de ventas (V20): `clientes_mayoristas`, `ventas`, `venta_detalle`,
      `movimiento_inventario`, `configuracion_descuento_planta`, `produccion_queso`.
- [ ] Módulo de adulteración (V18) y solicitud de cambio de ruta (V19).
- [ ] GPS y offline en el móvil: hoy `recorrido` no guarda coordenadas, así que no hay prueba
      de que la parada se haya hecho en la finca del proveedor.
- [ ] Bulkhead, timeout y load balancer si aparece un flujo externo.
