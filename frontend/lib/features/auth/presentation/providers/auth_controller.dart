import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/session_events.dart';
import '../../../../core/network/token_refresher.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/auth_api.dart';
import '../../data/auth_repository.dart';
import '../../domain/permisos.dart';
import '../../domain/planta.dart';
import '../../domain/sesion.dart';

// ------------------------------------------------------------------
// Infraestructura
//
// Sin estado de negocio: se comparten por toda la app.
// ------------------------------------------------------------------

/// Almacén cifrado del token.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Canal por el que la capa de red avisa que la sesión se venció.
final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final eventos = SessionEvents();
  ref.onDispose(eventos.dispose);
  return eventos;
});

/// Cliente HTTP con su interceptor de autenticación.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = crearApiClient();

  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      eventos: ref.watch(sessionEventsProvider),
      refresher: ref.watch(tokenRefresherProvider),
    ),
  );

  return dio;
});

/// Renueva el token cuando está por caducar.
///
/// Usa un `Dio` propio sin el interceptor: si compartiera el cliente, pedir un
/// token nuevo dispararía otra vez este mismo interceptor, que volvería a
/// renovar, sin fin.
final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    storage: ref.watch(tokenStorageProvider),
    dio: crearApiClient(),
  );
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

// ------------------------------------------------------------------
// Estado de autenticación
// ------------------------------------------------------------------

/// Estado de la sesión desde el punto de vista de la interfaz.
sealed class AuthState {
  const AuthState();
}

/// Aún no se sabe si hay sesión: se está leyendo el almacén cifrado.
class AuthDesconocido extends AuthState {
  const AuthDesconocido();
}

/// No hay sesión: toca el login.
class SinSesion extends AuthState {
  const SinSesion({this.enviando = false, this.error});

  /// El login está en curso: el botón va en estado de carga.
  final bool enviando;

  /// Error del último intento, para mostrarlo bajo el formulario.
  final AppException? error;

  SinSesion copyWith({bool? enviando, AppException? error, bool limpiarError = false}) {
    return SinSesion(
      enviando: enviando ?? this.enviando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Hay sesión activa.
class Autenticado extends AuthState {
  const Autenticado(this.usuario, {this.plantas, this.permisos});

  final UsuarioSesion usuario;

  /// Plantas que puede supervisar esta sesión.
  ///
  /// Se piden solas al entrar. Vive en el estado y no en la pantalla para que
  /// Inicio y el selector de planta compartan la misma respuesta en vez de
  /// pedirla cada una.
  final PlantasDisponibles? plantas;

  /// Recursos que puede usar esta sesión.
  ///
  /// También se pide solo al entrar, y por el mismo motivo: el lanzador de
  /// módulos lo consulta cada vez que se pinta, y no debería haber una pantalla
  /// pidiendo la misma respuesta una y otra vez.
  final Permisos? permisos;

  Autenticado copyWith({
    UsuarioSesion? usuario,
    PlantasDisponibles? plantas,
    Permisos? permisos,
  }) {
    return Autenticado(
      usuario ?? this.usuario,
      plantas: plantas ?? this.plantas,
      permisos: permisos ?? this.permisos,
    );
  }
}

/// Controla el login, la restauración de sesión y el logout.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _suscripcion;

  @override
  AuthState build() {
    // Un 401 en cualquier petición cierra la sesión. Se suscribe aquí porque
    // es el punto donde el provider está vivo y puede cancelar la escucha.
    _suscripcion = ref
        .watch(sessionEventsProvider)
        .sesionVencida
        .listen((_) => unawaited(cerrarSesion()));

    ref.onDispose(() => _suscripcion?.cancel());

    unawaited(_restaurarSesion());

    return const AuthDesconocido();
  }

  /// Al arrancar, comprueba si quedó un token guardado.
  Future<void> _restaurarSesion() async {
    final hay = await ref.read(authRepositoryProvider).haySesion();

    if (!hay) {
      state = const SinSesion();
      return;
    }

    // Con solo el token no se conoce al usuario, así que se pide el perfil.
    await _cargarPerfil();
  }

  /// Carga perfil y plantas, que es todo lo que la app necesita para pintar la
  /// sesión completa.
  ///
  /// Las dos van juntas y en paralelo: son independientes y sin una depende de
  /// la otra, así que encadenarlas sería esperar de más. Un fallo en la lista de
  /// plantas no debe tumbar el perfil, que es lo que sí se necesita para entrar.
  Future<void> _cargarPerfil() async {
    try {
      final usuario = await ref.read(authApiProvider).perfil();
      state = Autenticado(usuario);

      unawaited(_cargarPlantas());
      unawaited(_cargarPermisos());
    } on AppException {
      // Token inválido o vencido: el interceptor ya lo borró del almacén.
      state = const SinSesion();
    }
  }

  /// Pide la matriz de permisos del token, sin tocar la sesión si falla.
  Future<void> _cargarPermisos() async {
    try {
      final permisos = await ref.read(authRepositoryProvider).permisos();
      final actual = state;

      if (actual is Autenticado) {
        state = actual.copyWith(permisos: permisos);
      }
    } on AppException {
      // Sin permisos el lanzador se queda vacío: se ve menos, pero no se ve
      // nada que la API vaya a rechazar. Faltarla sería enseñarle al usuario
      // módulos que no puede abrir, que es peor que no enseñarle ninguno.
    }
  }

  /// Pide las plantas que puede supervisar la sesión, sin tocar la sesión si
  /// falla.
  Future<void> _cargarPlantas() async {
    try {
      final plantas = await ref.read(authRepositoryProvider).plantasDisponibles();
      final actual = state;

      if (actual is Autenticado) {
        state = actual.copyWith(plantas: plantas);
      }
    } on AppException {
      // Sin lista de plantas la app sigue funcionando: solo se pierde el
      // selector de planta. Faltarla sería tirar la sesión entera.
    }
  }

  /// Intenta iniciar sesión. Devuelve `true` si lo consigue.
  Future<bool> login({required String email, required String password}) async {
    final correo = email.trim();

    if (correo.isEmpty || password.isEmpty) {
      state = const SinSesion(
        error: ValidationException('Completa tu correo y tu contraseña.'),
      );
      return false;
    }

    state = const SinSesion(enviando: true);

    try {
      final sesion = await ref
          .read(authRepositoryProvider)
          .login(email: correo, password: password);

      // El login ya trae el usuario, así que la pantalla puede pintarse de
      // inmediato. El perfil, las plantas y los permisos llegan después, sin
      // bloquear.
      state = Autenticado(sesion.usuario);
      unawaited(_cargarPerfil());
      unawaited(_cargarPlantas());
      unawaited(_cargarPermisos());

      return true;
    } on AppException catch (error) {
      state = SinSesion(error: error);
      return false;
    }
  }

  /// Cierra sesión a pedido del usuario.
  ///
  /// Le avisa al servidor con `POST /auth/logout` y después borra el token del
  /// dispositivo. El orden importa: si se borrara primero, la petición saldría
  /// sin cabecera y el servidor respondería 401 en vez de confirmar el cierre.
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).confirmarLogoutRemoto();
    } on AppException {
      // Si el servidor no responde, la sesión local se cierra igual: quedarse
      // dentro por un fallo de red sería peor que la decepción de no avisar.
    }

