import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/proveedor_api.dart';
import '../../data/proveedor_repository.dart';
import '../../domain/proveedor.dart';

final proveedorApiProvider = Provider<ProveedorApi>((ref) {
  return ProveedorApi(ref.watch(apiClientProvider));
});

final proveedorRepositoryProvider = Provider<ProveedorRepository>((ref) {
  return ProveedorRepository(api: ref.watch(proveedorApiProvider));
});

/// Estado de la lista de proveedores.
class ProveedoresState {
  const ProveedoresState({
    this.proveedores = const <Proveedor>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<Proveedor> proveedores;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  ProveedoresState copyWith({
    List<Proveedor>? proveedores,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return ProveedoresState(
      proveedores: proveedores ?? this.proveedores,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosProveedores {
  const FiltrosProveedores({this.soloInactivos = false, this.busqueda = ''});

  /// Muestra los **inactivos**, que son los pocos. El nombre va al revés de la
  /// pantalla a propósito: si se llamara `soloActivos`, "sin marcar" tendría que
  /// significar "todas" y haría falta un estado más.
  final bool soloInactivos;
  final String busqueda;

  bool get hayAlguno => soloInactivos || busqueda.isNotEmpty;

  FiltrosProveedores copyWith({bool? soloInactivos, String? busqueda}) {
    return FiltrosProveedores(
      soloInactivos: soloInactivos ?? this.soloInactivos,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de proveedores y ejecuta las acciones sobre cada uno.
class ProveedoresController extends Notifier<ProveedoresState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  ProveedoresState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const ProveedoresState();
  }

  ProveedorRepository get _repo => ref.read(proveedorRepositoryProvider);

  FiltrosProveedores get _filtros => ref.read(filtrosProveedoresProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        busqueda: filtros.busqueda,
        activo: filtros.soloInactivos ? false : null,
      );

      state = state.copyWith(
        proveedores: resultado.proveedores,
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

  Future<void> alternarSoloInactivos() async {
    ref.read(filtrosProveedoresProvider.notifier).alternarSoloInactivos();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosProveedoresProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosProveedoresProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea un proveedor y recarga la lista.
  ///
  /// **`rutaId` no se acepta como parámetro**, a propósito: mandarlo —incluso
  /// valiendo `null`— hace que el backend rechace el alta con un 400. Quien
  /// asigne un proveedor a una ruta lo hace desde las paradas de esa ruta.
  Future<bool> crear({
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    try {
      await _repo.crear(
        nombre: nombre,
        apellido: apellido,
        dni: dni,
        telefono: telefono,
        direccion: direccion,
        zonaId: zonaId,
        activo: activo,
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

  /// Guarda los cambios de un proveedor.
  Future<bool> editar(
    Proveedor proveedor, {
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    try {
      final actualizado = await _repo.editar(
        proveedor.id,
        nombre: nombre,
        apellido: apellido,
        dni: dni,
        telefono: telefono,
        direccion: direccion,
        zonaId: zonaId,
        activo: activo,
      );

      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Proveedor proveedor) async {
    try {
      await _repo.eliminar(proveedor.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró, y
      // recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        proveedores:
            state.proveedores.where((p) => p.id != proveedor.id).toList(),
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
  void _reemplazar(Proveedor actualizado) {
    final lista = state.proveedores
        .map((p) => p.id == actualizado.id ? actualizado : p)
        .toList();

    state = state.copyWith(proveedores: lista, limpiarError: true);
  }
}

final proveedoresControllerProvider =
    NotifierProvider<ProveedoresController, ProveedoresState>(
  ProveedoresController.new,
);

/// Filtros de la lista de proveedores.
///
/// Un provider aparte del que carga: así el `build` de `ProveedoresController`
/// puede leerlos sin depender de su propio estado.
class FiltrosProveedoresController extends Notifier<FiltrosProveedores> {
  @override
  FiltrosProveedores build() => const FiltrosProveedores();

  void alternarSoloInactivos() {
    state = state.copyWith(soloInactivos: !state.soloInactivos);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }

  void limpiar() {
    state = const FiltrosProveedores();
  }
}

final filtrosProveedoresProvider =
    NotifierProvider<FiltrosProveedoresController, FiltrosProveedores>(
  FiltrosProveedoresController.new,
);

/// Los proveedores, para el desplegable de otros módulos.
///
/// Vive aquí y no en cada módulo que lo necesite: Recolecciones elige un
/// proveedor en cada alta, y pedirlo desde los dos sitios son dos listas que
/// pueden quedar sin sincronizar.
///
/// Se piden solo los activos: dar de alta una recolección a un proveedor dado de
/// baja es una excepción que hay que justificar, no el caso normal.
final opcionesDeProveedorProvider = FutureProvider<List<ReferenciaProveedor>>((ref) async {
  final proveedores = await ref.watch(proveedorRepositoryProvider).listar(limite: 100, activo: true);

  return proveedores.proveedores.map(ReferenciaProveedor.nueva).toList();
});

/// Un proveedor para un desplegable: lo que se enseña y lo que se devuelve.
class ReferenciaProveedor {
  const ReferenciaProveedor({required this.id, required this.nombreCompleto});

  final int id;
  final String nombreCompleto;

  factory ReferenciaProveedor.nueva(Proveedor p) =>
      ReferenciaProveedor(id: p.id, nombreCompleto: p.nombreCompleto);
}
