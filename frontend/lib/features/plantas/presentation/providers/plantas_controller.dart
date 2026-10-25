import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/domain/planta.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/planta_api.dart';

/// API de plantas, para el módulo de administración.
final plantaApiProvider = Provider<PlantaApi>((ref) {
  return PlantaApi(ref.watch(apiClientProvider));
});

/// Estado de la lista de plantas.
class PlantasState {
  const PlantasState({
    this.plantas = const <Planta>[],
    this.cargando = false,
    this.error,
  });

  final List<Planta> plantas;
  final bool cargando;
  final AppException? error;

  int get total => plantas.length;

  /// Las activas primero y dentro por nombre, que es como se lee una lista de
  /// sedes.
  ///
  /// **El backend no lo ordena.** Lo ordena la lista para el ojo, no el servidor:
  /// quien da de alta una planta la quiere ver arriba, no en el orden en que se
  /// insertó.
  List<Planta> get ordenadas {
    final copia = [...plantas];

    copia.sort((a, b) {
      if (a.activo != b.activo) {
        return a.activo ? -1 : 1;
      }
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });

    return copia;
  }

  PlantasState copyWith({
    List<Planta>? plantas,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return PlantasState(
      plantas: plantas ?? this.plantas,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Carga las plantas y ejecuta acciones sobre cada una.
class PlantasController extends Notifier<PlantasState> {
  @override
  PlantasState build() {
    return const PlantasState();
  }

  PlantaApi get _api => ref.watch(plantaApiProvider);

  Future<void> cargar() async {
    state = state.copyWith(cargando: true, limpiarError: true);

    try {
      final lista = await _api.listar();
      state = state.copyWith(plantas: lista, cargando: false);
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  Future<bool> crear({
    required String nombre,
    required String codigo,
    String? direccion,
  }) async {
    try {
      await _api.crear(nombre: nombre, codigo: codigo, direccion: direccion);
      await cargar();
      await _refrescarAlcance();
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<bool> editar(
    Planta planta, {
    required String nombre,
    required String codigo,
    String? direccion,
  }) async {
    try {
      await _api.editar(planta.id, nombre: nombre, codigo: codigo, direccion: direccion);
      await cargar();
      await _refrescarAlcance();
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Planta planta) async {
    try {
      await _api.eliminar(planta.id);

      state = state.copyWith(
        plantas: state.plantas.where((p) => p.id != planta.id).toList(),
      );

      await _refrescarAlcance();
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  void limpiarError() {
    if (state.error != null) {
      state = state.copyWith(limpiarError: true);
    }
  }

  /// Vuelve a pedir la lista de plantas del superadmin.
  ///
  /// Hace falta porque **crear una planta no la mete sola en la tarjeta del
  /// inicio**: esa tarjeta lee `estado.plantas`, que viene de `GET /auth/plantas`.
  /// Sin esto, se crea la planta y el selector sigue sin mostrarla hasta que se
  /// cierre la sesión.
  Future<void> _refrescarAlcance() async {
    await ref.read(authControllerProvider.notifier).recargarAlcance();
  }
}

final plantasControllerProvider =
    NotifierProvider<PlantasController, PlantasState>(PlantasController.new);

/// El nombre de la planta en la que está la sesión.
///
/// **Un `Provider` y no un `FutureProvider`, a propósito.** Va en la sesión y no se
/// pide a `/plantas`, por dos razones que salieron al intentar lo otro:
///
/// - Un recolector **no tiene permiso de `plantas: read`**. Pedirla por aparte le
///   daría un 403 en la pantalla, que es peor que no llevar etiqueta.
/// - Es una petición extra para pintar un texto. En una red de planta, con el
///   móvil cogiendo cobertura a ratos, eso se cae justo cuando hace falta.
///
/// Sale de la sesión porque **todo lo que puede ver una persona es de su planta**:
/// el backend aísla por `plantaId` en cada consulta. Por eso esto no es un filtro
/// sino una etiqueta que quita la duda de si lo que estás mirando es de aquí o de
/// al lado.
///
/// **Devuelve `null` y no un texto de relleno** cuando no se sabe: es mejor no
/// poner nada que poner "Planta" a secas, que parece el nombre de una planta
/// llamada Planta.
final plantaActualProvider = Provider<String?>((ref) {
  final estado = ref.watch(authControllerProvider);

  return estado is Autenticado ? estado.usuario.plantaParaMostrar : null;
});