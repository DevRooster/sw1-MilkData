import 'dart:async';

/// Avisos de sesión que no dependen de nada más.
///
/// Existe para romper una dependencia circular: el interceptor de red necesita
/// poder decir "la sesión se venció", y el controlador de autenticación necesita
/// enterarse. Si el interceptor llamara directamente al controlador, y el
/// controlador usa el cliente HTTP, cada uno dependería del otro.
///
/// Como este objeto no depende de nada, ambos pueden hablar con él.
class SessionEvents {
  final _sesionVencida = StreamController<void>.broadcast();

  /// Emite cuando la API responde 401 y hay que cerrar la sesión.
  Stream<void> get sesionVencida => _sesionVencida.stream;

  void notificarSesionVencida() {
    if (!_sesionVencida.isClosed) {
      _sesionVencida.add(null);
    }
  }

  void dispose() {
    _sesionVencida.close();
  }
}