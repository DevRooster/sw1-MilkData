import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/evento_api.dart';
import '../../domain/evento.dart';

final eventoApiProvider = Provider<EventoApi>((ref) {
  return EventoApi(ref.watch(apiClientProvider));
});

final eventoRepositoryProvider = Provider<EventoRepository>((ref) {
  return EventoRepository(api: ref.watch(eventoApiProvider));
});

/// Repositorio de `/eventos`.
class EventoRepository {
  EventoRepository({required this.api});

  final EventoApi api;

  Future<EventosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? nombre,
    String? busqueda,
    String? lugar,
    String? fecha,
    String? desde,
    String? hasta,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      nombre: nombre,
      busqueda: busqueda,
      lugar: lugar,
      fecha: fecha,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<Evento> ver(int id) => api.ver(id);

  Future<Evento> crear({
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) {
    return api.crear(nombre: nombre, fecha: fecha, lugar: lugar, descripcion: descripcion);
  }

  Future<Evento> editar(
    int id, {
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) {
    return api.editar(id, nombre: nombre, fecha: fecha, lugar: lugar, descripcion: descripcion);
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}

/// Estado de la lista de eventos.
class EventosState {
  const EventosState({
    this.eventos = const <Evento>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.proximos = 0,
    this.cargando = false,
    this.error,
  });

  final List<Evento> eventos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;
  final AppException? error;

  /// Cuántos de **esta página** todavía no han pasado.
  ///
  /// Un evento que ya se dio es historia; uno que no se ha dado es a lo que hay
  /// que apuntar. Mezclados en la misma lista, saber cuál es cuál es lo primero
  /// que se mira.
  final int proximos;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  EventosState copyWith({
    List<Evento>? eventos,
    int? pagina,
    int? totalPaginas,
    int? total,
    int? proximos,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return EventosState(
      eventos: eventos ?? this.eventos,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      proximos: proximos ?? this.proximos,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosEventos {
  const FiltrosEventos({this.texto = '', this.desde = '', this.hasta = ''});

  /// Busca en nombre, sitio y descripción.
  final String texto;

  /// Rango de fechas, `YYYY-MM-DD`. Vacío es todos.
  final String desde;
  final String hasta;

  bool get hayAlguno => texto.isNotEmpty || desde.isNotEmpty || hasta.isNotEmpty;

  FiltrosEventos copyWith({String? texto, String? desde, String? hasta}) {
    return FiltrosEventos(
      texto: texto ?? this.texto,
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
    );
  }
}

/// Carga los eventos y ejecuta acciones sobre cada uno.
class EventosController extends Notifier<EventosState> {
  static const int limite = 10;

  @override
  EventosState build() {
    Future<void>.microtask(() => unawaited(cargar()));
    return const EventosState();
  }

  EventoRepository get _repo => ref.read(eventoRepositoryProvider);

  FiltrosEventos get _filtros => ref.read(filtrosEventosProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        busqueda: filtros.texto,
        desde: filtros.desde,
        hasta: filtros.hasta,
      );

      state = state.copyWith(
        eventos: resultado.eventos,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        proximos: resultado.eventos.where((e) => !e.yaPaso).length,
        cargando: false,
      );
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  Future<void> irAPagina(int numero) => cargar(pagina: numero);

  void _volverAPrimero() {
    state = state.copyWith(pagina: 1);
  }

  Future<void> filtrarPorTexto(String texto) async {
    ref.read(filtrosEventosProvider.notifier).filtrarPorTexto(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> filtrarPorRango(String desde, String hasta) async {
    ref.read(filtrosEventosProvider.notifier).filtrarPorRango(desde, hasta);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosEventosProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  Future<bool> crear({
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    try {
      await _repo.crear(nombre: nombre, fecha: fecha, lugar: lugar, descripcion: descripcion);
      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<bool> editar(
    Evento evento, {
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    try {
      final actualizado = await _repo.editar(
        evento.id,
        nombre: nombre,
        fecha: fecha,
        lugar: lugar,
        descripcion: descripcion,
      );

      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Evento evento) async {
    try {
      await _repo.eliminar(evento.id);

      state = state.copyWith(
        eventos: state.eventos.where((e) => e.id != evento.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
        proximos: state.proximos - (evento.yaPaso ? 0 : 1),
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

  void _reemplazar(Evento actualizado) {
    final lista = state.eventos
        .map((e) => e.id == actualizado.id ? actualizado : e)
        .toList();

    state = state.copyWith(
      eventos: lista,
      proximos: lista.where((e) => !e.yaPaso).length,
      limpiarError: true,
    );
  }
}

final eventosControllerProvider =
    NotifierProvider<EventosController, EventosState>(EventosController.new);

/// Filtros de la lista de eventos.
class FiltrosEventosController extends Notifier<FiltrosEventos> {
  @override
  FiltrosEventos build() => const FiltrosEventos();

  void filtrarPorTexto(String texto) {
    state = state.copyWith(texto: texto);
  }

  void filtrarPorRango(String desde, String hasta) {
    state = state.copyWith(desde: desde, hasta: hasta);
  }

  void limpiar() {
    state = const FiltrosEventos();
  }
}

final filtrosEventosProvider =
    NotifierProvider<FiltrosEventosController, FiltrosEventos>(FiltrosEventosController.new);

/// Los eventos para el desplegable de Asistencias.
///
/// Va aparte de la lista de la pantalla: el desplegable quiere **los que no han
/// pasado** —apuntar una asistencia a una charla de hace un mes no tiene sentido—
/// y en orden de fecha, no en el orden de alta en que los dejó el servidor.
final eventosParaElegirProvider = FutureProvider<List<Evento>>((ref) async {
  final pagina = await ref.watch(eventoApiProvider).listar(limite: 50, desde: _hoy());
  return pagina.eventos.where((e) => !e.yaPaso).toList();
});

String _hoy() {
  final ahora = DateTime.now();
  return '${ahora.year.toString().padLeft(4, '0')}-'
      '${ahora.month.toString().padLeft(2, '0')}-'
      '${ahora.day.toString().padLeft(2, '0')}';
}
