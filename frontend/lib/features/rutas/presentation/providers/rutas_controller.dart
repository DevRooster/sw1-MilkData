import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/ruta_api.dart';
import '../../data/ruta_repository.dart';
import '../../domain/ruta.dart';

final rutaApiProvider = Provider<RutaApi>((ref) {
  return RutaApi(ref.watch(apiClientProvider));
});

final rutaRepositoryProvider = Provider<RutaRepository>((ref) {
  return RutaRepository(api: ref.watch(rutaApiProvider));
});

/// Estado de la lista de rutas.
class RutasState {
  const RutasState({
    this.rutas = const <Ruta>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<Ruta> rutas;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  RutasState copyWith({
    List<Ruta>? rutas,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return RutasState(
      rutas: rutas ?? this.rutas,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
///
/// Van aparte del estado y no dentro de él, por el mismo motivo que en los otros
/// módulos: dentro, el `build` del controller tendría que leerlos para cargarse,
/// y eso es depender de su propio estado mientras se construye.
class FiltrosRutas {
  const FiltrosRutas({this.soloInactivas = false, this.busqueda = ''});

  /// Muestra las **inactivas**, que son las pocas. El nombre va al revés de la
  /// pantalla a propósito: si se llamara `soloActivas`, "sin marcar" tendría que
  /// significar "todas" y haría falta un estado más.
  final bool soloInactivas;
  final String busqueda;

  bool get hayAlguno => soloInactivas || busqueda.isNotEmpty;

  FiltrosRutas copyWith({bool? soloInactivas, String? busqueda}) {
    return FiltrosRutas(
      soloInactivas: soloInactivas ?? this.soloInactivas,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de rutas y ejecuta las acciones sobre cada una.
class RutasController extends Notifier<RutasState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  RutasState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const RutasState();
  }

  RutaRepository get _repo => ref.read(rutaRepositoryProvider);

  FiltrosRutas get _filtros => ref.read(filtrosRutasProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        busqueda: filtros.busqueda,
        activa: filtros.soloInactivas ? false : null,
      );

      state = state.copyWith(
        rutas: resultado.rutas,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        cargando: false,
      );
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  Future<void> irAPagina(int numero) => cargar(pagina: numero);

  /// Vuelve a la primera página.
  ///
  /// Al cambiar un filtro, no al navegar: quedarse en la página 5 de un filtro
  /// que ahora tiene dos páginas mostraría una lista vacía sin explicación.
  void _volverAPrimero() {
    state = state.copyWith(pagina: 1);
  }

  Future<void> alternarSoloInactivas() async {
    ref.read(filtrosRutasProvider.notifier).alternarSoloInactivas();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosRutasProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosRutasProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea una ruta y recarga la lista.
  Future<bool> crear({
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    try {
      await _repo.crear(
        nombre: nombre,
        codigo: codigo,
        descripcion: descripcion,
        horaInicio: horaInicio,
        horaFin: horaFin,
        activa: activa,
      );

      // Se recarga entero en vez de añadir la fila a mano: la respuesta llega
      // sin el orden de la base, y un insertado en cabecera podría no ser el
      // primero que devolvería el servidor.
      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de una ruta.
  Future<bool> editar(
    Ruta ruta, {
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    try {
      final actualizada = await _repo.editar(
        ruta.id,
        nombre: nombre,
        codigo: codigo,
        descripcion: descripcion,
        horaInicio: horaInicio,
        horaFin: horaFin,
        activa: activa,
      );

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Ruta ruta) async {
    try {
      await _repo.eliminar(ruta.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró, y
      // recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        rutas: state.rutas.where((r) => r.id != ruta.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  void limpiarError() {
    if (state.error != null) {
      state = state.copyWith(limpiarError: true);
    }
  }

  /// Cambia una fila por su versión actualizada, conservando el orden.
  void _reemplazar(Ruta actualizada) {
    final lista = state.rutas
        .map((r) => r.id == actualizada.id ? actualizada : r)
        .toList();

    state = state.copyWith(rutas: lista, limpiarError: true);
  }
}

final rutasControllerProvider = NotifierProvider<RutasController, RutasState>(
  RutasController.new,
);

/// Filtros de la lista de rutas.
///
/// Un provider aparte del que carga: así el `build` de `RutasController` puede
/// leerlos sin depender de su propio estado.
class FiltrosRutasController extends Notifier<FiltrosRutas> {
  @override
  FiltrosRutas build() => const FiltrosRutas();

  void alternarSoloInactivas() {
    state = state.copyWith(soloInactivas: !state.soloInactivas);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }

  void limpiar() {
    state = const FiltrosRutas();
  }
}

final filtrosRutasProvider = NotifierProvider<FiltrosRutasController, FiltrosRutas>(
  FiltrosRutasController.new,
);

/// Las rutas, para el desplegable de otros módulos.
///
/// Vive aquí y no en cada módulo que lo necesite: Zonas y Recorridos eligen una
/// ruta, y pedirlo desde los tres sitios son tres listas que pueden quedar sin
/// sincronizar.
final opcionesDeRutaProvider = FutureProvider<List<ReferenciaRuta>>((ref) async {
  final rutas = await ref.watch(rutaRepositoryProvider).listar(limite: 100);

  return rutas.rutas.map(ReferenciaRuta.nueva).toList();
});

/// Una ruta para un desplegable: lo que se enseña y lo que se devuelve.
class ReferenciaRuta {
  const ReferenciaRuta({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory ReferenciaRuta.nueva(Ruta ruta) =>
      ReferenciaRuta(id: ruta.id, nombre: ruta.nombre);
}