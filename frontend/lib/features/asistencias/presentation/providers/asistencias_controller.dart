import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/asistencia_api.dart';
import '../../data/asistencia_repository.dart';
import '../../domain/asistencia.dart';

final asistenciaApiProvider = Provider<AsistenciaApi>((ref) {
  return AsistenciaApi(ref.watch(apiClientProvider));
});

final asistenciaRepositoryProvider = Provider<AsistenciaRepository>((ref) {
  return AsistenciaRepository(api: ref.watch(asistenciaApiProvider));
});

/// Estado de la lista de asistencias.
class AsistenciasState {
  const AsistenciasState({
    this.asistencias = const <Asistencia>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.porQr = 0,
    this.cargando = false,
    this.error,
  });

  final List<Asistencia> asistencias;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Cuántas de **esta página** se escanearon con QR.
  ///
  /// La proporción importa: si casi todas son manuales, el registro de asistencia
  /// se está llenando de memoria, y eso es un dato que la pantalla debe poder
  /// enseñar sin tener que exportar nada.
  final int porQr;

  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  AsistenciasState copyWith({
    List<Asistencia>? asistencias,
    int? pagina,
    int? totalPaginas,
    int? total,
    int? porQr,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return AsistenciasState(
      asistencias: asistencias ?? this.asistencias,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      porQr: porQr ?? this.porQr,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosAsistencias {
  const FiltrosAsistencias({this.evento = '', this.registradoPor, this.fecha = ''});

  /// Texto a buscar **dentro** del evento.
  ///
  /// Va por fragmento porque `evento` es texto libre: quien recuerda "reunion"
  /// tiene que encontrar "Reunión de ruta del Norte".
  final String evento;

  /// `QR`, `manual`, o `null` para las dos.
  final String? registradoPor;

  /// Un día concreto, `YYYY-MM-DD`. Vacío es todos.
  final String fecha;

  bool get hayAlguno => evento.isNotEmpty || registradoPor != null || fecha.isNotEmpty;

  FiltrosAsistencias copyWith({
    String? evento,
    String? registradoPor,
    bool limpiarRegistro = false,
    String? fecha,
  }) {
    return FiltrosAsistencias(
      evento: evento ?? this.evento,
      // Sin `limpiarRegistro` no se podría volver a "todas": `null` es justo el
      // valor que significa eso.
      registradoPor: limpiarRegistro ? null : (registradoPor ?? this.registradoPor),
      fecha: fecha ?? this.fecha,
    );
  }
}

/// Carga la lista de asistencias y ejecuta las acciones sobre cada una.
class AsistenciasController extends Notifier<AsistenciasState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  AsistenciasState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const AsistenciasState();
  }

  AsistenciaRepository get _repo => ref.read(asistenciaRepositoryProvider);

  FiltrosAsistencias get _filtros => ref.read(filtrosAsistenciasProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        evento: filtros.evento,
        registradoPor: filtros.registradoPor,
        fecha: filtros.fecha,
      );

      state = state.copyWith(
        asistencias: resultado.asistencias,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        porQr: resultado.asistencias.where((a) => a.esQr).length,
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

  Future<void> filtrarPorEvento(String evento) async {
    ref.read(filtrosAsistenciasProvider.notifier).filtrarPorEvento(evento);
    _volverAPrimero();
    await cargar();
  }

  Future<void> filtrarPorRegistro(String? registradoPor) async {
    ref.read(filtrosAsistenciasProvider.notifier).filtrarPorRegistro(registradoPor);
    _volverAPrimero();
    await cargar();
  }

  Future<void> filtrarPorFecha(String fecha) async {
    ref.read(filtrosAsistenciasProvider.notifier).filtrarPorFecha(fecha);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosAsistenciasProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea una asistencia y recarga la lista.
  ///
  /// `eventoNombre` y `eventoId` van juntos y **se mandan los dos a propósito**.
  /// El id es el enlace al catálogo y el nombre es el texto libre que la base
  /// exige; si se eligió un evento del catálogo, el nombre se rellena con el suyo,
  /// de modo que la fila se lee sola aunque el catálogo se borre mañana.
  Future<bool> crear({
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String registradoPor = Asistencia.manual,
    int? eventoId,
  }) async {
    try {
      await _repo.crear(
        proveedorId: proveedorId,
        usuarioId: usuarioId,
        evento: evento,
        fecha: fecha,
        registradoPor: registradoPor,
        eventoId: eventoId,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de una asistencia.
  Future<bool> editar(
    Asistencia asistencia, {
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String? registradoPor,
    int? eventoId,
  }) async {
    try {
      final actualizada = await _repo.editar(
        asistencia.id,
        proveedorId: proveedorId,
        usuarioId: usuarioId,
        evento: evento,
        fecha: fecha,
        registradoPor: registradoPor ?? asistencia.registradoPor,
        eventoId: eventoId,
      );

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Asistencia asistencia) async {
    try {
      await _repo.eliminar(asistencia.id);

      state = state.copyWith(
        asistencias: state.asistencias.where((a) => a.id != asistencia.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
        porQr: state.porQr - (asistencia.esQr ? 1 : 0),
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
  void _reemplazar(Asistencia actualizada) {
    final lista = state.asistencias
        .map((a) => a.id == actualizada.id ? actualizada : a)
        .toList();

    state = state.copyWith(
      asistencias: lista,
      porQr: lista.where((a) => a.esQr).length,
      limpiarError: true,
    );
  }
}

final asistenciasControllerProvider =
    NotifierProvider<AsistenciasController, AsistenciasState>(AsistenciasController.new);

/// Filtros de la lista de asistencias.
///
/// Un provider aparte del que carga: así el `build` de `AsistenciasController`
/// puede leerlos sin depender de su propio estado.
class FiltrosAsistenciasController extends Notifier<FiltrosAsistencias> {
  @override
  FiltrosAsistencias build() => const FiltrosAsistencias();

  void filtrarPorEvento(String evento) {
    state = state.copyWith(evento: evento);
  }

  void filtrarPorRegistro(String? registradoPor) {
    state = state.copyWith(
      registradoPor: registradoPor,
      limpiarRegistro: registradoPor == null,
    );
  }

  void filtrarPorFecha(String fecha) {
    state = state.copyWith(fecha: fecha);
  }

  void limpiar() {
    state = const FiltrosAsistencias();
  }
}

final filtrosAsistenciasProvider =
    NotifierProvider<FiltrosAsistenciasController, FiltrosAsistencias>(
  FiltrosAsistenciasController.new,
);