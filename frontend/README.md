# MilkData — App móvil

App Flutter para MilkData. Se conecta con la API que vive en `../backend`.

## Requisitos ya instalados en esta máquina

| Herramienta | Ubicación |
| --- | --- |
| Flutter 3.47.6 (stable) | `D:\flutter` |
| Dart 3.13.5 | dentro del SDK de Flutter |
| JDK Temurin 21.0.12.1 | `D:\jdk\jdk-21.0.12.1+1` |
| Android SDK 36.0.0 | `%LOCALAPPDATA%\Android\Sdk` |

Variables de entorno: `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, y el `PATH` con
`D:\flutter\bin`, el bin del JDK y `platform-tools`.

## Comandos

```bash
flutter pub get          # dependencias
flutter analyze          # análisis estático
flutter test             # pruebas
flutter run              # compila y ejecuta en el celular conectado
flutter build apk        # genera el APK en build/app/outputs/flutter-apk/
```

## Correr en un celular físico

1. En el celular: Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación"
   para abrir las opciones de desarrollador, y activa **Depuración USB**.
2. Conéctalo por USB y desbloquea la pantalla.
3. Acepta el diálogo "Permitir depuración USB" en el teléfono.
4. Verifica que Flutter lo ve:

   ```bash
   flutter devices
   ```

   Debe aparecer con su nombre y `android-arm64`. Si sale `unauthorized`, desbloquea el
   teléfono y vuelve a aceptar el diálogo.

La primera compilación descarga Gradle y tarda bastante. Las siguientes son mucho más
rápidas.

## Conectar con la API del backend

El backend corre en `http://localhost:3000`, pero desde el celular `localhost` es el propio
teléfono. Hay dos formas:

- **Con el emulador**: usar `http://10.0.2.2:3000`, que es el alias del host.
- **Con un celular físico**: usar la IP de la máquina en la red local, por ejemplo
  `http://192.168.1.50:3000`. Además el servidor tiene que escuchar en `0.0.0.0`, no solo en
  `localhost`, y el firewall tiene que permitir el puerto 3000.

En un teléfono físico conviene no usar HTTP plano salvo que el backend tenga su
certificado; para desarrollo, la app móvil Android 9+ bloquea el tráfico claro por
defecto y hay que permitirlo explícitamente en el manifiesto.

## Imagenes

Las tres peticiones de `/uploads/api` viven en `features/uploads/`, aparte de auth,
porque las van a usar varios modulos y no solo la sesion.

```text
GET    /uploads/api   limites y recursos admitidos
POST   /uploads/api   multipart: archivo, recurso y opcionalmente id
DELETE /uploads/api   desvincula del registro y borra el archivo
```

Con `id` la operacion es atomica: el backend guarda el archivo y actualiza la
columna `imagen` del registro en el mismo paso. Si la actualizacion falla, el
archivo huerfano se borra, de modo que no quedan imagenes sin dueno.

`SelectorImagen` es el widget reutilizable. Sirve para el perfil de un usuario,
la foto de un producto, la de un proveedor o el logo de una planta porque lo
unico que cambia es el recurso y el id:

```dart
SelectorImagen(
  recurso: RecursoImagen.usuario,
  id: usuario.id,
  rutaActual: usuario.imagen,
)
```

### Decisiones que conviene no deshacer

- **Los limites se piden al servidor**, no se fijan en la app. Si el backend
  cambia el maximo, la app se entera sola en vez de subir un archivo que sera
  rechazado despues de haber-travelado entero por la red.
- **La base guarda una ruta relativa** (`/uploads/1/usuario/abc.png`), no una URL
  absoluta, para que los datos no dependan de donde este desplegado. Quien
  muestra la imagen antepone el servidor con `AppConfig.urlDeImagen`.
- **El borrado va al servidor tambien.** Quitar la foto solo de la base dejaria
  el archivo en disco para siempre.

### Permisos en Android

`READ_MEDIA_IMAGES` y `READ_EXTERNAL_STORAGE` (solo hasta API 32) para la
galeria. La camara **no** lleva permiso: al declararla, Android exige pedirla en
tiempo de ejecucion y, si se deniega, la app se queda sin poder tomar fotos
aunque la galeria siga funcionando. `image_picker` llama a la camara por fuera
de la app, asi que el permiso se lo pide el sistema a la aplicacion de camara.
## Menu de navegacion

`CupertinoTabScaffold` con dos pestañas. Cada una tiene su propio `CupertinoTabView`,
de modo que el historial de navegacion de Inicio no se pisa al usar Auth y al volver
a Inicio la pantalla conserva donde estaba.

```text
Inicio   sesion actual, rol, planta y URL de la API
Auth     las 9 peticiones de /auth, cada una con su formulario
```

## La pestaña Auth

Un formulario por endpoint. Cada tarjeta muestra el metodo con su color (como
Swagger), la ruta y que hace. El resultado de la ultima llamada aparece arriba,
en verde o en rojo, con el mensaje que devolvio la API.

```text
POST /auth/login      GET/PUT /auth/perfil
POST /auth/verify     GET  /auth/plantas
POST /auth/refresh    POST /auth/planta
POST /auth/logout     POST /auth/register
```

Tres detalles que no son obvios:

- **Cambiar de planta guarda el token nuevo.** `POST /auth/planta` devuelve un token
  ligado a esa planta; seguir con el anterior deja a la app operando en la planta
  anterior aunque la pantalla diga otra cosa.
- **Cerrar sesion desde aqui no borra el token.** El endpoint solo confirma: el
  servidor no puede revocarlo porque es un JWT sin estado. Quien lo borra del
  dispositivo es la app, en Inicio.
- **El registro necesita rol admin o superadmin y `plantaId`.** El servidor nunca
  deduce la planta, y un admin de planta que intente crear un superadmin recibe 403.
## Estructura

```text
lib/main.dart          punto de entrada
lib/app.dart          CupertinoApp + menu de pestañas

lib/core/
  config/              URL de la API y timeouts
  error/               AppException y traduccion de errores de Dio
  network/             cliente HTTP, interceptor de token, eventos de sesion
  storage/             token cifrado (Keystore de Android)
  theme/               colores y espaciados

lib/features/<nombre>/
  data/                llamadas HTTP y repositorio
  domain/              modelos
  presentation/        pantallas, widgets y controladores Riverpod

lib/features/uploads/    imagenes: /uploads/api y SelectorImagen

lib/shared/widgets/    AppButton, AppCard, AppTextField, AppErrorBanner

test/widget_test.dart  pruebas de widget
test/helpers/          dobles de prueba, sin red
android/               proyecto Android nativo (Gradle, manifiesto)
```

## Estado

Login contra la API y menu de dos pestañas: Inicio y Auth. La pestaña Auth permite
probar las 9 peticiones de /auth desde el celular.