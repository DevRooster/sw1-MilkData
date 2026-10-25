import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/recoleccion_api.dart';
import '../../data/recoleccion_repository.dart';
import '../../domain/recoleccion.dart';

final recoleccionApiProvider = Provider<RecoleccionApi>((ref) {
  return RecoleccionApi(ref.watch(apiClientProvider));
});

final recoleccionRepositoryProvider = Provider<RecoleccionRepository>((ref) {
  return RecoleccionRepository(api: ref.watch(recoleccionApiProvider));
});

/// Estado de la lista de recolecciones.
class RecoleccionesState {
  const RecoleccionesState({
    this.recolecciones = const <Recoleccion>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.litros = 0,
    this.cargando = false,
    this.error,
  });

  final List<Recoleccion> recolecciones;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Suma de litros de las recolecciones de **esta página**, no de todas.
  ///
  /// Ponerlo aquí y no calcularlo en la pantalla evita que cada fila lo sume otra
  /// vez. Y es de la página y no del total porque el total paginado no trae las
  /// filas: para la suma harían falta todas las consultas.
  final double litros;

  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  RecoleccionesState copyWith({
    List<Recoleccion>? recolecciones,
    int? pagina,
    int? totalPaginas,
    int? total,
    double? litros,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return RecoleccionesState(
      recolecciones: recolecciones ?? this.recolecciones,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      litros: litros ?? this.litros,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosRecolecciones {
  const FiltrosRecolecciones({
    this.registradoEn,
    this.soloPendientes = false,
    this.fecha = '',
  });

  /// Dónde se anotó: campo, planta, o `null` para las dos.
  ///
  /// El enumerado va entero y no como texto porque es el que la pantalla usa;
  /// el texto del servidor se decide en la capa de API.
  final String? registradoEn;

  /// Muestra las **no sincronizadas**, que son las que aún no se han subido.
  /// El nombre va al revés de la pantalla a propósito: si se llamara
  /// `soloSincronizadas`, "sin marcar" tendría que significar "todas".
  final bool soloPendientes;

  /// Un día concreto, `YYYY-MM-DD`. Vacío es todos.
  final String fecha;

  bool get hayAlguno => registradoEn != null || soloPendientes || fecha.isNotEmpty;

  FiltrosRecolecciones copyWith({
    String? registradoEn,
    bool limpiarRegistro = false,
    bool? soloPendientes,
    String? fecha,
  }) {
    return FiltrosRecolecciones(
      // Sin `limpiarRegistro` no se podría volver a "todas": `null` es justo el
      // valor que significa eso.
      registradoEn: limpiarRegistro ? null : (registradoEn ?? this.registradoEn),
      soloPendientes: soloPendientes ?? this.soloPendientes,
      fecha: fecha ?? this.fecha,
    );
  }
}

/// Carga la lista de recolecciones y ejecuta las acciones sobre cada una.
class RecoleccionesController extends Notifier<RecoleccionesState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  RecoleccionesState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const RecoleccionesState();
  }

  RecoleccionRepository get _repo => ref.read(recoleccionRepositoryProvider);

  FiltrosRecolecciones get _filtros => ref.read(filtrosRecoleccionesProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        fecha: filtros.fecha,
        registradoEn: filtros.registradoEn,
        sincronizado: filtros.soloPendientes ? false : null,
      );

      state = state.copyWith(
        recolecciones: resultado.recolecciones,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        litros: resultado.recolecciones.fold<double>(
          0,
          (suma, r) => suma + r.cantidad,
        ),
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

  Future<void> filtrarPorRegistro(String? registradoEn) async {
    ref.read(filtrosRecoleccionesProvider.notifier).filtrarPorRegistro(registradoEn);
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloPendientes() async {
    ref.read(filtrosRecoleccionesProvider.notifier).alternarSoloPendientes();
    _volverAPrimero();
    await cargar();
  }

  Future<void> filtrarPorFecha(String fecha) async {
    ref.read(filtrosRecoleccionesProvider.notifier).filtrarPorFecha(fecha);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosRecoleccionesProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea una recolección y recarga la lista.
  Future<bool> crear({
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) async {
    try {
      await _repo.crear(
        proveedorId: proveedorId,
        zonaId: zonaId,
        unidadId: unidadId,
        usuarioId: usuarioId,
        cantidad: cantidad,
        fecha: fecha,
        registradoEn: registradoEn,
        hora: hora,
        temperatura: temperatura,
        recorridoParadaId: recorridoParadaId,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de una recolección.
  Future<bool> editar(
    Recoleccion recoleccion, {
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) async {
    try {
      final actualizada = await _repo.editar(
        recoleccion.id,
        proveedorId: proveedorId,
        zonaId: zonaId,
        unidadId: unidadId,
        usuarioId: usuarioId,
        cantidad: cantidad,
        fecha: fecha,
        registradoEn: registradoEn,
        hora: hora,
        temperatura: temperatura,
        recorridoParadaId: recorridoParadaId,
      );

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Recoleccion recoleccion) async {
    try {
      await _repo.eliminar(recoleccion.id);

      // La fila sale de la lista sin volver a pedirla, y los litros se restan
      // con ella: dejarlos como estaban daría una suma que ya no existe.
      state = state.copyWith(
        recolecciones:
            state.recolecciones.where((r) => r.id != recoleccion.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
        litros: state.litros - recoleccion.cantidad,
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
  void _reemplazar(Recoleccion actualizada) {
    final lista = state.recolecciones
        .map((r) => r.id == actualizada.id ? actualizada : r)
        .toList();

    state = state.copyWith(
      recolecciones: lista,
      litros: lista.fold<double>(0, (suma, r) => suma + r.cantidad),
      limpiarError: true,
    );
  }
}

final recoleccionesControllerProvider =
    NotifierProvider<RecoleccionesController, RecoleccionesState>(
  RecoleccionesController.new,
);

/// Filtros de la lista de recolecciones.
///
/// Un provider aparte del que carga: así el `build` de `RecoleccionesController`
/// puede leerlos sin depender de su propio estado.
class FiltrosRecoleccionesController extends Notifier<FiltrosRecolecciones> {
  @override
  FiltrosRecolecciones build() => const FiltrosRecolecciones();

  void filtrarPorRegistro(String? registradoEn) {
    state = state.copyWith(
      registradoEn: registradoEn,
      limpiarRegistro: registradoEn == null,
    );
  }

  void alternarSoloPendientes() {
    state = state.copyWith(soloPendientes: !state.soloPendientes);
  }

  void filtrarPorFecha(String fecha) {
    state = state.copyWith(fecha: fecha);
  }

  void limpiar() {
    state = const FiltrosRecolecciones();
  }
}

final filtrosRecoleccionesProvider =
    NotifierProvider<FiltrosRecoleccionesController, FiltrosRecolecciones>(
  FiltrosRecoleccionesController.new,
);
