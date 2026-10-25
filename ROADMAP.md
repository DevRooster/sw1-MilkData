# MilkData — orden de construcción de los módulos

> Escrito el 2026-10-10, con el proyecto medido: 114 endpoints en el backend,
> 527 pruebas backend verdes, 38 pruebas Flutter verdes, 2 módulos en el móvil.

---

## 1. Dónde estamos

| | |
| --- | --- |
| Endpoints en el backend | **115** |
| Endpoints con pantalla en el móvil | **36** (auth 10, usuarios 7, imágenes 7, unidades 7, planta 6) |
| Endpoints que solo existen en la API | **79** |
| Módulos del móvil terminados | **13** (los 13) |
| Pruebas del backend | **559** |
| Pruebas del móvil | **279** |

**El backend está prácticamente terminado.** Los 79 endpoints que faltan en el
móvil ya existen, ya tienen pruebas y ya están documentados en Swagger.

Esto cambia el plan. No vamos a "construir un módulo" en el sentido de escribir
un servicio y sus pruebas: vamos a **recorrer el patrón que Autenticación ya
fijó** sobre recursos que ya están hechos.

El riesgo real dejó de ser el backend. Es que el patrón se degrade en el
noveno módulo, cuando ya nadie recuerda por qué era así. Por eso este
documento insiste más en las reglas que en los hitos.

---

## 2. La regla de un módulo

Autenticación y Usuarios dejaron el molde. Un módulo es siempre esto:

**Backend** — ya hecho en el 85 % de los casos:

- `src/entities/` — la tabla
- `src/repositories/`, `src/services/impl/`, `src/controllers/`, `src/routes/`
- `src/config/swagger.config.js` — cada endpoint con esquema y sus códigos
- `src/security/role-permissions.config.js` — qué roles leen y qué roles escriben
- `tests/integration/` — las reglas que no son obvias

**Frontend** — esto es lo que falta de verdad:

```text
features/<modulo>/
  domain/            modelo puro, sin importar Flutter
  data/              api.dart + repository.dart (Dio, sin widgets)
  presentation/
    providers/       controller Riverpod, y los filtros en otro provider
    <recurso>_page.dart   lista con filtros y paginación
    <recurso>_form.dart   alta y edición
```

### Cuatro reglas que ya pagaron

1. **Los filtros van en su propio provider**, no dentro del estado de la
   pantalla. Meterlos dentro obliga al provider a depender de su propio estado
   durante `build`, que es un ciclo.
2. **Todo selector con opción "todos" la tiene de verdad.** Si el texto dice
   "Todos" pero la hoja no lo ofrece, el filtro es una puerta de sentido único.
   Se pagó en el filtro por rol.
3. **Cada columna desnormalizada tiene un dueño.** `usuario.rolId` se cambia
   solo por `PUT /usuarios/:id/rol`, nunca por `PUT /usuarios/:id`. La misma
   regla se aplica en el módulo de Proveedores (ver §6).
4. **Un módulo sin prueba de su regla más incómoda no está terminado.** No hace
   falta probar cada endpoint: sí la regla que, si se rompe, nadie ve.

---

## 3. El grafo de dependencias real

No es una suposición: sale de las columnas de cada tabla.

```text
                       ┌──────────┐
                       │ PLANTA   │  (ya está: se crea sola en /auth/register)
                       └────┬─────┘
                            │
        ┌───────────────────┼───────────────────────┐
        │                   │                       │
   ┌────▼────┐         ┌────▼────┐            ┌─────▼─────┐
   │  UNIDAD │         │ PRODUCTO│            │  RUTA     │
   │ acopiador       │ (suelto)│            │ (suelta)  │
   │   →Usuario      └──────────┘            └─────┬─────┘
   └────┬─────┘                                   │
        │        ┌──────────┐                      │
        └───────►│   ZONA   │◄─────────────────────┘
                 │ ruta,unid│
                 └────┬─────┘
                      │
                 ┌────▼──────┐        ┌──────────┐
                 │ PROVEEDOR │───────►│RUTAPARADA│
                 │ (galería) │        └──────────┘
                 └────┬──────┘
                      │
   ┌──────────────┬───┴────────────┬──────────────────┐
   │              │                │                  │
┌──▼─────┐  ┌─────▼───────┐  ┌─────▼─────┐     ┌──────▼──────┐
│ASISTENCIA│ │ RECORRIDO   │  │ NOTIFIC.  │     │  REPORTE    │
└──────────┘  │ ruta,unidad │  └───────────┘     │ (solo lee)  │
              └─────┬───────┘                    └─────────────┘
                    │
              ┌─────▼──────┐
              │ RECOLECCIÓN│
              └─────┬──────┘
                    │
              ┌─────▼──────┐
              │  CALIDAD   │
              └────────────┘
```

**Las tres cosas que sorprenden:**

- **`Ruta` no depende de nada.** No tiene `unidadId` ni `zonaId`. Se puede
  construir entero antes que Zonas y Proveedores.
- **`Zona` depende de `Ruta` y de `Unidad`**, no al revés. El orden intuitivo
  (zonas antes que rutas) es el orden imposible.
- **`Recoleccion` cuelga de `RecorridoParada`**, no del `Recorrido`. Es lo que
  permite que una parada tenga su propia recolección y su propio control de
  calidad.

---

## 4. El orden recomendado

Cada módulo es una rebanada vertical: se ve funcionando en el teléfono antes de
pasar al siguiente. El "tamaño" es el esfuerzo relativo, no en días.

| # | Módulo | Endpoints | Depende de | Tamaño |
| --- | --- | --- | --- | --- |
| 1 | **Autenticación** | 9 | — | ✅ hecho |
| 2 | **Usuarios** | 7 | 1 | ✅ hecho |
| 3 | **Unidades** | 7 | 1 | ✅ hecho |
| 4 | **Productos** | 7 | — | ✅ hecho |
| 5 | **Rutas** | 11 | — | ✅ hecho |
| 6 | **Zonas** | 7 | 3, 5 | ✅ hecho |
| 7 | **Proveedores** | 9 | 1, 6 | ✅ hecho |
| 8 | **Recorridos** | 11 | 3, 5, 1 | ✅ hecho |
| 9 | **Recolecciones** | 8 | 7, 8 | ✅ hecho |
| 10 | **Calidad** | 6 | 9 | ✅ hecho |
| 11 | **Notificaciones** | 8 | 7, 1 | ✅ hecho |
| 12 | **Asistencias** | 7 | 7, 1 | ✅ hecho |
| 13 | **Reportes** | 4 | todo | ✅ hecho |

