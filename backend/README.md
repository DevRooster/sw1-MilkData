# MilkData API

Backend REST para la gestión de proveedores, recolecciones y control de calidad de la Planta Ecológica Huata.

## Dos formas de levantarlo

| | Con Docker | Sin Docker |
| --- | --- | --- |
| Qué necesitas | Docker Desktop | Node 18+, pnpm, MySQL 8 |
| Comandos | `docker compose up -d` | `pnpm install` + `pnpm start` |
| MySQL | contenedor, sin instalar | el de tu máquina o Laragon |
| Para quién | trabajar en equipo, desplegar, no ensuciar el sistema | depurar rápido con las herramientas del IDE |

Docker **no reduce el consumo de memoria**: el contenedor corre el mismo Node y encima
suma su propio overhead. Lo que da es que no tengas que instalar MySQL ni Node, y que
todo el equipo y el servidor usen exactamente lo mismo.

## Con Docker (recomendado)

Requisitos: solo [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/).

```bash
docker compose up -d --build          # levanta MySQL y la API
docker compose exec api node scripts/seed.js   # carga los datos iniciales
```

La API queda en <http://localhost:3000> y Swagger en <http://localhost:3000/api-docs>.

```bash
docker compose ps          # qué está corriendo y si está sano
docker compose logs -f api # sigue el arranque
docker compose restart api # reinicia solo la API
docker compose down        # apaga todo (la base se conserva)
docker compose down -v     # apaga y BORRA la base de datos
```

### Configuración

Los valores por defecto están en `.env.docker.example`. Para cambiarlos:

```bash
copy .env.docker.example .env.docker.local
```

Compose lee ese archivo automáticamente. Ahí es donde se cambia, por ejemplo:

```text
API_PORT=3000
DB_PORT_HOST=3307
JWT_SECRET=<una cadena larga y aleatoria>
```

### Por qué el puerto 3307

MySQL se expone en el **3307** del host y sigue en el **3306** dentro del contenedor. En
Windows Laragon ya ocupa el 3306, y dos procesos no pueden escuchar en el mismo puerto.
La API se conecta con `DB_HOST=mysql` (el nombre del servicio), no con `localhost`.

### Qué hay dentro

```text
Dockerfile            imagen de la API, en etapas
docker-compose.yml    MySQL + API, con healthchecks y volúmenes
.dockerignore         qué NO entra al contexto de build (node_modules, .env, uploads)
.env.docker.example   valores por defecto de los contenedores
uploads/              imágenes de la API; montadas como volumen, se ven desde Windows
```

La imagen es de **etapas**: la primera instala las dependencias de producción y la
última copia solo el código, así que no arrastra las devDependencies. Corre como usuario
`node`, no como `root`.

### Datos

La base vive en el volumen `mysql_data`. Sobrevive a `docker compose down` y a reiniciar
Docker; se borra con `docker compose down -v`.

Las tablas se crean solas al arrancar (`syncSchema`), y las migraciones se aplican antes.
Para empezar limpio:

```bash
docker compose down -v
docker compose up -d --build
docker compose exec api node scripts/seed.js
```

### Pruebas dentro del contenedor

```bash
docker compose --profile test run --rm tests
```

Corre sobre su propia base (`milkdata_test`), así que no toca los datos de desarrollo, y deja
el seed listo antes de arrancar. Los servicios tienen que estar arriba.

Dos pruebas crean y borran bases para comprobar la migración del esquema viejo. Para eso hacen
falto credenciales con permiso de `CREATE DATABASE`, que el usuario de la aplicación no tiene:
de ahí `TEST_DB_ADMIN_USER` y `TEST_DB_ADMIN_PASSWORD` en el servicio `tests`.

Para correrlas a mano hace falta la imagen aparte:

```bash
docker build --target test -t milkdata-test .
docker run --rm --network milkdata_default \
  -e DB_HOST=mysql -e DB_NAME=milkdata_test -e DB_USER=milkdata -e DB_PASSWORD=milkdata \
  -e TEST_DB_ADMIN_USER=root -e TEST_DB_ADMIN_PASSWORD=milkdata_root \
  milkdata-test
```

La etapa `test` incluye las devDependencies.

## Sin Docker

### Requisitos

- Node.js 18 o superior
- pnpm
- MySQL 8

### Instalación

```bash
pnpm install
copy .env.example .env
```

```text
PORT=3000
NODE_ENV=development
DB_NAME=milkdata
DB_USER=root
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=3306
JWT_SECRET=<cambia este valor>
JWT_EXPIRES_IN=7d
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100
```

## Base de datos: creación automática

Solo necesitas que la **base de datos** exista. Las **tablas se crean solas** al arrancar:

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS milkdata CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
pnpm start
```

Al arrancar, `syncSchema()`:

1. Corre las migraciones de `src/migrations/index.js` (renombres y columnas nuevas).
2. Ejecuta `sequelize.sync({ alter: false, force: false })`: crea las tablas que faltan y
   **reutiliza sin tocar** las que ya existen.

Nunca borra ni altera una tabla con datos. El arranque registra qué hizo:

```text
Migraciones aplicadas: 2
  + planta: crear tabla
  + planta: registrar la planta principal
Tablas creadas: rol, unidad, zona, usuario, proveedor, recoleccion, ...
Tablas reutilizadas: (ninguna)
```

Para hacerlo sin levantar el servidor:

```bash
pnpm run db:sync
```

### Migraciones

`sync` corre con `alter: false` a propósito, así que **una columna nueva declarada en un modelo
no se agrega a una tabla que ya existe**. Para eso están las migraciones. Son idempotentes
(correrlas dos veces no cambia nada) y **solo agregan o renombran**: nunca borran ni truncan.

Para agregar una columna a una tabla existente:

1. Declárala en el modelo de la entidad.
2. Agrégala a `MIGRACIONES` en `src/migrations/index.js`.

```js
{
  nombre: 'entrega: agregar observacion',
  async run({ queryInterface }) {
    await queryInterface.addColumn('recoleccion', 'observacion', {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null,
    });
  },
  antesDe: async ({ tablas, columnas }) => {
    if (!tablas.has('recoleccion')) return false;   // sync la creará completa
    return !(columnas.get('recoleccion') || new Set()).has('observacion');
  },
}
```

Las migraciones marcadas con `antesDeSync: true` corren **antes** del `sync`. Úsalo solo para
renombres: si el `sync` corriera primero, crearía la tabla nueva vacía y el `RENAME` fallaría
por colisión de nombre.

### Ver la estructura

```bash
pnpm run db:schema
```

Imprime cada tabla con sus columnas, tipos, nulabilidad, claves únicas, claves foráneas y un
diagrama de relaciones.

## Seed

```bash
pnpm run seed
```

Crea la planta principal, 5 roles, 4 unidades, 4 zonas, los dos administradores y 5 proveedores.
Es idempotente y corre por planta: si agregas una segunda planta a `PLANTAS` en el script,
cada una recibe su propio juego de datos.

La cuenta de arranque es el **superadmin**, porque es la única que puede crear plantas y
fundar el primer admin de cada una:

```text
admin@milkdata.com / Superadmin123!          superadmin (todas las plantas)
admin.huata@milkdata.com / Admin123!          admin de la planta principal
```

## Aislamiento por planta

Cada planta opera de forma independiente. Todo lo que ve un usuario está limitado a su planta.

- `usuario.planta_id` es `NOT NULL`: todo usuario pertenece a una planta.
- Las 9 tablas operativas llevan `planta_id` con índice y clave foránea a `planta`.
- El `planta_id` viaja en el JWT. `authMiddleware` arma `req.contexto`, y `BaseService` lo
  inyecta en **cada** consulta: lecturas, escrituras, filtros y reportes.

El `plantaId` que llegue en el cuerpo de una petición **se descarta**. Siempre gana el de la
sesión, así que ningún cliente puede leer ni escribir datos de otra planta. Un registro de otra
planta responde `404`, no `403`: desde fuera no se confirma siquiera que existe.

```text
Planta A                           Planta B
  admin-a ── token {plantaId: 1}     admin-b ── token {plantaId: 2}
      |                                  |
   GET /proveedores                 GET /proveedores
   -> solo proveedores de A         -> solo proveedores de B
