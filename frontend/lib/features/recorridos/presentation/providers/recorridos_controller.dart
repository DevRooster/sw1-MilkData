import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/recorrido_api.dart';
import '../../data/recorrido_repository.dart';
import '../../domain/recorrido.dart';

final recorridoApiProvider = Provider<RecorridoApi>((ref) {
  return RecorridoApi(ref.watch(apiClientProvider));
});

final recorridoRepositoryProvider = Provider<RecorridoRepository>((ref) {
  return RecorridoRepository(api: ref.watch(recorridoApiProvider));
});

/// Estado de la lista de recorridos.
class RecorridosState {
  const RecorridosState({
    this.recorridos = const <Recorrido>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.enAccion = false,
    this.error,
  });

  final List<Recorrido> recorridos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Hay una transición en curso —iniciar, finalizar, atender una parada—.
  ///
  /// Va aparte de `cargando` porque bloquean la pantalla de otra manera: la
  /// `cargando` deja ver la lista vieja mientras llega la nueva, y una
  /// transición tiene que bloquear los botones para que no se pulse dos veces.
  /// Sin esto, dos toques seguidos en "Iniciar" serían dos peticiones.
  final bool enAccion;

  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  RecorridosState copyWith({
    List<Recorrido>? recorridos,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    bool? enAccion,
    AppException? error,
    bool limpiarError = false,
  }) {
    return RecorridosState(
      recorridos: recorridos ?? this.recorridos,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      cargando: cargando ?? this.cargando,
      enAccion: enAccion ?? this.enAccion,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosRecorridos {
  const FiltrosRecorridos({this.estado, this.fecha = ''});

  /// Estado por el que se filtra, o `null` para todos.
  ///
  /// El enumerado va entero y no como texto porque es el que la pantalla usa;
  /// el texto del servidor se decide en la capa de API.
  final EstadoRecorrido? estado;

  /// Un día concreto, `YYYY-MM-DD`. Vacío es todos.
  final String fecha;

  bool get hayAlguno => estado != null || fecha.isNotEmpty;

  FiltrosRecorridos copyWith({
    EstadoRecorrido? estado,
    bool limpiarEstado = false,
    String? fecha,
  }) {
    return FiltrosRecorridos(
      // Sin `limpiarEstado` no se podría volver a "Todos": `null` es justo el
      // valor que significa eso.
      estado: limpiarEstado ? null : (estado ?? this.estado),
      fecha: fecha ?? this.fecha,
    );
  }
}

/// Carga la lista de recorridos y ejecuta el ciclo de vida sobre cada uno.
class RecorridosController extends Notifier<RecorridosState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  RecorridosState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const RecorridosState();
  }

  RecorridoRepository get _repo => ref.read(recorridoRepositoryProvider);

  FiltrosRecorridos get _filtros => ref.read(filtrosRecorridosProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        estado: filtros.estado,
        fecha: filtros.fecha,
      );

      state = state.copyWith(
        recorridos: resultado.recorridos,
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

  Future<void> filtrarPorEstado(EstadoRecorrido? estado) async {
    ref.read(filtrosRecorridosProvider.notifier).filtrarPorEstado(estado);
    _volverAPrimero();
    await cargar();
  }

  Future<void> filtrarPorFecha(String fecha) async {
    ref.read(filtrosRecorridosProvider.notifier).filtrarPorFecha(fecha);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosRecorridosProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// El recorrido en curso de este acopiador, o `null`.
  ///
  /// Vive aquí y no en la lista porque lo consulta el detalle y el lanzador, no
  /// la tabla: son dos pantallas distintas con la misma pregunta.
  Future<Recorrido?> actual() async {
    try {
      return await _repo.actual();
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return null;
    }
  }

  /// Crea un recorrido y recarga la lista.
  Future<bool> crear({
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    try {
      await _repo.crear(
        rutaId: rutaId,
        unidadId: unidadId,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        ayudanteUsuarioId: ayudanteUsuarioId,
        ayudanteNombre: ayudanteNombre,
        ayudanteApellido: ayudanteApellido,
        ayudanteDni: ayudanteDni,
        ayudanteCelular: ayudanteCelular,
        observaciones: observaciones,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de un recorrido.
  Future<bool> editar(
    Recorrido recorrido, {
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    try {
      await _repo.editar(
        recorrido.id,
        rutaId: rutaId,
        unidadId: unidadId,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        ayudanteUsuarioId: ayudanteUsuarioId,
        ayudanteNombre: ayudanteNombre,
        ayudanteApellido: ayudanteApellido,
        ayudanteDni: ayudanteDni,
        ayudanteCelular: ayudanteCelular,
        observaciones: observaciones,
      );

      await cargar();
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Recorrido recorrido) async {
    try {
      await _repo.eliminar(recorrido.id);

      state = state.copyWith(
        recorridos: state.recorridos.where((r) => r.id != recorrido.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// `POST /recorridos/{id}/iniciar`
  ///
  /// **Sella las paradas de la ruta** y pone la hora y fecha reales, así que la
  /// respuesta no es el mismo recorrido con otro estado: trae paradas donde antes
  /// no había ninguna. Por eso se reemplaza la fila entera en vez de tocar solo
  /// el estado.
  Future<bool> iniciar(Recorrido recorrido) => _transicion(recorrido, (r) => r.iniciar(recorrido.id));

  /// `POST /recorridos/{id}/finalizar`
  ///
  /// Marca como `OMITIDA` las paradas que sigan pendientes.
  Future<bool> finalizar(Recorrido recorrido) =>
      _transicion(recorrido, (r) => r.finalizar(recorrido.id));

  /// `POST /recorridos/{id}/cancelar`
  Future<bool> cancelar(Recorrido recorrido, {String? observaciones}) => _transicion(
        recorrido,
        (r) => r.cancelar(recorrido.id, observaciones: observaciones),
      );

  /// `POST /recorridos/{id}/paradas/{paradaId}/atender`
  Future<bool> atenderParada(Recorrido recorrido, ParadaRecorrido parada) =>
      _transicion(recorrido, (r) => r.atenderParada(recorrido.id, parada.id));

  /// Las cinco transiciones comparten el mismo cuerpo: bloquear, llamar,
  /// reemplazar la fila con lo que devuelve el servidor, desbloquear.
  ///
  /// Devuelven si salió bien para que la pantalla pueda decidir si se queda
  /// abierta o se va.
  Future<bool> _transicion(
    Recorrido recorrido,
    Future<Recorrido> Function(RecorridoRepository) llamada,
  ) async {
    if (state.enAccion) {
      // Un doble toque no llega al servidor. `enAccion` se pone a verdad
      // inmediatamente, antes de la primera línea async, y por eso esto
      // funciona: no hay ningún hueco en el que el segundo toque se cuele.
      return false;
    }

    state = state.copyWith(enAccion: true, limpiarError: true);

    try {
      final actualizado = await llamada(_repo);
      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    } finally {
      state = state.copyWith(enAccion: false);
    }
  }

  void limpiarError() {
    if (state.error != null) {
      state = state.copyWith(limpiarError: true);
    }
  }

  /// Cambia una fila por su versión actualizada, conservando el orden.
  void _reemplazar(Recorrido actualizado) {
    // Si el recorrido no está en esta página —porque se filtró o se paginó— no
    // se inserta: meterlo en una lista que no lo contiene la descoloca.
    if (!state.recorridos.any((r) => r.id == actualizado.id)) {
      return;
    }

    final lista = state.recorridos
        .map((r) => r.id == actualizado.id ? actualizado : r)
        .toList();

    state = state.copyWith(recorridos: lista, limpiarError: true);
  }
}

final recorridosControllerProvider =
    NotifierProvider<RecorridosController, RecorridosState>(
  RecorridosController.new,
);

/// Filtros de la lista de recorridos.
///
/// Un provider aparte del que carga: así el `build` de `RecorridosController`
/// puede leerlos sin depender de su propio estado.
class FiltrosRecorridosController extends Notifier<FiltrosRecorridos> {
  @override
  FiltrosRecorridos build() => const FiltrosRecorridos();

  void filtrarPorEstado(EstadoRecorrido? estado) {
    state = state.copyWith(estado: estado, limpiarEstado: estado == null);
  }

  void filtrarPorFecha(String fecha) {
    state = state.copyWith(fecha: fecha);
  }

  void limpiar() {
    state = const FiltrosRecorridos();
  }
}

final filtrosRecorridosProvider =
    NotifierProvider<FiltrosRecorridosController, FiltrosRecorridos>(
  FiltrosRecorridosController.new,
);