### Por qué este orden y no otro

**3. Unidades antes que nada.** Es la rebanada vertical más pequeña que existe:
siete endpoints, dos columnas, ninguna dependencia nueva. Y es la primera que
introduce un patrón que se repite: **asignar un usuario a un registro**
(`unidad.acopiadorId`). Ese mismo selector usuario-a-entidad vuelve en
Recorridos, en Notificaciones y en Asistencias. Si se hace bien aquí, sale
casi gratis en los tres sitios siguientes.

**4. Productos.** No depende de nada y vale casi igual que Unidades. Encaja
aquí porque `SelectorImagen` ya está escrito y es genérico, pero **hoy no tiene
ninguna pantalla que lo use**: es el componente huérfano más visible del
proyecto. Este módulo le da casa y valida la galería con un segundo recurso, que
es como se descubre si de verdad era genérica o si solo funcionaba con usuarios.

**5. Rutas antes que Zonas**, porque `zona.ruta_id` es una clave foránea real:
no se puede crear una zona sin ruta, y la matriz de referencias lo rechaza.
Al revés de lo intuitivo, pero no hay vuelta atrás.

**8. Recorridos es el módulo que justifica el proyecto**, y el más caro: once
endpoints, cinco transiciones de estado (iniciar, atender, recolectar, finalizar,
cancelar) y reglas que no se ven en el código. Es el primero donde un bug de
permisos hace daño real: que un acopiador pueda cerrar el recorrido de otro.

**13. Reportes al final, sin discusión.** Cuatro endpoints de solo lectura que
agregan sobre recolecciones, calidad y proveedores. Si se hacen antes, se
reescriben cuando cambien los módulos de los que dependen.

### La excepción que quiero plantear

Si lo que se busca es **enseñar la app funcionando cuanto antes** y no aprender
el patrón, el salto es atractivo pero posible: **módulos 3 a 8 del tirón**,
con el Recorrido como única pantalla real. Cuesta más de una sentada y deja
Unidades, Zonas y Rutas sin pulir.

Mi recomendación sigue siendo el orden de la tabla. El patrón solo se aprende
haciendo módulos pequeños, y el primero grande sale solo.

---

## 5. Dos decisiones que había que tomar ANTES del módulo 4

Ya están tomadas. Se dejan escritas porque explican por qué el móvil está como
está, y porque el razonamiento sigue sirviendo cuando se añadan más módulos.

### 5.1 La barra de pestañas no llegaba a once módulos

Había tres pestañas fijas y escritas a mano en `app.dart`. Con once módulos no
caben ni se leen.

**Lo que se hizo:** la pestaña **Inicio** dejó de ser solo la tarjeta de perfil
y pasó a ser el lanzador de módulos. Perfil se quedó como segunda pestaña, y la
de Usuarios se quitó: su módulo vive ahora en el lanzador.

No se puso una pestaña por módulo porque habría que reescribir `app.dart` once
veces, que es justo la deuda que este documento pide no crear. Un
`CupertinoTabBar` con más de cuatro o cinco elementos tampoco es legible en un
teléfono.

Consecuencia que salió sola: **abrir un módulo dejó de ser cambiar de pestaña y
pasó a ser empujar una ruta**, y eso destapó un fallo de tema que llevaba meses
escondido (§8, ficha del módulo 3). Un cambio estructural enseña cosas que no se
veían, y no por el cambio en sí: por lo que dejó de estar oculto.

### 5.2 El lanzador no debe reescribir la matriz de permisos

Si la lista de módulos se decide en Dart, es una segunda copia de la matriz de
`role-permissions.config.js`, y las dos se van a desincronizar. El síntoma es
el peor posible: un supervisor ve "Recolecciones" en su inicio, la toca, y la
API le contesta 403.

**Lo que se hizo:** un endpoint nuevo, `GET /auth/permisos`, que devuelve qué
recursos puede leer y escribir el token actual. El lanzador se dibuja con esa
respuesta. Tres consecuencias buenas:

- La matriz tiene **una sola fuente de verdad**, que ya está probada.
- Añadir un módulo al backend lo hace aparecer solo en los roles que lo tienen.
- Si el móvil dice que algo está permitido y la API lo rechaza, hay un bug
  detectable, en vez de una sorpresa.

Fue un endpoint pequeño (doce líneas de servicio, una ruta) y evitaba copiar una
matriz de 7 roles por 13 recursos a Dart. **Era el trabajo previo más rentable de
toda la lista, y salió más rentable de lo previsto:** además de resolver el
lanzador, destapó que `GET /unidades?tipo=furgon` no filtraba nada (§8).

---

## 6. Lo que falta en el backend

Son tres cosas. Dos ya estaban anotadas; la tercera la encontré al medir, no al
leer.

### 6.1 ✅ `PUT /proveedores/:id` deja escribir `rutaId` a su antojo

**Encontrado probando la API, no leyendo el código.** El modelo dice en qué ruta
está un proveedor en dos sitios a la vez:

- `proveedor.ruta_id`
- la fila en `ruta_parada` (`ruta_id`, `proveedor_id`, `orden`)

`ruta.service` mantiene los dos sincronizados **cuando se usan los endpoints de
paradas** (`POST /rutas/:id/paradas` pone `proveedor.ruta_id`; `DELETE` lo deja
en nulo). Pero `PUT /proveedores/:id` acepta `rutaId` y lo escribe sin tocar
`ruta_parada`.

Lo comprobé contra la API:

```text
POST /rutas/3/paradas  {proveedorId: 6}  ->  parada en la ruta 3
PUT  /proveedores/6    {rutaId: 1}       ->  ACEPTADO

proveedor.ruta_id          = 1
parada real del proveedor  = ruta 3
paradas que declara la ruta 1 = no lo incluye
```

Queda un proveedor que dice estar en la ruta 1 y cuya parada está en la 3. Las
dos pantallas que lo muestren van a discrepar, y no hay forma de saber cuál
miente.

**Arreglo, con el patrón que ya existe:** `PUT /proveedores/:id` rechaza
`rutaId` con 400, igual que `PUT /usuarios/:id` rechaza `rolId`. La pertenencia
a una ruta es de `POST /rutas/:id/paradas` y `DELETE /rutas/:id/paradas/:id`,
que son los que saben mantener las dos cosas de acuerdo.

También conviene revisar el mismo patrón en `zona.ruta_id`: ¿lo puede escribir
`PUT /zonas/:id`? La misma pregunta, probablemente la misma respuesta.