```

`rol` y `planta` son globales: los niveles de permiso significan lo mismo en todas las plantas,
y `planta` es la raíz del aislamiento, no algo contenido dentro de él.

### Registrar usuarios de otra planta

El bootstrap sin token solo sirve para la **primera** planta del sistema. Las plantas siguientes
las crea un `admin` autenticado:

```bash
curl -X POST http://localhost:3000/plantas -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Planta Cusco","codigo":"CUS"}'

curl -X POST http://localhost:3000/auth/register -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Admin","apellido":"Cusco","email":"admin@cusco.com",
       "password":"Admin123!","rolId":2,"plantaId":2}'
```

Un admin solo puede registrar usuarios en su propia planta. La excepción es una planta
**recién creada**, que todavía no tiene admin: ahí cualquier admin puede fundarla. Sin esa
regla no habría forma de levantar la segunda planta.

### Registrar usuarios

`POST /auth/register` exige **cuatro cosas**: `nombre`, `apellido`, `email`, `password`,
`rolId` y además `plantaId`, más el `Authorization: Bearer` de un admin o superadmin.

`plantaId` es obligatorio y el registro nunca lo deduce. No es un campo opcional con valor por
defecto: cada usuario pertenece a una planta y esa planta hay que nombrarla. Sin él la
petición responde `400` y no se crea nada.

```text
id  rol
1   superadmin    todas las plantas
2   admin         solo la suya
3   supervisor
4   acopiador
5   operador
6   laboratorio
7   proveedor
```

Solo un **superadmin** puede crear a otro superadmin. Un admin de planta que lo intentara
obtendría `403`: si pudiera, escalaría de administrar una planta a administrar todas, que es
el poder que por diseño es exclusivo del superadmin.

| Quién llama | Qué crea | Resultado |
| --- | --- | --- |
| admin de planta | su propia planta | `200` |
| admin de planta | otra planta | `403` |
| admin de planta | un superadmin | `403` |
| superadmin | cualquiera | `200` |
| sin token | cualquiera | `401` |

## Galería de imágenes

Un registro puede tener **varias** imágenes: la foto de perfil de un usuario, la botella y la
etiqueta de un producto. La tabla `imagen` lo permite:

```text
imagen  id, planta_id, recurso, recurso_id, ruta, orden, principal
```

`recurso` es `planta`, `usuario`, `proveedor` o `producto`, y `recurso_id` es el id del registro.
No hay clave foránea porque el registro puede estar en cualquiera de esas cuatro tablas: una
tabla por recurso sería más puro y cuatro veces más código para lo mismo.

```bash
curl -X POST http://localhost:3000/uploads/api/producto/2 \
  -H "Authorization: Bearer $TOKEN" -F "archivo=@botella.jpg"

