import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../recolecciones/domain/recoleccion.dart';
import '../../../recolecciones/presentation/providers/recolecciones_controller.dart';
import '../../data/calidad_api.dart';
import '../../data/calidad_repository.dart';
import '../../domain/control_calidad.dart';

final calidadApiProvider = Provider<CalidadApi>((ref) {
  return CalidadApi(ref.watch(apiClientProvider));
});

final calidadRepositoryProvider = Provider<CalidadRepository>((ref) {
  return CalidadRepository(api: ref.watch(calidadApiProvider));
});

/// Estado de la lista de controles de calidad.
class CalidadState {
  const CalidadState({
    this.controles = const <ControlCalidad>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.adulterados = 0,
    this.cargando = false,
    this.error,
  });

  final List<ControlCalidad> controles;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Cuántos de **esta página** salieron adulterados.
  ///
  /// De la página y no del total paginado: para el total harían falta todas las
  /// filas, y un número que crece al pasar de página y mengua al
  /// retroceder daría más confianza de la que tiene.
  final int adulterados;

  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  CalidadState copyWith({
    List<ControlCalidad>? controles,
    int? pagina,
    int? totalPaginas,
    int? total,
    int? adulterados,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return CalidadState(
      controles: controles ?? this.controles,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      adulterados: adulterados ?? this.adulterados,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosCalidad {
  const FiltrosCalidad({this.resultado});

  /// `pura`, `adulterada`, o `null` para las dos.
  ///
  /// El texto del `ENUM` de la base va directo en el estado, y no el nombre de un
  /// enumerado de Dart: son dos valores y una traducción, y traducirla aquí
  /// sería un sitio más donde equivocarse.
  final String? resultado;

  bool get hayAlguno => resultado != null;

  FiltrosCalidad copyWith({String? resultado, bool limpiar = false}) {
    return FiltrosCalidad(
      // Sin `limpiar` no se podría volver a "todas": `null` es justo el valor
      // que significa eso.
      resultado: limpiar ? null : (resultado ?? this.resultado),
    );
  }
}

/// Carga la lista de controles y ejecuta las acciones sobre cada uno.
class CalidadController extends Notifier<CalidadState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  CalidadState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const CalidadState();
  }

  CalidadRepository get _repo => ref.read(calidadRepositoryProvider);

  FiltrosCalidad get _filtros => ref.read(filtrosCalidadProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        resultado: filtros.resultado,
      );

      state = state.copyWith(
        controles: resultado.controles,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        adulterados: resultado.controles.where((c) => c.esAdulterada).length,
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

  Future<void> filtrarPorResultado(String? resultado) async {
    ref.read(filtrosCalidadProvider.notifier).filtrarPorResultado(resultado);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosCalidadProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea un control y recarga la lista.
  ///
  /// Devuelve `false` y deja el error en el estado cuando el servidor rechaza.
  /// El rechazo que se espera aquí es el de la recolectora única: si esa
  /// recolección ya tenía análisis, se rechaza con un 400.
  Future<bool> crear({
    required int recoleccionId,
    required int usuarioId,
    String resultado = ControlCalidad.pura,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) async {
    try {
      await _repo.crear(
        recoleccionId: recoleccionId,
        usuarioId: usuarioId,
        resultado: resultado,
        grasa: grasa,
        proteina: proteina,
        lactosa: lactosa,
        densidad: densidad,
        temperatura: temperatura,
        aguaAnadida: aguaAnadida,
        ph: ph,
      );

      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de un control.
  Future<bool> editar(
    ControlCalidad control, {
    int? recoleccionId,
    int? usuarioId,
    String? resultado,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
    bool limpiarGrasa = false,
    bool limpiarProteina = false,
    bool limpiarLactosa = false,
    bool limpiarDensidad = false,
    bool limpiarTemperatura = false,
    bool limpiarAguaAnadida = false,
    bool limpiarPh = false,
  }) async {
    try {
      final actualizado = await _repo.editar(
        control.id,
        recoleccionId: recoleccionId ?? control.recoleccionId,
        usuarioId: usuarioId ?? control.usuarioId,
        resultado: resultado,
        grasa: grasa,
        proteina: proteina,
        lactosa: lactosa,
        densidad: densidad,
        temperatura: temperatura,
        aguaAnadida: aguaAnadida,
        ph: ph,
      );

      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(ControlCalidad control) async {
    try {
      await _repo.eliminar(control.id);

      state = state.copyWith(
        controles: state.controles.where((c) => c.id != control.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
        adulterados: state.adulterados - (control.esAdulterada ? 1 : 0),
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
  void _reemplazar(ControlCalidad actualizado) {
    final lista = state.controles
        .map((c) => c.id == actualizado.id ? actualizado : c)
        .toList();

    state = state.copyWith(
      controles: lista,
      adulterados: lista.where((c) => c.esAdulterada).length,
      limpiarError: true,
    );
  }
}

final calidadControllerProvider =
    NotifierProvider<CalidadController, CalidadState>(CalidadController.new);

/// Filtros de la lista de controles.
///
/// Un provider aparte del que carga: así el `build` de `CalidadController` puede
/// leerlos sin depender de su propio estado.
class FiltrosCalidadController extends Notifier<FiltrosCalidad> {
  @override
  FiltrosCalidad build() => const FiltrosCalidad();

  void filtrarPorResultado(String? resultado) {
    state = state.copyWith(resultado: resultado, limpiar: resultado == null);
  }

  void limpiar() {
    state = const FiltrosCalidad();
  }
}

final filtrosCalidadProvider =
    NotifierProvider<FiltrosCalidadController, FiltrosCalidad>(FiltrosCalidadController.new);

/// Las recolecciones que **todavía no tienen análisis**.
///
/// Esta es la regla de una recolección, un análisis, puesta donde sirve:
/// `recoleccionId` es único en la base, así que un segundo análisis de la misma
/// recogida se rechaza con un 400. Filtrar aquí es lo que evita que alguien
/// escriba las siete mediciones y solo entonces descubra que esa leche ya se
/// había analizado.
///
/// Se cruzan dos peticiones y no N: una a /calidad para saber qué está ocupado,
/// y otra a /recolecciones para traer las fechas y los litros.
/// Preguntar a /calidad/recoleccion por id una por una serían decenas de viajes.
final recoleccionesParaAnalizarProvider = FutureProvider<List<Recoleccion>>((ref) async {
  final controles = await ref.watch(calidadRepositoryProvider).listar(limite: topeParaCruzar);
  final recolecciones = await ref.watch(recoleccionRepositoryProvider).listar(limite: topeParaCruzar);

  final ocupadas = controles.controles.map((c) => c.recoleccionId).toSet();

  return recolecciones.recolecciones.where((r) => !ocupadas.contains(r.id)).toList();
});

/// Cuántas filas se cruzan para montar la lista anterior.
///
/// Las dos peticiones comparten tope y motivo: no traer medio millar de filas
/// para un desplegable. Así que el número va en un sitio y no repetido dos
/// veces. Si el servidor limitara el parámetro limite, este sería lo único que habría que
/// revisar.
const int topeParaCruzar = 100;
