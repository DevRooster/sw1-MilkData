/// Configuración que se puede cambiar en tiempo de compilación.
///
/// ## A qué dirección apunta la API
///
/// Por defecto, **`http://127.0.0.1:3000`**, y eso quiere decir que el teléfono
/// tiene que estar puenteado con el ordenador:
///
/// ```bash
/// adb reverse tcp:3000 tcp:3000
/// ```
///
/// El puente se cae cada vez que se desenchufa el cable, se reinicia el
/// teléfono o se reinicia el servidor de adb, así que hay que rehacerlo. Sin
/// él, la app ve un tiempo de espera agotado.
///
/// ### Por qué no la IP de la máquina
///
/// Porque es la que menos funciona. La IP de la red local cambia cuando el
/// router reparte, y no es la IP del USB: `172.22.176.1` era la del adaptador
/// virtual de WSL, que el teléfono no sabe alcanzar. Con ella, un APK
/// compilado sin `--dart-define` fallaba siempre con "el servidor tardó
/// demasiado" sin llegar a preguntar a nadie.
///
/// Para probar por WiFi en vez de por USB hace falta la IP de la red local **y**
/// que el cortafuegos permita el puerto 3000, que en este equipo no lo permite.
/// Con el puente no hay cortafuegos de por medio.
///
/// ### Cambiarla sin tocar el código
///
/// ```bash
/// flutter run --dart-define=API_URL=http://192.168.0.87:3000
/// ```
///
/// Cualquier host al que se apunte tiene que estar en la lista de texto plano
/// de `android/app/src/main/res/xml/network_security_config.xml`, o Android
/// descarta la conexión en silencio.
class AppConfig {
  const AppConfig._();

  /// Base de la API. Sin definir, al puerto 3000 del propio teléfono, que solo
  /// sirve con `adb reverse` puesto.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Tiempo máximo para abrir la conexión.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Tiempo máximo de espera de la respuesta.
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Tiempo máximo de envío del cuerpo de la petición.
  static const Duration sendTimeout = Duration(seconds: 15);

  /// URL completa de una imagen guardada por la API.
  ///
  /// La base guarda una ruta relativa (`/uploads/1/usuario/abc.png`) y no una
  /// URL absoluta, para que la base de datos no dependa de dónde esté
  /// desplegada. Quien la muestra es quien tiene que anteponer el servidor.
  ///
  /// Si ya viniera una URL completa o externa se devuelve tal cual, porque la
  /// columna `imagen` también admite imágenes que la API no administra.
  static String urlDeImagen(String? ruta) {
    if (ruta == null || ruta.isEmpty) {
      return '';
    }

    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }

    return '$apiBaseUrl$ruta';
  }
}
