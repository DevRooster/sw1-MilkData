import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Renueva el token solo cuando está a punto de caducar.
///
/// La app no debería pedirle a la persona que "renueve su token": eso es un
/// trabajo interno. Aquí se comprueba la fecha de expiración del JWT antes de
/// cada petición y, si quedan pocos minutos, se renueva en silencio y se
/// guarda el nuevo.
///
/// El token es un JWT, así que su expiración viaja dentro y no hace falta
/// pedirle nada al servidor para saberla.
class TokenRefresher {
  TokenRefresher({required TokenStorage storage, required Dio dio})
      : _storage = storage,
        _dio = dio;

  // ignore: prefer_initializing_formals
  final TokenStorage _storage;

  // ignore: prefer_initializing_formals
  final Dio _dio;

  /// Margen antes de la expiración a partir del cual se renueva.
  ///
  /// Tres minutos dan margen para una petición lenta sin renovar en cada
  /// llamada, que sería tirar peticiones contra el servidor sin motivo.
  static const Duration margen = Duration(minutes: 3);

  /// Renovación en marcha, para no lanzar varias a la vez.
  ///
  /// Al abrir la app se lanzan varias peticiones juntas (perfil, plantas). Si
  /// todas ven el token a punto de caducar y cada una renueva por su cuenta,
  /// el servidor recibe N renovaciones en el mismo instante. Al guardar el
  /// futuro aquí, todas comparten la misma.
  Future<String?>? _enCurso;

  /// Token vigente para la próxima petición.
  ///
  /// Devuelve `null` si no hay sesión, para que el `interceptor` no mande
  /// cabecera ninguna.
  Future<String?> tokenVigente() async {
    final token = await _storage.leer();
    if (token == null || token.isEmpty) {
      return null;
    }

    final expira = _expiraEn(token);

    // Si no se puede leer la expiración no se renueva a ciegas: se usa el
    // token y, si el servidor lo rechaza, el interceptor limpia la sesión.
    if (expira == null) {
      return token;
    }

    final restante = expira.difference(DateTime.now().toUtc());
    if (restante > margen) {
      return token;
    }

    return _renovar();
  }

  /// Fuerza una renovación y guarda el token nuevo.
///
/// Devuelve `null` si el servidor no pudo emitirlo. Se usa al cambiar de planta,
/// que ya devuelve su propio token, y no solo por caducidad.
Future<String?> renovarAhora() => _renovar();

  Future<String?> _renovar() {
    final enCurso = _enCurso;
    if (enCurso != null) {
      return enCurso;
    }

    final futuro = _pedirTokenNuevo().whenComplete(() => _enCurso = null);
    _enCurso = futuro;
    return futuro;
  }

  Future<String?> _pedirTokenNuevo() async {
    try {
      final respuesta = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        options: Options(extra: const {marcaSinTokenInterno: true}),
      );

      final cuerpo = respuesta.data;
      if (cuerpo == null || cuerpo['success'] != true) {
        return null;
      }

      final datos = cuerpo['data'] as Map<String, dynamic>?;
      final token = datos?['token'] as String?;

      if (token == null || token.isEmpty) {
        return null;
      }

      await _storage.guardar(token);
      return token;
    } catch (_) {
      // Una renovación fallida no debe tumbar la app: se devuelve `null` y la
      // petición sigue con el token viejo. Si ese tampoco vale, el 401 que
      // llegará después se encarga de cerrar la sesión.
      return null;
    }
  }

  /// Instantante de expiración de un JWT, o `null` si no se puede leer.
  static DateTime? _expiraEn(String token) {
    final partes = token.split('.');
    if (partes.length != 3) {
      return null;
    }

    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
      final datos = jsonDecode(payload) as Map<String, dynamic>;
      final exp = datos['exp'] as int?;

      if (exp == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}

/// Marca una petición como hecha sin token.
///
/// El renovador usa un `Dio` propio, sin el interceptor de sesión, así que
/// dentro de esta cadena no hay recursión posible. La marca está por si acaso y
/// para que el intention sea explícito al leerlo.
const String marcaSinTokenInterno = 'sinToken';