import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/unidad_api.dart';
import '../../data/unidad_repository.dart';
import '../../domain/unidad.dart';

final unidadApiProvider = Provider<UnidadApi>((ref) {
  return UnidadApi(ref.watch(apiClientProvider));
});

final unidadRepositoryProvider = Provider<UnidadRepository>((ref) {
  return UnidadRepository(api: ref.watch(unidadApiProvider));
});

/// Estado de la lista de unidades.
class UnidadesState {
  const UnidadesState({
    this.unidades = const <Unidad>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<Unidad> unidades;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  UnidadesState copyWith({
    List<Unidad>? unidades,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return UnidadesState(
      unidades: unidades ?? this.unidades,
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
/// Van aparte del estado y no dentro de él, por el mismo motivo que en usuarios:
/// dentro, el `build` del controller tendría que leerlos para cargarse, y eso es
/// depender de su propio estado mientras se construye.
class FiltrosUnidades {
  const FiltrosUnidades({
    this.tipo,
    this.soloInactivos = false,
    this.soloCerradas = false,
    this.busqueda = '',
  });

  /// Tipo de unidad elegido, o `null` para todos.
  final TipoUnidad? tipo;

  /// Al revés de lo natural: muestra las **inactivas**, que son las pocas.
  ///
  /// El nombre lo dice al revés de la pantalla a propósito. Si se llamara
  /// `soloActivos`, "sin marcar" significaría "todas" y habría que añadir un
  /// estado más para distinguir "todas" de "solo activas".
  final bool soloInactivos;
  final bool soloCerradas;
  final String busqueda;

  bool get hayAlguno =>
      tipo != null || soloInactivos || soloCerradas || busqueda.isNotEmpty;

  FiltrosUnidades copyWith({
    TipoUnidad? tipo,
    bool limpiarTipo = false,
    bool? soloInactivos,
    bool? soloCerradas,
    String? busqueda,
  }) {
    return FiltrosUnidades(
      // Sin `limpiarTipo` no se podría volver a "Todos": `null` es justo el
      // valor que significa eso.
      tipo: limpiarTipo ? null : (tipo ?? this.tipo),
      soloInactivos: soloInactivos ?? this.soloInactivos,
      soloCerradas: soloCerradas ?? this.soloCerradas,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de unidades y ejecuta las acciones sobre cada una.
class UnidadesController extends Notifier<UnidadesState> {
  /// Peticiones por página.
  ///
  /// Diez es el tamaño con el que la API responde por defecto y cabe en pantalla
  /// sin paginar.
  static const int limite = 10;

  @override
  UnidadesState build() {
    // Fuera del `build` a propósito: aquí el estado todavía no está
    // inicializado, y escribir en él daría el aviso de provider sin
    // inicializar y parecería que se depende de sí mismo.
    Future<void>.microtask(() => unawaited(cargar()));
    return const UnidadesState();
  }

  UnidadRepository get _repo => ref.read(unidadRepositoryProvider);

  FiltrosUnidades get _filtros => ref.read(filtrosUnidadesProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        tipo: filtros.tipo?.valor,
        activo: filtros.soloInactivos ? false : null,
        cerrado: filtros.soloCerradas ? true : null,
        busqueda: filtros.busqueda,
      );

      state = state.copyWith(
        unidades: resultado.unidades,
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

  Future<void> filtrarPorTipo(TipoUnidad? tipo) async {
    ref.read(filtrosUnidadesProvider.notifier).filtrarPorTipo(tipo);
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloInactivos() async {
    ref.read(filtrosUnidadesProvider.notifier).alternarSoloInactivos();
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloCerradas() async {
    ref.read(filtrosUnidadesProvider.notifier).alternarSoloCerradas();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosUnidadesProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  /// Quita todos los filtros de golpe.
  Future<void> limpiarFiltros() async {
    ref.read(filtrosUnidadesProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea una unidad y la pone arriba de la lista.
  Future<bool> crear({
    required String nombre,
    required TipoUnidad tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    try {
      await _repo.crear(
        nombre: nombre,
        tipo: tipo.valor,
        capacidad: capacidad,
        cerrado: cerrado,
        activo: activo,
        acopiadorId: acopiadorId,
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

  /// Guarda los cambios de una unidad.
  Future<bool> editar(
    Unidad unidad, {
    required String nombre,
    required TipoUnidad tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    try {
      final actualizado = await _repo.editar(
        unidad.id,
        nombre: nombre,
        tipo: tipo.valor,
        capacidad: capacidad,
        cerrado: cerrado,
        activo: activo,
        acopiadorId: acopiadorId,
      );

      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Elimina una unidad.
  Future<void> eliminar(Unidad unidad) async {
    try {
      await _repo.eliminar(unidad.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró, y
      // recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        unidades: state.unidades.where((u) => u.id != unidad.id).toList(),
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
  void _reemplazar(Unidad actualizado) {
    final lista = state.unidades
        .map((u) => u.id == actualizado.id ? actualizado : u)
        .toList();

    state = state.copyWith(unidades: lista, limpiarError: true);
  }
}

final unidadesControllerProvider = NotifierProvider<UnidadesController, UnidadesState>(
  UnidadesController.new,
);

/// Filtros de la lista de unidades.
///
/// Un provider aparte del que carga: así el `build` de `UnidadesController` puede
/// leerlos sin depender de su propio estado.
class FiltrosUnidadesController extends Notifier<FiltrosUnidades> {
  @override
  FiltrosUnidades build() => const FiltrosUnidades();

  void filtrarPorTipo(TipoUnidad? tipo) {
    state = state.copyWith(tipo: tipo, limpiarTipo: tipo == null);
  }

  void alternarSoloInactivos() {
    state = state.copyWith(soloInactivos: !state.soloInactivos);
  }

  void alternarSoloCerradas() {
    state = state.copyWith(soloCerradas: !state.soloCerradas);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }

  void limpiar() {
    state = const FiltrosUnidades();
  }
}

final filtrosUnidadesProvider = NotifierProvider<FiltrosUnidadesController, FiltrosUnidades>(
  FiltrosUnidadesController.new,
);
/// Las unidades, para el desplegable de otros módulos.
///
/// Vive aquí y no en cada módulo que lo necesite: Zonas y Recorridos eligen una
/// unidad, y pedirlo desde los tres sitios son tres listas que pueden quedar sin
/// sincronizar.
///
/// Se piden solo las activas: una unidad cerrada o inactiva no es una opción a la
/// que planear un recorrido encima.
final opcionesDeUnidadProvider = FutureProvider<List<ReferenciaUnidad>>((ref) async {
  final unidades = await ref.watch(unidadRepositoryProvider).listar(limite: 100, activo: true);

  return unidades.unidades.map(ReferenciaUnidad.nueva).toList();
});

/// Una unidad para un desplegable: lo que se enseña y lo que se devuelve.
class ReferenciaUnidad {
  const ReferenciaUnidad({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory ReferenciaUnidad.nueva(Unidad unidad) =>
      ReferenciaUnidad(id: unidad.id, nombre: unidad.nombre);
}