curl http://localhost:3000/uploads/api/producto/2 -H "Authorization: Bearer $TOKEN"
curl -X PUT http://localhost:3000/uploads/api/imagen/3/principal -H "Authorization: Bearer $TOKEN"
curl -X DELETE http://localhost:3000/uploads/api/imagen/3 -H "Authorization: Bearer $TOKEN"
```

Máximo 10 imágenes por registro.

### La columna `imagen` y la tabla `imagen`

Conviven a propósito. La columna `imagen` de `usuario`, `producto`, `proveedor` y `planta`
guarda la **principal**; la tabla `imagen` guarda todas.

Es redundancia deliberada: una lista de productos no puede ir a consultar la galería en cada
fila, así que la columna es el dato desnormalizado que se pinta, y la tabla es la fuente para
editar. Si se borrara la columna, las listas quedarían sin imagen; si se borrara la tabla, solo
se perderían las fotos que no son la principal.

Antes de que existiera la tabla, subir una segunda imagen dejaba la primera huérfana en disco:
nada la apuntaba. Ahora la anterior sigue en la galería y se puede volver a poner.

### Reglas que no conviene romper

- **La primera imagen que llega es la principal.** Las siguientes se agregan al final y no le
  quitan el sitio a la que ya estaba: subir una foto nueva no debe robar el lugar de la que ya
  estaba. Para cambiarla hay que usar `PUT /uploads/api/imagen/{id}/principal`.
- **Solo una es principal por registro.** Al marcar una, se le quita la marca a la anterior.
- **Borrar la principal no deja al registro sin imagen.** La siguiente pasa a serlo; si no
  queda ninguna, la columna se pone en `null`. Un registro apuntando a un archivo borrado es un
  error que la app vería como una foto rota.
- **`planta_id` se filtra siempre.** Una imagen de otra planta responde `404`, igual que el
  resto de lo operativo.
| sin `plantaId` | cualquiera | `400` |

## Imágenes

Las imágenes se **guardan en archivos dentro del proyecto**, en la carpeta `uploads/` de la
raíz. La columna `imagen` guarda la ruta con la que se sirven, no la URL absoluta, para que la
base no dependa de dónde esté desplegado.

```text
uploads/<plantaId>/<recurso>/<uuid>.<ext>     en disco
/uploads/<plantaId>/<recurso>/<uuid>.<ext>     lo que guarda la base y se sirve
```

```text
usuario.imagen      foto de perfil
proveedor.imagen    foto del proveedor
producto.imagen     imagen del producto
planta.imagen       logo de la planta
```

```text
GET    /uploads/api                configuración: carpeta, tipos, límite de tamaño
POST   /uploads/api                multipart: archivo + recurso + id opcional
DELETE /uploads/api                { imagen, recurso?, id? }
GET    /auth/perfil
PUT    /auth/perfil                nombre, apellido, imagen
PUT    /proveedores/:id/imagen
PUT    /productos/:id/imagen
```

`POST /uploads/api` acepta `archivo` (binario), `recurso` (`planta`, `usuario`, `proveedor`,
`producto`) y `id`. Con `id` la operación es **atómica**: guarda el archivo y actualiza la
columna, y si el registro no existe o es de otra planta responde 404 sin dejar el archivo
huérfano en disco. Sin `id` solo devuelve la ruta, para que el cliente la use después.

Se aceptan `image/jpeg`, `image/png`, `image/webp` y `image/gif`, hasta 5 MB
(`UPLOAD_MAX_BYTES`). El nombre del archivo lo genera la API con un UUID: nunca se usa el
nombre que envía el cliente.

`DELETE /uploads/api` solo borra archivos que la propia API almacenó; una URL externa se
rechaza con 400. Las rutas guardadas se resuelven contra `uploads/` y cualquier intento de
salir de esa carpeta con `../` devuelve `null`.

`PUT .../imagen` sigue existiendo para cuando el cliente ya tiene la imagen subida en otro
lado: acepta una ruta o una URL completa. `{"imagen": null}` la quita.

## Rutas de recolección

Una ruta es lo que el acopiador ya conoce: no la calcula el sistema, la mantiene la planta.
Tiene **paradas ordenadas** (`ruta_parada`) y un proveedor pertenece a **una sola ruta
activa** a la vez.

```text
ruta           planta_id, nombre, codigo (único por planta), hora_inicio, hora_fin, activa
ruta_parada    ruta_id, proveedor_id (único), orden (único por ruta), hora_estimada
zona.ruta_id   la zona pasa a apuntar a su ruta (antes era el texto `ruta`)
proveedor.ruta_id
```

`zona.ruta` (el texto) dejó de usarse. La migración convierte cada valor distinto en una fila
de `ruta` y apunta la zona a ella, pero **no borra la columna**: queda opcional y vacía. Si
tras revisarlo quieres eliminarla:

```bash
node -e "require('./src/config/database.config').sequelize.query('ALTER TABLE zona DROP COLUMN ruta')"
```

### Endpoints

```text
GET    /rutas                                   lista con el conteo de paradas
GET    /rutas/codigo/:codigo
GET    /rutas/:id                               con zonas y paradas ordenadas
GET    /rutas/:id/recomendada?recorridoId=      paradas en orden con el estado de cada una
POST   /rutas
PUT    /rutas/:id
DELETE /rutas/:id