**Arreglado** al cerrar el módulo 3: `ProveedorService._sinRuta()` rechaza el
campo en el alta **y** en la edición, con dos pruebas que reproducen el caso
bueno y malo.

### 6.2 🟡 Reordenar imágenes de la galería

La columna `orden` existe, la galería la respeta al listar, y no hay forma de
cambiarla: falta un `PATCH /uploads/api/imagen/:id`. No bloquea ningún módulo;
se puede hacer cuando la primera pantalla de galería toque.

### 6.3 ✅ `GET /auth/permisos`

El de §5.2. Hecho antes de empezar el módulo 3, como se recomendaba. Hay una
prueba que no solo comprueba que responda, sino que **recorre los recursos uno a
uno contra la API real** y verifica que lo que promete el endpoint y lo que hace
`authorizeMiddleware` coinciden. Si alguien cambia la matriz en un sitio y no en
el otro, esa prueba falla.

---

## 7. Qué significa "un módulo terminado"

Un módulo está terminado cuando las ocho cosas están:

- [ ] **Cada filtro de la lista existe en el backend.** Un filtro que solo está en
      la pantalla es una mentira: el servidor devuelve la lista entera y quien lo
      usa cree que está viendo una parte. Antes de dibujar un filtro, se
      declara en `_filtros()` del servicio y se prueba que llega.
- [ ] La pantalla de lista: paginada, con filtro por texto y por los campos que
      el backend acepte, y con un camino para volver a "todos" los filtros.
- [ ] El formulario de alta y el de edición, con validación en el cliente y el
      error del servidor mostrado donde se cometió.
- [ ] El botón de la galería, si el recurso tiene imágenes, con
      `SelectorImagen` y el `recurso` correcto.
- [ ] El lanzador de Inicio enseña el módulo **solo a quien puede usarlo**, y la
      respuesta viene de `GET /auth/permisos`.
- [ ] Un caso en el que el módulo **no** aparece o **no** se abre, para el rol
      que no tiene permiso.
- [ ] Pruebas Flutter del módulo: la lista filtra, la paginación avanza, y el
      camino de vuelta a "todos" funciona.
- [ ] `flutter analyze` limpio y la suite completa en verde.

Si una de las ocho falla, el módulo sigue abierto. Medio módulo es peor que
ninguno: ocupa sitio en el menú y no se puede usar.

---

## 8. Fichas de módulo

Una ficha por módulo: pantallas, campos, filtros y quién la ve. Se rellena
**antes** de programarla, para decidir sobre la mesa y no a mitad de la pantalla.
Cada módulo lleva además su estado, para saber de un vistazo cuál está.

### Módulo 3 — Unidades ✅ terminado

**Endpoints (7, ya existían):** `GET /unidades`, `GET /unidades/tipo/{tipo}`,
`GET /unidades/nombre/{nombre}`, `GET /unidades/{id}`, `POST`, `PUT`, `DELETE`.

**Campos:** `nombre` · `tipo` (furgon/motocarga) · `capacidad` (litros, decimal)
· `cerrado` · `activo` · `acopiadorId` (opcional).

`cerrado` y `activo` son campos distintos y no se pueden confundir: `cerrado` es
el estado de hoy, `activo` es si la unidad existe en el calendario.

**Lista:** búsqueda por nombre, filtro por tipo, casillas de inactivas y
cerradas, paginación de 10 y acciones de editar y eliminar.

**Formulario:** los seis campos. El selector de chófer **solo aparece si el rol
puede leer `usuarios`**, que es admin y superadmin: un supervisor puede escribir
unidades pero no listar usuarios, así que no puede elegir chófer. Mostrarle un
selector que acabaría en 403 es peor que no mostrárselo.

**Lo que se descubrió al construirlo** (y aplica a los módulos que quedan):

- 🔴 **Los filtros de la lista no filtraban.** `GET /unidades?tipo=motocarga`
  devolvía las cuatro unidades, dos de ellas furgón. Nueve servicios heredaban
  `list` de la base y descartaban cualquier filtro de la query en silencio. Ahora
  `BaseService` rechaza lo que no reconoce con un 400 que dice qué admite, y cada
  servicio declara lo suyo en `_filtros()`. **Los ocho servicios restantes
  declaran cero filtros**: cuando se llegue a ellos hay que dárselos, o la
  pantalla tendrá filtros que el servidor ignora.
- 🔴 **`PUT /proveedores/:id` escribía `ruta_id`** dejando al proveedor diciendo
  que estaba en una ruta con su parada en otra (§6.1, ya arreglado).
- 🟡 **El tema mezclaba `inherit` en los estilos** y reventaba la animación al
  empujar una página con barra de navegación. No se veía porque hasta ahora
  ninguna pantalla se empujaba: los módulos vivían en pestañas. Ahora
  `navTitleTextStyle` y `tabLabelTextStyle` van con `inherit: false`.

**Estado:** era 91/91 cuando se escribió; hoy el proyecto entero va 259/259 y
`flutter analyze` limpio.

---

## Reglas que salieron de los módulos 5 y 6

Son de las que no se ven leyendo el código, y por eso las apunto aquí:

- 🔴 **Un guardián en la capa equivocada no protege nada.** El rechazo de
  filtros desconocidos estaba en `BaseService.list`, y `ruta`, `recorrido` y
  `usuario` sobrescriben `list`: nunca pasaban por ahí. `/rutas?busqueda=zzzz`
  devolvía las seis rutas sin avisar. Va en `BaseController.list`, que es el
  único punto por el que pasan todos. **Y un sitio donde un hijo puede
  esquivarlo no es "un solo sitio".**
- 🔴 **Declarar un filtro no es aplicarlo.** `RutaService` declaraba `busqueda`
  en `_filtros()` y el endpoint aceptaba el parámetro, pero `list` lo expandía
  suelto y Sequelize lo ignoraba porque no iba dentro de `where`. Un filtro
  declarado y no aplicado es peor que uno inexistente: el 400 deja de saltar y la
  lista miente en silencio.
- 🔴 **`BaseService.list` no puede rechazar nada.** También la llaman otros
  servicios con sus propias opciones (`where`, `include`, `order`), que no son
  filtros de usuario. Cuando lo hacía, `GET` devolvía 500 y —peor— el `where` del
  llamante se perdía porque el de los filtros lo pisaba.
