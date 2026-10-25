import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/app_exception.dart';

/// Convierte lo que lanza `Dio` en los errores que la app entiende.
///
/// Todo el manejo de fallos de red pasa por aquí, así que las pantallas nunca
/// se topan con excepciones de Dio ni con códigos HTTP sueltos.
AppException mapearError(Object error) {
  if (error is AppException) {
    return error;
  }

  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        TimeoutException(_mensajeDeEspera()),
      DioExceptionType.connectionError => NetworkException(_mensajeDeEspera()),
      DioExceptionType.badCertificate =>
        const NetworkException('No se pudo validar el certificado del servidor.'),
      _ => _desdeRespuesta(error.response),
    };
  }

  return ServerException('Ocurrió un error inesperado.');
}

/// Qué se estaba intentando y por dónde.
///
/// Un tiempo de espera agotado no dice **a quién** se le llamaba. Sin eso, el
/// aviso era "el servidor tardó demasiado" y el problema real puede ser la
/// dirección equivocada, el puente USB caído o el cortafuegos. Poner la URL a la
/// vista convierte un mensaje sordo en uno contra el que se puede actuar.
String _mensajeDeEspera() {
  return 'No se pudo contactar con ${AppConfig.apiBaseUrl}. '
      'Si pruebas con el teléfono por USB, el puente puede haberse caído: '
      'vuelve a ejecutar "adb reverse tcp:3000 tcp:3000".';
}

/// Traduce la respuesta de la API en una excepción tipada.
///
/// El backend responde siempre con la misma forma:
///
/// ```json
/// { "success": false, "data": null, "message": "...", "errors": [] }
/// ```
AppException _desdeRespuesta(Response<dynamic>? respuesta) {
  final status = respuesta?.statusCode ?? 0;
  final cuerpo = respuesta?.data;

  final mensaje = switch (cuerpo) {
    {'message': final String texto} when texto.isNotEmpty => texto,
    _ => switch (status) {
      401 => 'Sesión vencida. Vuelve a iniciar sesión.',
      403 => 'No tienes permisos para realizar esta acción.',
      404 => 'No se encontró lo que solicitaste.',
      >= 500 => 'El servidor tuvo un problema. Intenta más tarde.',
      _ => 'Ocurrió un error inesperado.',
    },
  };

  final errores = switch (cuerpo) {
    {'errors': final List<dynamic> lista} =>
      lista.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
    _ => const <String>[],
  };

  return switch (status) {
    401 => const UnauthorizedException(),
    403 => const ForbiddenException(),
    404 => const NotFoundException(),
    400 || 422 => ValidationException(mensaje, errores: errores),
    _ => ServerException(mensaje, statusCode: status == 0 ? null : status),
  };
}