POST   /rutas/:id/paradas                       { proveedorId, orden?, horaEstimada? }
PUT    /rutas/:id/paradas/orden                 { ordenes: [{ idParada, orden }] }
DELETE /rutas/:id/paradas/:paradaId

GET    /rutas/proveedores/:proveedorId/sugerencia
```

`sugerencia` indica en qué ruta debería entrar un proveedor que todavía no tiene: prioriza las
rutas que ya atienden su zona y, entre varias, la que tiene menos paradas. Devuelve también
las candidatas con su conteo, para que el móvil muestre por qué sugiere esa.

`agregarParada` mueve al proveedor: sale de la ruta anterior y queda en la nueva, junto con
su zona. `quitarParada` compacta el orden para no dejar huecos y libera al proveedor si ya
no está en ninguna ruta.

## Recorridos

El recorrido es la **ejecución real** de una ruta: una unidad, un acopiador y un ayudante
opcional. Nace `PLANIFICADO`; la recolección no arranca hasta que el acopiador marca
**EN RUTA**, y en ese momento se sellan las paradas copiándolas de la ruta.

```text
recorrido         ruta_id, unidad_id, acopiador_id, ayudante_*, estado, fecha,
                  hora_inicio, hora_fin, fecha_inicio, fecha_fin,
                  kilometraje_inicio, kilometraje_fin, observaciones
recorrido_parada  recorrido_id, ruta_parada_id, proveedor_id, orden, estado,
                  hora_llegada, hora_salida, recoleccion_id, litros, observaciones
unidad.acopiador_id
recoleccion.recorrido_parada_id
```

Estados: `PLANIFICADO` → `EN_RUTA` → `FINALIZADO`, con `CANCELADO` como salida de un recorrido
que no llegó a arrancar. Al finalizar, las paradas pendientes pasan a `OMITIDA` para que el
reporte cuadre.

### El acopiador y el ayudante

El **acopiador** es el rol del chófer de la unidad (`unidad.acopiador_id`). Es el único que
puede arrancar y finalizar un recorrido: otro acopiador recibe 403, y el supervisor o el admin
pueden hacerlo en nombre de él.

El **ayudante** es opcional y de dos formas:

- **interno**: se manda `ayudanteUsuarioId` con un usuario de la misma planta. Los datos
  sueltos se ignoran.
- **externo**: se mandan `ayudanteNombre`, `ayudanteApellido` y `ayudanteDni`, con
  `ayudanteCelular` opcional. Faltando alguno de los tres obligatorios, responde 400 con la
  lista de lo que falta.

### Endpoints

```text
GET    /recorridos?estado=&fecha=&unidadId=
GET    /recorridos/actual                        el EN RUTA del acopiador autenticado
GET    /recorridos/:id                           con ruta, unidad, acopiador y paradas
POST   /recorridos                               queda PLANIFICADO
PUT    /recorridos/:id
DELETE /recorridos/:id

POST   /recorridos/:id/iniciar                   EN RUTA: sella las paradas, registra la hora
POST   /recorridos/:id/finalizar                 las pendientes pasan a OMITIDA
POST   /recorridos/:id/cancelar