- 🔴 **`node --check` no basta.** `regla is not defined` con un `const regla`
  inmediatamente encima, en un archivo con la sangría correcta y los bytes
  correctos: `node --check` lo daba por bueno y el método fallaba en cuanto se
  ejecutaba. **Solo ejecutarlo lo delata.**
- 🔴 **Declarar cero filtros rompe cualquier filtro dibujado.** Ocho servicios
  seguían sin declarar, y con el rechazo nuevo cualquier filtro sería un 400.

---

## Nota sobre el lanzador

El lanzador de Inicio es un `ListView`: solo construye lo que cabe en pantalla.
Con seis módulos, "Usuarios" y "Cerrar sesión" quedan por debajo del pliegue y
hay que desplazarse hasta ellos. Las pruebas lo hacen, porque es lo que hace el
usuario; no usan `skipOffstage`, que daría verde sin comprobar nada.

**Pendiente de decidir cuando se vea en el móvil:** con trece módulos la lista
será larga. Opciones: agrupar por secciones, un buscador, o una cuadrícula de
iconos. Es una decisión de interfaz, no de código.

---

## Módulo 4 — Productos ✅ terminado

**Endpoints (7, ya existían):** `GET /productos`, `GET /productos/nombre/{nombre}`,
`GET /productos/{id}`, `POST`, `PUT /productos/{id}/imagen`, `PUT /productos/{id}`,
`DELETE`.

**Campos:** `nombre` · `descripción` · `unidadMedida` · `precioVenta` · `imagen` ·
`estado`.

**Lista:** búsqueda por nombre **o descripción**, filtro por unidad de medida,
casilla de inactivos, paginación, y la imagen principal en cada fila.

**Formulario:** los campos, con el `SelectorImagen` al final. Este módulo es el
primero que usa la galería con un recurso que no es el usuario, que es justo lo
que faltaba para comprobar que de verdad era genérica.

**Dos decisiones que se pueden cambiar:**

- **`unidadMedida` son sugerencias, no un desplegable cerrado.** El servidor
  acepta cualquier texto de hasta 30 caracteres. Un selector obligaría a adivinar
  una lista que no existe. Se dejaron atajos —`unidad`, `litro`, `kilo`— sobre un
  campo de escritura libre.
- **En el alta no aparece la galería.** Una imagen necesita un producto al que
  colgarse, y en el alta todavía no existe. En cuanto se guarda, aparece.

**Lo que se descubrió al construirlo:**

- 🟡 **`AppTextField` no admitía varias líneas**, y una descripción sí las
  necesita. Se le añadió `maxLines`, **con 1 por defecto**, así que ningún campo
  existente cambia de aspecto. Es un widget compartido por todos los módulos:
  tocarlo mal rompe cinco pantallas.
- 🟡 **`GET /productos?busqueda=fresca` no filtraba nada.** No declara filtros
  en `_filtros()`, así que el rechazo nuevo respondía 400. Declarados y
  comprobados contra la API viva: `busqueda` (nombre o descripción), `estado` y
  `unidadMedida`.

**Estado:** era 61/61 (eran 50) cuando se escribió; hoy el proyecto entero va
259/259 y `flutter analyze` limpio.

### Módulo 5 — Rutas ✅ terminado (sin paradas)

**Lo hecho:** listado, alta, edición, filtros y pantalla de detalle.
**Lo pendiente:** las paradas. Dependen del **módulo 7 (Proveedores)**: una
parada es un proveedor en un orden, y no hay cuáles elegir hasta que exista.

