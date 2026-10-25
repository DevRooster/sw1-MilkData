import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/avisos.dart';
import '../domain/notificacion.dart';

/// Publica un aviso en la barra del sistema.
///
/// Va como interfaz propia y no se llama al plugin directamente porque el plugin
/// necesita un móvil de verdad: sin esta separación, la prueba de "no repitas un
/// aviso ya marcado" no se podría escribir en absoluto.
abstract class PublicaAvisos {
  Future<void> publicar(Notificacion notificacion, Canal canal);
}

/// Dónde se guarda hasta qué aviso ya se avisó.
///
/// También interfaz por el mismo motivo: [`FlutterSecureStorage`] necesita
/// plataforma, y `TokenStorage` —que ya lo usa— no está pensado para esto.
abstract class MarcaDeAvisos {
  /// El id del último aviso ya avisado, o `null` si nunca se ha avisado.
  ///
  /// `null` **no** es cero: significa "no hay marca todavía", que es lo que
  /// distingue la primera vez de las siguientes.
  Future<int?> leer();

  Future<void> guardar(int id);
}

/// Marca guardada en el almacenamiento seguro de la plataforma.
///
/// Va aquí y no en `shared_preferences` por no añadir otra dependencia, pero
/// conviene saber que el almacenamiento seguro está pensado para secretos y este
/// no lo es: si algún día hay otra cosa que guardar sin cifrar,
/// `shared_preferences` es su sitio.
class MarcaEnAlmacenamiento implements MarcaDeAvisos {
  MarcaEnAlmacenamiento({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  /// Prefijada para no chocar con las claves de las demás libs de la app.
  static const String _clave = 'milkdata_aviso_marcado';

  @override
  Future<int?> leer() async {
    try {
      final bruto = await _storage.read(key: _clave);
      // `int.tryParse` y no `int.parse`: un valor raro guardado ahí no debe
      // tumbar el arranque de la app.
      return bruto == null ? null : int.tryParse(bruto);
    } catch (_) {
      // Si el almacenamiento no responde, se trata como "nunca se ha avisado"
      // en vez de impedir abrir la app.
      return null;
    }
  }

  @override
  Future<void> guardar(int id) async {
    try {
      await _storage.write(key: _clave, value: '$id');
    } catch (_) {
      // Perder la marca solo cuesta un aviso repetido la próxima vez. Fallar
      // al avisar sería mucho peor.
    }
  }
}

/// El plugin, a nivel de fichero.
///
/// Fuera de [AvisosLocales] porque [PublicaEnPlugin] —la clase que de verdad
/// publica— también lo necesita, y para eso no hace falta hacerlo público.
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

/// Publica los avisos en la barra del sistema de Android.
///
/// **Solo avisa con la app abierta**: recoge lo que devuelve
/// `GET /notificaciones` cuando la pantalla carga y publica lo que aún no se ha
/// enseñado. No hay nada en segundo plano, así que un aviso que llegue con la app
/// cerrada se verá al abrirla — y no al móvil. Eso es lo que diferencia esto de
/// un push de verdad, que necesitaría un proyecto de Firebase, registrar el token
/// del dispositivo en el servidor y enviar desde allí.
class AvisosLocales {
  AvisosLocales({required this.marca, PublicaAvisos? publica})
      : _publica = publica ?? PublicaEnPlugin();

  final MarcaDeAvisos marca;
  final PublicaAvisos _publica;

  bool _inicializado = false;

  /// Prepara el plugin y crea los tres canales.
  ///
  /// Los canales **se crean aunque el permiso se deniegue**: el usuario puede
  /// activarlos después en los ajustes del móvil, y si no existen no hay nada
  /// que activar. Crearlos depende de la app; que suene, ya no.
  Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }

    final ajustes = InitializationSettings(
      // Sin icono propio se usa el de la app. El aviso del sistema necesita uno
      // y sin él Android lo sustituye por un cuadro vacío.
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    try {
      await _plugin.initialize(settings: ajustes);

      for (final canal in Canal.todos()) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                canal.id,
                canal.nombre,
                description: canal.descripcion,
                importance: canal.importante ? Importance.max : Importance.low,
              ),
            );
      }

      // El permiso va aparte y **después** de crear los canales: en Android 13+
      // pedirlo antes de que existan los canales muestra un diálogo sobre nada,
      // y el usuario dice que sí sin llegar a ver lo que está activando.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _inicializado = true;
    } catch (error) {
      // Un móvil que no dé notificaciones no es motivo para que la app no abra.
      // La lista funciona igual; lo único que se pierde es el aviso del sistema.
      debugPrint('No se pudieron preparar los avisos locales: $error');
    }
  }

  /// Publica los avisos que aún no se han enseñado y avanza la marca.
  ///
  /// Devuelve cuántos se publicaron, para que una prueba pueda comprobarlo.
  /// No lanza: avisar es un extra y no puede impedir que la lista se vea.
  Future<int> avisar(List<Notificacion> avisos) async {
    try {
      final guardada = await marca.leer();
      final esPrimeraVez = guardada == null;

      final resultado = calculaNuevos(
        avisos,
        ultimaMarcada: guardada ?? 0,
        esPrimeraVez: esPrimeraVez,
      );

      // La marca se guarda **antes** de publicar. Si publicar fallara a mitad, no
      // se repetiría todo en la próxima carga; es el fallo que menos molesta.
      await marca.guardar(resultado.marca);

      for (final notificacion in resultado.nuevos) {
        await _publica.publicar(notificacion, Canal.deTipo(notificacion.tipo));
      }

      return resultado.nuevos.length;
    } catch (error) {
      debugPrint('No se pudieron avisar de las notificaciones: $error');
      return 0;
    }
  }
}

/// La implementación de verdad, la que habla con el plugin.
class PublicaEnPlugin implements PublicaAvisos {
  @override
  Future<void> publicar(Notificacion notificacion, Canal canal) async {
    // Todo con nombre a partir de la versión 22: antes eran posicionales y el
    // cambio no es de los que el analizador avisa con un mensaje legible —solo
    // dice que sobran argumentos, sin mencionar que es el mismo método.
    await _plugin.show(
      id: notificacion.id,
      title: '${notificacion.titulo} · ${Notificacion.etiquetaDeTipo(notificacion.tipo)}',
      // El cuerpo enseña a quién va: sin eso, un aviso de adulteración en la
      // barra del móvil no dice a qué proveedor se le dio por alta.
      body: '${notificacion.destinatario}: ${notificacion.mensajeCorto}',
      // Sin esto, al tocar el aviso el móvil no sabría a qué pantalla volver.
      payload: '${notificacion.id}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.nombre,
          channelDescription: canal.descripcion,
          importance: canal.importante ? Importance.max : Importance.low,
          priority: canal.importante ? Priority.high : Priority.low,
          // Un aviso sin id numérico se leería como duplicado de otro anterior.
          // El del aviso va, porque es el que distingue una adulteración de una
          // reunión.
          styleInformation: BigTextStyleInformation(notificacion.mensaje),
          ticker: notificacion.titulo,
        ),
      ),
    );
  }
}