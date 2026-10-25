import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/avisos_locales.dart';
import '../../data/notificacion_api.dart';
import '../../data/notificacion_repository.dart';
import '../../domain/notificacion.dart';

final notificacionApiProvider = Provider<NotificacionApi>((ref) {
  return NotificacionApi(ref.watch(apiClientProvider));
});

final notificacionRepositoryProvider = Provider<NotificacionRepository>((ref) {
  return NotificacionRepository(api: ref.watch(notificacionApiProvider));
});

/// Publica en la barra del sistema lo que aún no se ha enseñado.
///
/// Provider aparte para poder sustituirlo entero en las pruebas: el plugin de
/// notificaciones necesita un móvil de verdad, y sin este hueco estas pruebas no
/// se podrían escribir.
final avisosLocalesProvider = Provider<AvisosLocales>((ref) {
  return AvisosLocales(marca: MarcaEnAlmacenamiento());
});

/// Estado de la lista de avisos.
class NotificacionesState {
  const NotificacionesState({
    this.notificaciones = const <Notificacion>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.sinLeer = 0,
    this.borradores = 0,
    this.cargando = false,
    this.error,
  });

  final List<Notificacion> notificaciones;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Cuántas de **esta página** siguen sin leer.
  final int sinLeer;

  /// Cuántas de esta página solo se guardaron y no salieron.
  final int borradores;

  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  NotificacionesState copyWith({
    List<Notificacion>? notificaciones,
    int? pagina,
    int? totalPaginas,
    int? total,
    int? sinLeer,
    int? borradores,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return NotificacionesState(
      notificaciones: notificaciones ?? this.notificaciones,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      sinLeer: sinLeer ?? this.sinLeer,
      borradores: borradores ?? this.borradores,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosNotificaciones {
  const FiltrosNotificaciones({this.tipo, this.soloSinLeer = false, this.soloBorradores = false});

  /// `adulteracion`, `reunion`, `capacitacion`, o `null` para los tres.
  final String? tipo;

  /// Solo las que aún no se han leído.
  ///
  /// El nombre va al revés de la pantalla a propósito: si se llamara
  /// `soloLeidas`, "sin marcar" tendría que significar "todas".
  final bool soloSinLeer;

  /// Solo las que se guardaron pero no salieron.
  final bool soloBorradores;

  bool get hayAlguno => tipo != null || soloSinLeer || soloBorradores;

  FiltrosNotificaciones copyWith({
    String? tipo,
    bool limpiarTipo = false,
    bool? soloSinLeer,
    bool? soloBorradores,
  }) {
    return FiltrosNotificaciones(
      // Sin `limpiarTipo` no se podría volver a "todos": `null` es justo el
      // valor que significa eso.
      tipo: limpiarTipo ? null : (tipo ?? this.tipo),
      soloSinLeer: soloSinLeer ?? this.soloSinLeer,
      soloBorradores: soloBorradores ?? this.soloBorradores,
    );
  }
}

/// Carga la lista de avisos y ejecuta las acciones sobre cada uno.
class NotificacionesController extends Notifier<NotificacionesState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  NotificacionesState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const NotificacionesState();
  }

  NotificacionRepository get _repo => ref.read(notificacionRepositoryProvider);

  FiltrosNotificaciones get _filtros => ref.read(filtrosNotificacionesProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        tipo: filtros.tipo,
        // Los dos booleanos van a `null` cuando el filtro está apagado, y no a
        // `false`: `false` preguntaría "solo las leídas" y dejaría fuera
        // justamente lo que se quiere ver.
        leida: filtros.soloSinLeer ? false : null,
        enviada: filtros.soloBorradores ? false : null,
      );

      state = state.copyWith(
        notificaciones: resultado.notificaciones,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        sinLeer: resultado.notificaciones.where((n) => !n.leida).length,
        borradores: resultado.notificaciones.where((n) => n.esBorrador).length,
        cargando: false,
      );

      // Avisa de lo nuevo, pero **solo de la primera página sin filtros**. Con un
      // filtro puesto, lo que sale son avisos viejos que el usuario está
      // buscando a propósito, y avisar de ellos sería molestar por lo que acaba
      // de decidir mirar.
      if (pagina == null && !filtros.hayAlguno) {
        await _avisarDeLoNuevo(resultado.notificaciones);
      }
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  /// Publica en la barra del sistema los avisos que aún no se habían enseñado.
  ///
  /// Va aparte y con su propio `try` porque **avisar nunca debe romper la
  /// lista**: un móvil donde el plugin falla tiene que seguir enseñando los
  /// avisos, solo que sin aviso del sistema.
  Future<void> _avisarDeLoNuevo(List<Notificacion> avisos) async {
    try {
      final locales = ref.read(avisosLocalesProvider);
      await locales.inicializar();
      await locales.avisar(avisos);
    } catch (error) {
      debugPrint('No se pudieron avisar de las notificaciones: $error');
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

  Future<void> filtrarPorTipo(String? tipo) async {
    ref.read(filtrosNotificacionesProvider.notifier).filtrarPorTipo(tipo);
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloSinLeer() async {
    ref.read(filtrosNotificacionesProvider.notifier).alternarSoloSinLeer();
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloBorradores() async {
    ref.read(filtrosNotificacionesProvider.notifier).alternarSoloBorradores();
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosNotificacionesProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Marca un aviso como leído o no leído.
  ///
  /// **No recarga la lista**: la fila se cambia en sitio. Recargar entera por un
  /// cambio de una casilla tiraría la pantalla y volvería a la primera página
  /// justo cuando alguien está tachando cinco avisos seguidos.
  Future<bool> marcarLeida(Notificacion notificacion, bool leida) async {
    // Si ya está como se quiere, no se manda nada: un `PUT` inútil gastaría una
    // ida al servidor y podría fallar sin motivo.
    if (notificacion.leida == leida) {
      return true;
    }

    try {
      final actualizada = await _repo.editar(notificacion.id, leida: leida);

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Crea un **borrador**: queda guardado pero no sale hacia el proveedor.
  Future<bool> crear({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    try {
      await _repo.crear(
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        proveedorId: proveedorId,
        usuarioId: usuarioId,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Crea un aviso y lo **manda** en el mismo paso.
  Future<bool> enviar({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    try {
      await _repo.crearEnviada(
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        proveedorId: proveedorId,
        usuarioId: usuarioId,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de un aviso.
  ///
  /// **Solo manda `enviada` nunca**, ni siquiera para intentar retirar uno: el
  /// servidor no borra la fecha al ponerla en `false` y el resultado sería un
  /// borrador con fecha de envío. Medido.
  Future<bool> editar(
    Notificacion notificacion, {
    String? tipo,
    String? titulo,
    String? mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    try {
      final actualizada = await _repo.editar(
        notificacion.id,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        // Aquí `null` significa "sin cambios", no "quitar el proveedor": quitar
        // un destinatario es un acto deliberado y lo decide la pantalla.
        proveedorId: proveedorId,
        usuarioId: usuarioId,
      );

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Notificacion notificacion) async {
    try {
      await _repo.eliminar(notificacion.id);

      state = state.copyWith(
        notificaciones:
            state.notificaciones.where((n) => n.id != notificacion.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
        sinLeer: state.sinLeer - (notificacion.leida ? 0 : 1),
        borradores: state.borradores - (notificacion.esBorrador ? 1 : 0),
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
  void _reemplazar(Notificacion actualizada) {
    final lista = state.notificaciones
        .map((n) => n.id == actualizada.id ? actualizada : n)
        .toList();

    state = state.copyWith(
      notificaciones: lista,
      sinLeer: lista.where((n) => !n.leida).length,
      borradores: lista.where((n) => n.esBorrador).length,
      limpiarError: true,
    );
  }
}

final notificacionesControllerProvider =
    NotifierProvider<NotificacionesController, NotificacionesState>(
  NotificacionesController.new,
);

/// Filtros de la lista de avisos.
///
/// Un provider aparte del que carga: así el `build` de
/// `NotificacionesController` puede leerlos sin depender de su propio estado.
class FiltrosNotificacionesController extends Notifier<FiltrosNotificaciones> {
  @override
  FiltrosNotificaciones build() => const FiltrosNotificaciones();

  void filtrarPorTipo(String? tipo) {
    state = state.copyWith(tipo: tipo, limpiarTipo: tipo == null);
  }

  void alternarSoloSinLeer() {
    state = state.copyWith(soloSinLeer: !state.soloSinLeer);
  }

  void alternarSoloBorradores() {
    state = state.copyWith(soloBorradores: !state.soloBorradores);
  }

  void limpiar() {
    state = const FiltrosNotificaciones();
  }
}

final filtrosNotificacionesProvider =
    NotifierProvider<FiltrosNotificacionesController, FiltrosNotificaciones>(
  FiltrosNotificacionesController.new,
);