**Aviso para el módulo 7:** cada parada apunta a un proveedor en **dos sitios a
la vez** —la fila en `ruta_parada` y la columna `proveedor.ruta_id. Y hay un
detalle fino medido, no deducido:

```
POST /proveedores { ..., rutaId: 1 }   → 400  "La ruta no se cambia con este endpoint"
POST /proveedores { ..., rutaId: null } → 400  ← también
POST /proveedores { ... }                → 201  (omitiendo la clave)
```

El servicio compara con `undefined`, y en JSON `"rutaId": null` es `null`, no
`undefined`. **El formulario no puede mandar la clave ni siquiera con `null`.**
Es lo contrario que en Zonas, donde mandar `null` sí desasigna.

### Módulo 6 — Zonas ✅ terminado

**Endpoints (7):** `GET /zonas`, `/zonas/nombre/{n}`, `/zonas/unidad/{u}`,
`GET /zonas/{id}`, `POST`, `PUT`, `DELETE`.

**Filtros declarados:** `busqueda` (nombre), `activo`, `rutaId`, `unidadId`.
Antes no declaraba ninguno y los cinco devolvían 400.

**Regla incómoda, la de Zonas:** `rutaId` y `unidadId` son opcionales
(`allowNull: true`), y **`null` desasigna mientras que omitir el campo deja el
valor anterior**. El formulario manda siempre las dos claves, precisamente para
que "quitar la ruta" sea una acción y no un olvido. Hay dos pruebas que lo
comprueban mirando lo que llega al servidor, en las dos direcciones.

**El formulario pide rutas y unidades a sus módulos.** Se leen de sus
repositorios en vez de copiar los datos, para que un cambio en Rutas o Unidades
llegue a Zonas sin tocar este módulo.

### Lo que se descubrió al construir Zonas

- 🔴 **`direccion` del proveedor era de solo escritura.** La columna existía y se
  guardaba, pero el DTO no la devolvía. Quien abriera a editar un proveedor veía
  el campo vacío aunque estuviera relleno, y al guardar de nuevo lo mandaba
  vacío: **el segundo guardado borraba lo que el primero había escrito.**
- 🟡 **El DTO es un contrato, no un resumen.** Lo que no está en el DTO no existe
  para la app, por más que esté en la base y se pueda escribir. Merece una
  prueba por campo.

---

## Módulo 5 — Rutas ⏳ en curso

**Lo que sí depende solo de sí mismo:** el listado, el alta y la edición de la
ruta — nombre, código, descripción, horarios y si está activa.

**Lo que no:** las paradas. Una parada es un proveedor en un orden, así que
`agregarParada`, `quitarParada` y `reordenarParadas` dependen del **módulo 7
(Proveedores)**.

**Recomendación:** hacer ahora la ruta y dejar las paradas para cuando estén los
proveedores. Esperar al módulo 7 para hacer las rutas bloquearía dos módulos por
una dependencia, y las rutas no dependen de nadie.

**Aviso para cuando llegue el módulo 7:** cada parada apunta a un proveedor en
**dos sitios a la vez** —la fila en `ruta_parada` y la columna `proveedor.ruta_id`.
El backend lo mantiene sincronizado cuando se usan sus endpoints, y el agujero por
el que se desincronizaba ya está cerrado (§6.1). Esa sincronización es lo
**primero** que hay que probar, no lo último.

---

## 8-bis. Reglas que salieron de los módulos 10 y 11

### 8-bis.1 Las relaciones se declaran en un método, no sobrescribiendo el servicio

`BaseService` no aplicaba ningún `include`. Los servicios que necesitaban nombres
—`recorrido`, `ruta`, `usuario`— sobrescribían `list` y `findById` enteros para
meterlo a mano, y **`recolecciones` nunca lo hizo**: su lista devolvía
`proveedor: null` y la app tenía que enseñar "Proveedor #1" donde debería decir
"Juan Pérez". Cuatro `null` por fila, en un módulo que ya estaba dado por bueno.

Se añadió `_incluir()` a `BaseService` y `_opcionesDeLectura()`, que lo aplica a
`list`, `findById`, `listByField` y `findOneByField`. `create` y `update` no
pueden devolver relaciones porque la fila acaba de insertarse, así que recargan
con `_conRelaciones()`: sin eso la respuesta a un alta es peor que la de un `GET`
de esa misma fila.

`juntaWhere` fusiona el `include` del llamante con el de `_incluir()`, **sin
duplicar** asociación: si no, un servicio que pase `ruta` a mano y también lo
declare en `_incluir()` la metería dos veces, y Sequelize no lo perdona.

### 8-bis.2 Dos filtros pueden escribir en la misma columna

`_whereDeFiltros` juntaba los filtros con `Object.assign`. `desde` y `hasta`
escriben los dos en `fecha` —uno con `[Op.gte]`, el otro con `[Op.lte]`—, así que
**el segundo machacaba al primero sin dejar error**.

Medido: `GET /calidad?desde=2027-01-01&hasta=2027-12-31` devolvía los controles
de 2026. Parecía funcionar porque la tabla estaba vacía y todo daba 0; en cuanto
hubo un control, se vio que el rango no filtraba **nada**. Una prueba sobre una
tabla vacía no prueba nada: hay que repetir la medición con datos dentro.

Ahora se usa `juntaWhere`, que acumula las claves de objeto en vez de
reemplazarlas —**incluidas las de símbolo**, porque los operadores de Sequelize
son precisamente símbolos y son la mitad del motivo.

### 8-bis.3 Una recolección, un análisis

`recoleccionId` es `unique` en `control_calidad`. Un segundo análisis de la misma
recogida da 400, y **mover** uno existente a una recolección que ya tiene otro
también: la unicidad la impone la base, no el servicio, así que se cumple igual al
editar. El desplegable del formulario sale **solo con las recolecciones libres**,
cruciendo `/calidad` y `/recolecciones` en dos peticiones y no `N`.

### 8-bis.4 Guardar y enviar no son lo mismo

En Notificaciones hay **dos endpoints**, no un interruptor: `POST /notificaciones`
deja un borrador (`enviada: false`, sin fecha) y `POST /notificaciones/enviar` lo
manda y le pone la fecha. El envío ocurre **antes** de guardar, así que si el
envío falla no queda nada guardado. Marcar como leída es un `PUT` a secas: no hay
endpoint aparte.

**No se manda `enviada` en un `PUT` nunca.** El servidor no borra `fechaEnvio`
cuando la pone a `false`, así que desmandar deja un "borrador" con fecha de
envío. Editar una ya enviada **sí** se acepta —el servidor no lo bloquea— y la app
lo avisa sin impedirlo, porque bloquearlo sería inventarse una regla que el
backend no tiene.

### 8-bis.5 Lo pendiente de decidir

- **`cantidad` admite negativos y cero en el backend.** Medido: `-5`, `0` y `0.001`
  se aceptan. La app lo bloquea; el backend sigue.
- **`cancelar` un recorrido no exige ser el acopiador**, a diferencia de `iniciar`
  y `finalizar`.
- **Asistencias permite duplicados exactos**: el mismo proveedor, el mismo evento y
  la misma fecha se registran dos veces y el servidor lo acepta. Es doble firma.
  No se ha tocado por ser decisión de negocio, pero queda medido.

---

## 8-ter. Fichas de los módulos 12 y 13

### Módulo 12 - Asistencias ✅ terminado

Quién asistió a qué evento, qué día y **cómo se anotó**. El detalle que
distingue este módulo de todos los anteriores: su campo principal es **texto
libre**, no un catálogo cerrado.

- `evento` es un `VARCHAR(150)` que escribe quien registra la asistencia. No hay
  desplegable posible, así que el formulario tiene un campo de texto y la lista
  filtra **por fragmento**, no por coincidencia exacta.
- `registradoPor` es un `ENUM` de dos valores —`QR` y `manual`— y es
  **obligatorio sin valor por defecto en la base**. Sin él el alta falla con un
  400 hablando de un campo que el usuario no vio nunca. Por eso la pantalla lo
  pone siempre, y el valor por defecto es `manual`: quien abre esa pantalla está
  apuntando, no escaneando.
- Los **cinco campos son obligatorios** y `usuarioId` sale de la sesión, igual que
  en Recolecciones y Calidad.

Filtros, todos declarados en `_filtros()` del servicio: `evento` (por fragmento),
`registradoPor`, `proveedorId`, `usuarioId`, `fecha`, `desde` y `hasta`.

Lo que hace la lista y que no hace ninguna otra: **el resumen de cuántas se
escanearon y cuántas se apuntaron de memoria**. Es la diferencia entre un registro
fiable y una anotación de memoria, y hay que poder verla sin exportar nada.

### Módulo 13 - Reportes ✅ terminado

Cuatro endpoints, **todos de solo lectura y todos bajo el mismo permiso**
(`reportes`). Deliberado: una pantalla que mezclase módulos con permisos
distintos devolvería "no se ve" sin decir cuál, y eso no se puede diagnosticar.

Seisin pestañas en vez de una por endpoint, y **cada reporte se pide solo cuando
se abre**: son cuatro consultas distintas contra tablas distintas, y pedirlas
todas al entrar haría cuatro viajes para enseñar uno.

Tres reglas que salieron de medirlo contra la API:

- **`porcentajeDiferencia` es `null` cuando no se recogió nada en el campo**,
  aunque la diferencia sea enorme. Dividir entre cero daría `Infinity` o `NaN`.
  No hay porcentaje, no un `0 %`: la pantalla lo distingue.
- **Un proveedor que no existe devuelve una fila con `muestras: 0`, no un 404.**
  Medido con el proveedor 9999. Una fila con cero muestras de alguien que no
  existe parece un análisis vacío y no lo que es, así que la app lo comprueba
  contra la lista de proveedores antes de pedirlo.
- **`muestras: 0` no es "la leche está mal": es que nadie ha analizado nada.** Los
  siete promedios vienen a `null` en ese caso, y enseñar un `0,00 %` de grasa se
  leería como un análisis. La pantalla lo dice con otras palabras.

Y un detalle de formato que hay que mirar dos veces: los flotantes llegan como
`52.501000000000005`. Todo el formateo vive en el dominio, no en las pantallas,
porque cada una reescribir el `toStringAsFixed` es donde se cuelan los ceros de
más y las comas perdidas.

### 8-ter.1 Un fallo del analizador que no era código

Durante este módulo, `flutter analyze` dijo que `AppTheme.dados` no existía
en `AppTheme`, en un fichero nuevo. **El código era correcto** y el mismo expresión
en otros veinte ficheros del proyecto pasaba sin un error.

Lo que se descartó, por si vuelve: imports byte a byte idénticos a los de un
fichero que sí compila; sin BOM; finales de línea LF; sin homoglifos; con prefijo
de import; con import de paquete; con otras profundidades de ruta; `flutter clean`
y `pub get` desde cero. Un fichero mínimo con esa única línea **también fallaba**,
y una copia exacta de un fichero que funciona **también pasaba**. Era
determinista —cinco veces seguidas, igual— y dependía del contenido, pero no del
código.

Se resolvió con `CupertinoColors.systemGroupedBackground`, que es **el mismo
color** que resuelve el tema (`0xFFF2F2F7` en claro) y además respeta el modo
oscuro. Queda anotado en el fichero. Si vuelve a aparecer, **no es el código**.

---

## 8-quater. Lo que salió de los cuatro arreglos del 15 de octubre

No fue un módulo nuevo: fueron cuatro cosas que no funcionaban. Tres de ellas
tenían una causa que no era visible desde la pantalla.

### El interruptor del ayudante no se podía encender

**Síntoma:** en Nuevo recorrido, el interruptor "Lleva ayudante" no respondía.
**Causa:** su valor no era estado, se calculaba: `!ayudanteCompleto ||
ayudanteHayAlgo`, es decir "¿hay algo escrito en los campos?". Al pulsarlo sin
haber escrito nada, la respuesta seguía siendo `false` y la casilla se saltaba
sola.

**La lección general:** *un control cuyo valor se deriva de otros campos no se
puede cambiar antes de rellenar esos campos, que es justo lo contrario de lo que
se espera de un interruptor.* Si el interruptor esconde los campos que él mismo
mide, el ciclo está cerrado y no hay forma de salir.

### `?busqueda=` no filtraba nada. En ningún módulo

**Síntoma:** buscar "Perez" en Proveedores devolvía los seis proveedores.
**Causa:** el guard que decide si el `where` está vacío usaba
`Object.keys(where).length > 0`. **`Object.keys()` no cuenta las claves de
símbolo**, y la búsqueda se construye justamente con `{ [Op.or]: [...] }`, que es
una clave de símbolo. El `where` salía vacío, el guard lo tiraba entero y la
petición se hacía sin filtro.

Medido antes y después: `?busqueda=Perez` pasa de 6 proveedores a 1, y
`?busqueda=zzzznada` pasa de 6 a 0.

**La lección general:** *`Object.keys` está mal para cualquier cosa que pueda
contener claves de símbolo.* Sequelize usa símbolos para los operadores, así que
cualquier `where` con `Op.or`, `Op.and`, `Op.gt`... se ve afectado. Está arreglado
en `base.service` y en `ruta.service`, que son los dos que tenían el guard.

### Las fechas inválidas devolvían 500

**Síntoma:** mandar `fecha: ""` en Asistencias, Recolecciones, Recorridos o
Eventos respondía "Error interno del servidor".
**Causa:** `allowNull: false` **no coge la cadena vacía**, porque `""` no es
`null`. Sequelize la pasaba a MySQL, que la convertía en `Invalid date` y
rechazaba la escritura con un error de base de datos — que el middleware trata
como no controlado.

Ahora los seis campos de fecha llevan `isDate` y devuelven 400 con el formato
esperado. Mismo patrón que el de los `ENUM` de la sección anterior: **el valor
equivocado tiene que pararse antes de la base de datos.**

### La prueba de referencias comprobaba una clave que nadie manda

**Síntoma:** al añadir la asociación asistencia → evento, la prueba "toda
asociación `belongsTo` con planta queda declarada" exigía declarar
`eventoRelacionId`.
**Causa, y esta es la buena:** el criterio de la prueba era `${alias}Id`, o sea el
nombre de la asociación más "Id". Pero el servicio de validación lee
**`datos[clave]`**, el nombre del atributo que manda el cliente. Las dos cosas solo
coinciden mientras el alias y la columna se llamen igual.

Habría bastado con declarar `eventoRelacionId` —una clave que el cliente no manda
nunca— y la prueba habría pasado con la validación **sin ejecutarse**. Comprobado
en el contenedor: el mapa tenía `proveedorId, usuarioId` y nada más.

Arreglado usando `asociacion.foreignKey`, que sí es el atributo. Y comprobado
contra la API: una asistencia con un `eventoId` de otra planta sale con
`el campo eventoId indicada (999999) no existe en esta planta`.

**La lección general:** *una prueba de cobertura puede cubrir algo que no existe.*
Pasó porque todas las asociaciones anteriores se llamaba como su columna. Merece
la pena mirar el criterio de una prueba verde antes de darla por buena.

### La planta no venía en la sesión

El login solo mandaba `plantaId`. Sin nombre no hay etiqueta posible en ninguna
pantalla, y pedirlo aparte a `/plantas` **no sirve**: un recolector no tiene
`plantas: read` y le daría un 403.

Arreglado en el servicio de autenticación, que ya lo cargaba en `/perfil` y solo
se olvidaba en el login. Comprobado entrando como acopiador, que es el rol con
menos permisos.

### Y una decisión que conviene tener presente

**En Asistencias conviven el texto del evento y el enlace al catálogo.** El texto
sigue siendo obligatorio y no se ha tocado; el `evento_id` es opcional y nuevo.

Motivo: hay asistencias ya escritas con textos como "reunion de ruta", en
minúsculas y sin tilde, que no corresponden a ningún evento del catálogo. Cambiar
el `allowNull` o inventar un evento al que apunta cada fila sería **falsear
datos que existen**. Las asistencias viejas siguen enseñando su texto, las nuevas
enseñan el nombre del catálogo cuando lo tienen.

---

## 8-quinque. Plantas y el cambio de planta

Lo pidió el usuario al ver en Inicio la tarjeta de "Todas las plantas / HUA": esa
tarjeta **no era pulsable**. No era un botón roto —nunca tuvo `onTap`— sino un
`AppCard` de texto que parecía un control.

**El backend ya estaba entero**, y eso conviene dejarlo escrito porque cambia lo
que había que hacer: `/plantas` tenía el CRUD, `POST /auth/planta` emitía un token
nuevo y el aislamiento funcionaba. Lo que faltaba era solo la app.

Comprobado contra la API viva, creando una planta de prueba: al cambiar a ella,
proveedores y eventos devuelven **0**, y al volver atrás vuelven a estar. Lo que
aísla es el token, no un filtro de pantalla.

### Dos decisiones

**La tarjeta solo es pulsable si hay a dónde ir.** Con una sola planta —el caso de
cualquier admin— no lleva flecha ni responde. Ponerle un dedo encima y una flecha
cuando no hay cambio posible sería prometer una acción que no ocurre, que es justo
lo que se veía antes.

**El módulo lo ve también el admin, pero solo en lectura.** Se pidió "solo para el
superadmin", y es cierto para escribir: el servidor da `plantas: ['read']` al
admin y `['read', 'write']` al superadmin. Esconder el módulo entero al admin lo
dejaría sin poder ni mirar por dónde trabaja. Se le enseña la lista y se le
oculta el botón de alta, que el servidor rechazaría igual.

### El fallo que salió al hacerlo

`actualizarUsuario` construía `Autenticado(usuario)` sin las plantas ni los
permisos, y eso **tiraba los dos**. Se disparaba justo al cambiar de planta: el
lanzador se quedaba sin módulos y la tarjeta pasaba a decir "Solo tu planta" para
un superadmin.

No se había visto nunca porque el cambio de planta **no se podía hacer desde
ningún sitio** —la tarjeta era inerte— y por eso la línea no llegaba a ejecutarse
con consecuencias. Es la clase de fallo que solo aparece cuando el camino por fin
existe.

### Y la lista de plantas salía vacía, con un 200 delante

Lo.kerasRobin avisó: se creaba una planta y la lista no la teach. Dos fallos en
uno.

**El primero:** la capa de datos leía `cuerpo['items']` cuando `items` vive dentro
de `data`. Daba `null`, la lista salía vacía y **sin ningún aviso**. La API
devolvía las dos plantas con un 200 —comprobado en el log del servidor— y la
pantaña decía que no había ninguna.

**Por qué ninguna prueba lo vio:** `FakePlantaApi` sobrescribe `listar` entero y
devuelve la lista ya construida. El atajo se salta **justo la línea que estaba
mal**. La lección general es esta:

> Un doble que reimplementa el método que quieres probar **no prueba nada de ese
> método**. Solo comprueba que el resto de la app llama al método y usa lo que
> devuelve.

Por eso se añadió `planta_api_test.dart`: mueve el `Dio` de verdad con un
adaptador que devuelve el JSON **copiado de una respuesta real del servidor**, y
ejercita la traducción entera.

**El segundo era peor:** la pantalla no tenía `AppErrorBanner`. Una petición que
fallaba —un 403, una red caída— pintaba "No hay ninguna planta", que hace creer
que no hay nada cuando lo que hay es que no se ha podido mirar. Todas las demás
listas de la app lo tienen y aquí se olvidó.

---

## 8-sexis. Una hoja en blanco y una API que no arrancaba

Dos fallos que aparecieron el mismo día, y los dos salieron de la misma idea:
**dar por hecho que los datos no cambian.**

### Un desplegable sin opciones abre una pantalla en blanco

El usuario, al crear un recorrido en la planta que acababa de crear, tocó **RUTA**
y le salió una hoja blanca. Sin opciones, sin un "Listo", sin una palabra.

La causa no era un fallo: la planta nueva no tenía ninguna ruta. **La rueda sin
opciones abre una hoja vacía**, y una pantalla vacía parece rota —cuando lo
único que pasa es que no hay nada.

> Un componente que no tiene nada que ofrecer **no debería fingir que sí**. O dice
> "aquí no hay nada" con palabras, o no se abre.

`AppSelector` ahora lleva `onTap: items.isEmpty ? null : ...`. El campo de al lado
ya decía "No hay rutas"; ahora además **no se abre una hoja que no lleva a
ninguna parte**.

Comprobado antes de tocar nada: `app_selector_test.dart` abre el desplegable con
las cuatro rutas de verdad y comprueba que se ven y que son tocables
(`hitTestable`, no `findsOneWidget` —este último encuentra también lo que está
fuera de la pantalla).

### El total de rutas contaba filas, no rutas

Mirando el log del servidor se veía otra cosa: el móvil pedía `/rutas` y recibía
**248 bytes**, una lista vacía con un 200. Desde el PC las mismas rutas venían con
datos. No era la app: **el móvil estaba en otra planta**, la que había creado
después de cambiar de alcance.

Pero al medir los números apareció un fallo de verdad:

| | rutas en la planta 1 | lo que decía la API |
|---|---|---|
| `total` | 4 | **6** |
| `limite=3`, página 1 | — | Este, Norte, Oeste |
| `limite=3`, página 2 | — | Sur *(y eso es todo)* |

La lista de rutas incluye `paradas` para enseñar cuántas tiene cada una, y esa
relación es un `hasMany`: **el join multiplica las filas**. Una ruta con tres
paradas sale tres veces, y un `COUNT(*)` cuenta filas de la tabla, no rutas.

El arreglo cabe en dos líneas —y el camino hasta él es lo que hay que recordar:

```js
// ANTES: se ignoraba, en silencio
count: { distinct: true, col: 'ruta.id' },