    await ref.read(authRepositoryProvider).logout();
    state = const SinSesion();
  }

  /// Cierra sesión, local o por un 401.
  Future<void> cerrarSesion() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SinSesion();
  }

  /// Cambia de planta y actualiza todo lo que depende del token.
  ///
  /// El token devuelto queda ligado a la planta elegida, así que el perfil se
  /// vuelve a pedir: si no, la cabecera seguiría mostrando la planta anterior.
  Future<bool> cambiarPlanta({required int plantaId}) async {
    try {
      await ref.read(authRepositoryProvider).cambiarPlanta(plantaId: plantaId);
      await _cargarPerfil();
      return true;
    } on AppException {
      return false;
    }
  }

  /// Vuelve a pedir el perfil al servidor y lo deja como sesión activa.
  ///
  /// Se usa tras cambiar de planta: el token nuevo apunta a otra planta y sin
  /// esto la cabecera seguiría mostrando la anterior.
  Future<void> recargarPerfil() async {
    await _cargarPerfil();
  }

  /// Vuelve a pedir la lista de plantas y la deja en la sesión.
  ///
  /// Se usa tras **crear, editar o borrar una planta**: la tarjeta del inicio lee
  /// `estado.plantas`, que viene de `GET /auth/plantas`, y sin esto la planta
  /// nueva no saldría en el selector hasta cerrar la sesión.
  Future<void> recargarAlcance() async {
    await _cargarPlantas();
  }

  /// Reemplaza al usuario de la sesión sin volver a pedirlo.
  ///
  /// Para cuando la respuesta de la API ya trae el usuario actualizado y
  /// gastarse otra petición sería tirarla.
  ///
  /// **Conserva plantas y permisos.** Antes los soltaba: `Autenticado(usuario)`
  /// sin ellos deja la sesión con la lista de plantas vacía y **sin un solo
  /// permiso**, con lo que el lanzador se queda sin módulos y la tarjeta del
  /// alcance dice "Solo tu planta" para un superadmin. Pasaba al cambiar de planta.
  void actualizarUsuario(UsuarioSesion usuario) {
    final actual = state;
    if (actual is Autenticado) {
      state = Autenticado(usuario, plantas: actual.plantas, permisos: actual.permisos);
    }
  }

  /// Limpia el error del formulario, para que desaparezca al escribir.
  void limpiarError() {
    final actual = state;
    if (actual is SinSesion && actual.error != null) {
      state = actual.copyWith(limpiarError: true);
    }
  }
}

/// Estado de autenticación de la app.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Atajo booleano: ¿hay sesión? Útil para decidir la pantalla inicial.
final haySesionProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider) is Autenticado,
);

/// Permisos de la sesión actual.
///
/// Sale vacío mientras la respuesta no llega, y también sin sesión. Es lo que
/// consultan el lanzador de módulos y las pestañas: si un módulo no está aquí,
/// no se enseña. Nunca se deduce del nombre del rol, porque el nombre del rol es
/// una de las dos mitades de la decisión y la otra vive en la matriz del
/// servidor.
final permisosProvider = Provider<Permisos>((ref) {
  final estado = ref.watch(authControllerProvider);
  return estado is Autenticado ? (estado.permisos ?? Permisos.vacio) : Permisos.vacio;
});