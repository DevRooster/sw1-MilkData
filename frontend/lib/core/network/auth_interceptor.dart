import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'session_events.dart';
import 'token_refresher.dart';

/// Clave con la que una petición marca que no quiere token.
///
/// Va en `extra` porque ahí llegan los datos que son para la app y no para el
/// servidor: el servidor recibiría un `extra` como parámetro si fuera en query.
const String marcaSinToken = 'sinToken';

/// Agrega el token a cada petición y avisa cuando la API lo rechaza.
///
/// Centralizarlo aquí es lo que hace escalable el cliente: ninguna pantalla
/// tiene que acordarse de poner `Authorization`, renovar el token a tiempo ni
/// cerrar sesión por un `401`. Todo eso es un caso y no una copia en cada
/// llamada.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required SessionEvents eventos,
    required TokenRefresher refresher,
  })  : _storage = storage,
        _eventos = eventos,
        _refresher = refresher;

  // ignore: prefer_initializing_formals
  final TokenStorage _storage;

  // ignore: prefer_initializing_formals
  final SessionEvents _eventos;

  // ignore: prefer_initializing_formals
  final TokenRefresher _refresher;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[marcaSinToken] != true) {
      // `tokenVigente` renueva por su cuenta si el token está por caducar, de
      // modo que quien llama no tiene que enterarse de que eso existe.
      final token = await _refresher.tokenVigente();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final esLogin = err.requestOptions.extra[marcaSinToken] == true;

    // El 401 del login es la respuesta esperada de unas credenciales malas, no
    // una sesión vencida: cerrar sesión ahí sería un error.
    if (err.response?.statusCode == 401 && !esLogin) {
      // El token venció o el usuario fue desactivado. Se limpia para que la
      // próxima petición no vuelva a fallar con lo mismo.
      await _storage.borrar();
      _eventos.notificarSesionVencida();
    }

    handler.next(err);
  }
}