POST   /recorridos/:id/paradas/:paradaId/atender     { estado?, litros?, observaciones? }
POST   /recorridos/:id/paradas/:paradaId/recolectar   { cantidad, temperatura?, zonaId? }
```

`recolectar` crea la recolección enlazada a la parada (`recoleccion.recorrido_parada_id`), así
que se sabe qué visita del día generó cada registro sin depender del horario. La zona se
hereda del proveedor; si el proveedor no tiene zona y no se manda `zonaId`, responde 400. Una
parada no admite dos recolecciones.

## Autenticación y autorización

Todas las rutas exigen `Authorization: Bearer <token>`, salvo `POST /auth/login`,
`POST /auth/register` (durante el bootstrap) y `GET /health`.

```bash
curl -X POST http://localhost:3000/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"admin@milkdata.com\",\"password\":\"Superadmin123!\"}"
```

Recursos: `plantas`, `proveedores`, `unidades`, `zonas`, `rutas`, `recorridos`,
`recolecciones`, `calidad`, `notificaciones`, `asistencias`, `productos`.

```text
POST /auth/register   bootstrap del primer admin; después exige rol admin de la misma planta
POST /auth/login
POST /auth/verify     valida el token
POST /auth/refresh    emite un token nuevo conservando la planta
POST /auth/logout     confirmación; el JWT es stateless
GET  /auth/plantas    plantas que puedo supervisar
POST /auth/planta     superadmin: cambia la planta del token
```

### Matriz de permisos

`src/security/role-permissions.config.js`. `read` implica poder leer, `write` implica leer y escribir.
La matriz es igual para todas las plantas: el aislamiento depende de `plantaId`, no del rol.

| Rol | Acceso |
| --- | --- |
| `superadmin` | Control de todas las plantas. Crea plantas y puede operar en cualquiera de ellas |
| `admin` | Su propia planta: lectura y escritura en todos los recursos operativos. Solo lectura en la lista de plantas |
| `supervisor` | Escritura en proveedores, unidades, zonas, rutas, recorridos, recolecciones, calidad, notificaciones, asistencias y productos. Solo lectura en plantas y reportes |
| `acopiador` | Lectura en proveedores, unidades, zonas, rutas y reportes. Escritura en recorridos, recolecciones y asistencias |
| `operador` | Escritura en recolecciones, calidad, asistencias y productos. Solo lectura en el resto |
| `laboratorio` | Escritura en calidad. Solo lectura en proveedores, recolecciones, productos y reportes |
| `proveedor` | Solo lectura en proveedores, recolecciones, notificaciones y productos |

El `acopiador` no edita las rutas a propósito: puede leerlas y recorrerlas, pero cambiar el
orden de las paradas es decisión de la planta, no del chofer. Tampoco puede tocar los
catálogos (proveedores, unidades, zonas), que no son suyos.

Crear plantas es privativo del `superadmin`. El `admin` de cada planta administra la suya, y
por eso solo llega a consultarlas: la lista le sirve para mostrarla en su perfil, no para abrir
sedes nuevas.

Operación no permitida devuelve `403`. Sin token o con token inválido, `401`.

## Superadmin: control entre plantas

El superadmin administra todas las plantas, pero **no tiene excepciones al aislamiento**.
Opera en una sola planta a la vez, la que lleva en su token. Lo que puede hacer es pedir un
token para otra planta:

```text
GET  /auth/plantas                 plantas disponibles y cuántas son
POST /auth/planta                  { plantaId } o { codigo } -> token nuevo
```

`GET /auth/plantas` responde `alcance: TODAS` para el superadmin y `alcance: PROPIA` con un
solo elemento para cualquier otro rol, que es la única planta sobre la que tiene alcance.

`POST /auth/planta` devuelve un token con el `plantaId` de la planta elegida. Desde ahí todo
funciona igual que en la suya: los servicios siguen filtrando por el `plantaId` del token, un
`plantaId` en el cuerpo se sigue descartando, y los registros de otra planta siguen
respondiendo 404. Un `plantaId` guardado en el cuerpo que no coincide con el del token se
ignora.

Un `admin` que intenta cambiar de planta recibe 403.

## Paginación

Los listados vienen paginados porque el móvil trabaja en pantallas pequeñas.

```text
GET /proveedores?pagina=2&limite=20
```

| Parámetro | Por defecto | Máximo |
| --- | --- | --- |
| `pagina` | 1 | — |
| `limite` | 10 | 200 |

La respuesta trae los registros en `data.items` y el estado en `data.paginacion`:

```json
{
  "items": [],
  "paginacion": {
    "pagina": 2,
    "limite": 10,
    "total": 37,
    "totalPaginas": 4,
    "tieneAnterior": true,
    "tieneSiguiente": true
  }
}
```

El `total` cuenta todos los registros del filtro, no solo los de la página. Sale de la misma
consulta que las filas, así que siempre corresponde a los datos devueltos.

`pagina` o `limite` con un valor no entero, cero o negativo responden 400, y un `limite` por
encima de 200 también. Se rechazan en vez de ignorarse para que el cliente sepa que calculó
mal, en vez de recibir en silencio una página de 10.

Los filtros por ruta (`/proveedores/zona/3`, `/zonas/unidad/2`) también paginan. Los que
devuelven un único registro (`/proveedores/dni/:dni`) van en `data.item`, sin paginación.

Configurable con `PAGINACION_POR_PAGINA` y `PAGINACION_LIMITE_MAXIMO`.

## Referencias entre plantas

Una clave foránea solo garantiza que el id exista. Sin más, se podría enviar un `zonaId` de
otra planta y la base lo aceptaría, dejando datos de Huata apuntando a la zona de Cusco.

`src/config/referencias.config.js` declara qué campo apunta a qué tabla, y toda escritura
pasa por esa comprobación: el registro referenciado tiene que existir **y** pertenecer a la
misma planta. Si no, responde 400.

```text
unidad            acopiador_id
zona              ruta_id, unidad_id
proveedor         zona_id, ruta_id, usuario_id
ruta_parada       ruta_id, proveedor_id
recorrido         ruta_id, unidad_id, acopiador_id, ayudante_usuario_id
recorrido_parada  recorrido_id, ruta_parada_id, proveedor_id, recoleccion_id
recoleccion       proveedor_id, zona_id, unidad_id, usuario_id, recorrido_parada_id
calidad           recoleccion_id, usuario_id
notificacion      proveedor_id, usuario_id
asistencia        proveedor_id, usuario_id
```

Quedan fuera a propósito:

- `planta_id`: es la planta de la sesión, nunca viene del cuerpo.
- `rol_id`: `rol` es global por diseño, el mismo rol significa lo mismo en todas las plantas.
  Se valida solo que exista.

Las comprobaciones se agrupan por tabla destino, así que un registro con cinco referencias
cuesta cinco consultas en total y no una por campo. Los campos que no vienen en el cuerpo no
se vuelven a validar al actualizar, porque ya se comprobaron al crearse.

`tests/integration/referencias.test.js` incluye una prueba que recorre las asociaciones de
todos los modelos y falla si alguna `belongsTo` con `planta_id` no está declarada: agregar una
clave foránea nueva no puede escaparse de la validación por omisión.

## Endpoints

```text
GET  /health
GET  /api-docs/
GET  /api-docs.json
```

### Recursos

```text
GET    /{recurso}
GET    /{recurso}/:id
POST   /{recurso}
PUT    /{recurso}/:id
DELETE /{recurso}/:id
```

Recursos: `plantas`, `proveedores`, `unidades`, `zonas`, `rutas`, `recorridos`,
`recolecciones`, `calidad`, `notificaciones`, `asistencias`, `productos`.

Filtros:

```text
GET /proveedores/dni/{dni}
GET /proveedores/codigo/{codigo}
GET /proveedores/zona/{zonaId}
GET /unidades/tipo/{tipo}
GET /unidades/nombre/{nombre}
GET /zonas/nombre/{nombre}
GET /zonas/unidad/{unidadId}
GET /recolecciones/proveedor/{proveedorId}
GET /recolecciones/zona/{zonaId}
GET /recolecciones/fecha/{fecha}
GET /calidad/recoleccion/{recoleccionId}
GET /notificaciones/proveedor/{proveedorId}
GET /notificaciones/tipo/{tipo}
GET /asistencias/proveedor/{proveedorId}
GET /asistencias/evento/{evento}
GET /productos/nombre/{nombre}
GET /plantas/codigo/{codigo}
POST /notificaciones/enviar
```

Los filtros que devuelven un solo registro (por `dni`, `codigo`, `nombre`) lo ponen en
`data.item`. Los que devuelven varios, en `data.items` más `data.filtro`.

### Reportes

```text
GET /reportes/contraste
GET /reportes/calidad
GET /reportes/calidad-proveedor
GET /reportes/calidad/proveedor/{proveedorId}
```

Los reportes también están acotados a la planta, e incluyen `plantaId` en la respuesta.

### Formato de respuesta

```json
{
  "success": true,
  "data": {},
  "message": "Operación exitosa",
  "errors": []
}
```

## Estructura

```text
server.js                     arranque: migra, sincroniza y levanta el servidor
src/app.js                    configuración de Express
src/config/                   base de datos, JWT, rate limit, Swagger
src/entities/                 modelos Sequelize y sus asociaciones
src/migrations/               migraciones idempotentes de esquema
src/repositories/             acceso a datos, base CRUD en base.repository.js
src/services/impl/            lógica de negocio, CRUD y aislamiento en base.service.js
src/controllers/              capa HTTP, CRUD en base.controller.js
src/routes/                   rutas y middlewares por recurso
src/security/                 JWT, hashing y matriz de permisos
src/resilience/               retry y circuit breaker
src/dtos/                     proyección de entidades
scripts/db-sync.js            sincronización del esquema
scripts/db-schema.js          informe de tablas y relaciones
scripts/db-counts.js          cuántas filas hay en cada tabla
scripts/db-spec-check.js      rutas y esquemas documentados en Swagger
scripts/seed.js               datos iniciales
tests/unit, tests/integration suites
uploads/                      imágenes subidas por la API (no se versiona)
```

## Tests

```bash
pnpm test                 # suite completa con cobertura
pnpm run test:unit
pnpm run test:integration
pnpm run test:rutas       # rutas, recorridos e imágenes
pnpm run test:uploads
```

Los umbrales están en `jest.config.js`. Las pruebas de integración usan MySQL real y **dejan la
base igual que estaba**: cada suite borra solo las filas que creó, identificadas por un sufijo
único y acotadas a su planta. `pnpm run db:clean` borra todo lo que no venga del seed, por si
alguna corrida quedó a medias.

`tests/integration/migration.legacy.test.js` levanta una base aparte con el esquema anterior a
multi-planta y comprueba que la migración conserva los datos.
`tests/integration/swagger.test.js` comprueba que cada ruta documentada existe de verdad.

Para volver la base al estado del seed (borra todo lo que no venga del seed):

```bash
pnpm run db:clean
```

## Estado conocido

- `zona.ruta` (el texto) ya no se usa; queda en la base como columna opcional. Ver
  [Rutas de recolección](#rutas-de-recolección) para el comando que la elimina.
- `producto` es un catálogo independiente. El módulo de ventas (V20) lo conectará con ventas,
  inventario y producción.
- Logout no invalida JWT ya emitidos porque la autenticación es stateless.
- Bulkhead, timeout y load balancer están omitidos hasta que exista un flujo externo que los necesite.
