import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import 'auth_controller.dart';

/// Desenlace del registro de un usuario.
///
/// El registro es la única operación de `/auth` que sigue siendo manual: las
/// demás las resuelve la app sola. Por eso necesita su propio estado con
/// mensajes claros.
sealed class RegistroEstado {
  const RegistroEstado();
}

/// El alta está en curso.
class RegistroEnCurso extends RegistroEstado {
  const RegistroEnCurso();
}

/// Usuario creado.
class RegistroOk extends RegistroEstado {
  const RegistroOk(this.mensaje);

  final String mensaje;
}

/// El servidor rechazó el alta.
class RegistroError extends RegistroEstado {
  const RegistroError(this.mensaje);

  final String mensaje;
}

/// Estado vacío: ni se ha intentado registrar nada.
class RegistroInactivo extends RegistroEstado {
  const RegistroInactivo();
}

/// Estado del formulario de alta de usuario.
class RegistroState {
  const RegistroState({this.estado = const RegistroInactivo()});

  final RegistroEstado estado;

  bool get ocupado => estado is RegistroEnCurso;
}

/// Da de alta usuarios contra la API.
class RegisterController extends Notifier<RegistroState> {
  @override
  RegistroState build() => const RegistroState();

  /// `POST /auth/register`
  ///
  /// Valida lo obvio antes de gastar una petición: el servidor rechaza con 400
  /// los campos vacíos, y un error de esa parte se lee mejor aquí que en un
  /// mensaje del servidor.
  Future<void> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required int rolId,
    required int plantaId,
  }) async {
    final falla = _validar(
      nombre: nombre,
      apellido: apellido,
      email: email,
      password: password,
    );

    if (falla != null) {
      state = RegistroState(estado: RegistroError(falla));
      return;
    }

    state = const RegistroState(estado: RegistroEnCurso());

    try {
      final usuario = await ref.read(authRepositoryProvider).registrar(
            nombre: nombre.trim(),
            apellido: apellido.trim(),
            email: email.trim(),
            password: password,
            rolId: rolId,
            plantaId: plantaId,
          );

      state = RegistroState(
        estado: RegistroOk(
          'Creado ${usuario.email} con rol ${usuario.rol.nombre} '
          'en la planta ${usuario.plantaId}.',
        ),
      );
    } on AppException catch (error) {
      state = RegistroState(estado: RegistroError(error.message));
    } catch (_) {
      state = const RegistroState(
        estado: RegistroError('Ocurrió un error inesperado.'),
      );
    }
  }

  /// Devuelve el mensaje del primer campo que no sirva, o `null` si todo bien.
  String? _validar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
  }) {
    if (nombre.trim().isEmpty || apellido.trim().isEmpty) {
      return 'Completa el nombre y el apellido.';
    }

    // La validación real de formato la hace el servidor; aquí solo se descarta
    // lo que no puede ser un correo para no gastar una ida y vuelta.
    if (!email.trim().contains('@')) {
      return 'El correo no parece válido.';
    }

    if (password.length < 8) {
      return 'La contraseña necesita al menos 8 caracteres.';
    }

    return null;
  }

  /// Limpia el mensaje para que desaparezca al tocar el formulario.
  void limpiar() {
    if (state.estado is! RegistroInactivo) {
      state = const RegistroState();
    }
  }
}

final registerControllerProvider = NotifierProvider<RegisterController, RegistroState>(
  RegisterController.new,
);