// AHORA
distinct: true,
col: 'id',
```

> **Sequelize 6 no lee `count.distinct`.** `findAndCountAll` pasa las opciones
> enteras a `Model.count`, y `count` lee `options.distinct` y `options.col` del
> **nivel superior**. Un `count: { ... }` anidado no da error: simplemente no hace
> nada, y el total sigue inflado.
>
> Y `col` va **sin tabla**: si hay `include`, `count` ya le pone delante el
> nombre del modelo. Escribir `ruta.id` a mano acaba en `ruta.ruta.id`.

Comprobado en SQL antes de tocar código, que es lo que separates el *"el join
multiplica"* de cualquier otra explicación:

```sql
COUNT(*)                 -> 6
COUNT(DISTINCT ruta.id)  -> 4
```

### La migración que tumbaba la API entera

Al reconstruir para probar el arreglo anterior, **la API no arrancó**:

```
SequelizeUniqueConstraintError: Duplicate entry 'Planta Ecológica Huata'
for key 'planta.nombre'
```

La migración `planta: registrar la planta principal` buscaba la planta por su
código `HUA`, y si no la encontraba la insertaba. El usuario **había cambiado ese
código a `HUATA` desde la app**, porque el campo es editable. La migración no se
enteraba de que la planta seguía ahí, la insertaba otra vez y reventaba contra el índice
único. **El servidor no arrancaba y la app se quedaba sin conexión entera**, sin
importar qué módulo se abriera.

Dos arreglos:

1. **La migración pregunta "¿hay alguna planta?", no "¿hay una planta con código
   `HUA`?"**. Si hay alguna, ya se registró. Da igual cómo se llame.

2. **Un registro de lo que ya corrió** (tabla `migracion_aplicada`). Una migración
   que ya corrió una vez no vuelve a correr, diga lo que diga la tabla.

Lo segundo es lo importante, y va más allá de esta planta:

> **Una migración que decide mirando los datos se rompe en cuanto los datos
> cambian.** Y aquí los cambia la app, desde el móvil, con un formulario.
>
> La regla general: `antesDe` puede mirar el **esquema** —qué columnas hay— pero
> si puede mirar **filas**, necesita además un registro de que ya pasó. El registro
> es la verdad; `antesDe` solo decide de las que no se han visto nunca.

`idDePlantaPrincipal()` resuelve ahora la planta por código y, si ya no está, cae
a la más antigua. El código `HUA` solo sirve para el arranque en frío.

Cubierto en `migraciones.test.js`: cambiar el código de la planta **y** correr
las migraciones no revoca. El arranque en frío —base vacía— también lo recorre esa
misma prueba, contra una base que crea y borra ella.

### Cómo salió la primera versión de esa prueba: envenenó la suite entera

La primera versión de `migraciones.test.js` hacía lo obvio: renombraba la planta
principal de la base compartida, comprobaba que las migraciones no reventaban y la
renombraba de vuelta en el `afterAll`. Suena bien y es exactamente lo que no hay
que hacer.

Dejó **35 pruebas rotas en cinco suites**, y solo dos eran suyas:

| suite | lo que veía |
|---|---|
| `rutas.conteo` (6) | `rutaParada.proveedorId cannot be null` — error propio |
| `rutas` (23) | `Ejecuta el seed primero` — no encontraba la planta `HUA` |
| `perfil` (4) | esperaba `HUA`, recibió `RENOMBRADA` |
| `reports` (6) | esperaba la planta 12, recibió la 1 |
| `migraciones` (1) | `codigo must be unique` al restaurar |

Las cuatro últimas no tenían nada que ver con su prueba. Todas buscaban la planta
por `codigo: 'HUA'`, y como ya no se llamaba así, acababan señalando otra.

> **Una prueba que cambia datos compartidos puede romper suites que no toca, y el
> fallo se lee como si fuera suyo.** El culpable aparece en el resumen de Jest
> como una línea; el motivo, en otra parte.

Dos reglas que salen de ahí:

1. **Si la prueba necesita un estado que la base compartida no tiene, que se lo
   haga ella.** `crearBaseConDatosViejos` + `eliminarBase` ya existen para eso, y
   `migration.legacy.test.js` es el ejemplo: migra una base aparte, en un proceso
   hijo, sin tocar la de nadie.
2. **Restaurar en el `afterAll` no es un seguro.** Si el `afterAll` falla —y aquí
   falló, por una colisión de códigos que él mismo había provocado—, el estado
   se queda sucio para todo lo que venga después. Ejecutar con `--runInBand` lo
   hace peor, porque las suites se encadenan en el mismo proceso.

Y una más, sobre la suite en sí: `574 - 6 = 568`. Las pruebas que fallaban eran
las mías y ninguna más, pero eso no se sabe hasta el final. Con las suites en
verde menos las nuevas se sabe mucho antes, y sale más barato.

---

## 9. Lo que no recomiendo

- **Hacer Reportes pronto.** Se reescribe. Siempre. *(Se acabó haciendo, en el
  módulo 13, y salió bien —pero no por llegar pronto: por no mezclarlo con nada.
  Ver la ficha del módulo 13.)*
- **Un módulo "de todo": una pantalla con productos, proveedores y
  calidades.** Mezcla permisos distintos en un sitio y hace imposible saber por
  qué algo no se ve.
- **Meter dentro de la ruta de la parada el resto de la lógica del recorrido.**
  La parada es un dato; el recorrido es un proceso con estados. Mantenlos
  separados o el quinto endpoint será imposible de probar.
- **Cambiar la estructura de `features/` con cada módulo.** La primera
  reorganización es la única barata; a partir de ahí, cada módulo paga la deuda
  de la anterior. Si algo hay que cambiar de la estructura, se cambia en el
  primer módulo y se escribe aquí.
- **Escribir una prueba de widget que dependa de arrastrar una rueda.** La rueda
  del `CupertinoPicker` asienta por física y en una prueba depende de cómo se
  reparta el movimiento: el mismo arrastre deja la opción en un sitio o en otro.
  Se probó con tres formas distintas y las tres fallaron. Para lo que importa
  —que el filtro llegue al servidor y que se pueda quitar— se prueba el
  controlador y el contrato de la hoja, no la física de la rueda.

---

## 10. Lo siguiente

Los **13 módulos están hechos**. No queda ninguno de la lista.

Lo que queda es todo lo de la sección 8-bis.5, que son decisiones de negocio y no
código: si `cantidad` acepta negativos, si `cancelar` debería exigir ser el
acopiador, si Asistencias debería rechazar los duplicados y si el `sender` de
notificaciones —que hoy es un simulador— pasa a ser FCM de verdad.

Y una cosa que conviene no perder de vista: **el frontend no está en git**. Los
commits que hay son del backend. Si se pierde esta carpeta, se pierden las trece
pantallas.

```bash
# estado del proyecto en cualquier momento
cd backend  && docker compose --profile test run --rm tests   # 559 pruebas
cd frontend && flutter analyze && flutter test                 # 279 pruebas
```
