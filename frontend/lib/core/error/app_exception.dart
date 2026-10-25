/// Errores de la aplicación, ordenados por lo que la interfaz puede hacer con
/// ellos.
///
/// Se agrupan en una jerarquía cerrada (`sealed`) para que cada pantalla pueda
/// decidir qué mostrar según el tipo, en vez de leer el texto del mensaje.
library;

/// Cualquier fallo que la app sepa nombrar.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Mensaje listo para mostrar al usuario, en español.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No se pudo alcanzar al servidor: sin internet, servidor apagado o la
/// dirección de la API equivocada.
class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'No se pudo conectar con el servidor. Revisa tu conexión y la dirección de la API.',
  ]);
}

/// El servidor tardó más de lo permitido.
class TimeoutException extends AppException {
  const TimeoutException([
    super.message = 'El servidor tardó demasiado en responder. Intenta de nuevo.',
  ]);
}

/// Credenciales incorrectas, sesión vencida o cuenta inactiva.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Usuario o contraseña incorrectos.']);
}

/// El usuario está autenticado pero no tiene permiso para esa operación.
class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'No tienes permisos para realizar esta acción.',
  ]);
}

/// No se encontró el recurso pedido.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'No se encontró lo que solicitaste.']);
}

/// La API respondió con un error de validación. `errores` trae el detalle.
class ValidationException extends AppException {
  const ValidationException(super.message, {this.errores = const []});

  /// Lista de errores por campo, tal como la API los devuelve.
  final List<String> errores;
}

/// Fallo del servidor. `statusCode` permite decidir con código y no con texto.
class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;
}