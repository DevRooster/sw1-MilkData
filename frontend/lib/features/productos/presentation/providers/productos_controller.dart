import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/producto_api.dart';
import '../../data/producto_repository.dart';
import '../../domain/producto.dart';

final productoApiProvider = Provider<ProductoApi>((ref) {
  return ProductoApi(ref.watch(apiClientProvider));
});

final productoRepositoryProvider = Provider<ProductoRepository>((ref) {
  return ProductoRepository(api: ref.watch(productoApiProvider));
});

/// Estado de la lista de productos.
class ProductosState {
  const ProductosState({
    this.productos = const <Producto>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<Producto> productos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  ProductosState copyWith({
    List<Producto>? productos,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return ProductosState(
      productos: productos ?? this.productos,
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
/// Van aparte del estado y no dentro de él, por el mismo motivo que en usuarios
/// y unidades: dentro, el `build` del controller tendría que leerlos para
/// cargarse, y eso es depender de su propio estado mientras se construye.
class FiltrosProductos {
  const FiltrosProductos({
    this.unidadMedida,
    this.soloInactivos = false,
    this.busqueda = '',
  });

  /// Unidad de medida elegida, o `null` para todas.
  final String? unidadMedida;

  /// Muestra los **inactivos**, que son los pocos. El nombre va al revés de la
  /// pantalla a propósito: si se llamara `soloActivos`, "sin marcar" tendría que
  /// significar "todas" y haría falta un estado más.
  final bool soloInactivos;
  final String busqueda;

  bool get hayAlguno =>
      unidadMedida != null || soloInactivos || busqueda.isNotEmpty;

  FiltrosProductos copyWith({
    String? unidadMedida,
    bool limpiarUnidad = false,
    bool? soloInactivos,
    String? busqueda,
  }) {
    return FiltrosProductos(
      // Sin `limpiarUnidad` no se podría volver a "Todas": `null` es justo el
      // valor que significa eso.
      unidadMedida: limpiarUnidad ? null : (unidadMedida ?? this.unidadMedida),
      soloInactivos: soloInactivos ?? this.soloInactivos,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de productos y ejecuta las acciones sobre cada uno.
class ProductosController extends Notifier<ProductosState> {
  /// Peticiones por página. Diez es el tamaño con el que la API responde por
  /// defecto y cabe en pantalla sin paginar.
  static const int limite = 10;

  @override
  ProductosState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const ProductosState();
  }

  ProductoRepository get _repo => ref.read(productoRepositoryProvider);

  FiltrosProductos get _filtros => ref.read(filtrosProductosProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        busqueda: filtros.busqueda,
        estado: filtros.soloInactivos ? false : null,
        unidadMedida: filtros.unidadMedida,
      );

      state = state.copyWith(
        productos: resultado.productos,
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

  Future<void> filtrarPorUnidad(String? unidadMedida) async {
    ref.read(filtrosProductosProvider.notifier).filtrarPorUnidad(unidadMedida);
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloInactivos() async {
    ref.read(filtrosProductosProvider.notifier).alternarSoloInactivos();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosProductosProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosProductosProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea un producto y recarga la lista.
  Future<bool> crear({
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    try {
      await _repo.crear(
        nombre: nombre,
        descripcion: descripcion,
        unidadMedida: unidadMedida,
        precioVenta: precioVenta,
        estado: estado,
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

  /// Guarda los cambios de un producto.
  Future<bool> editar(
    Producto producto, {
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    try {
      final actualizado = await _repo.editar(
        producto.id,
        nombre: nombre,
        descripcion: descripcion,
        unidadMedida: unidadMedida,
        precioVenta: precioVenta,
        estado: estado,
      );

      _reemplazar(actualizado);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Producto producto) async {
    try {
      await _repo.eliminar(producto.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró, y
      // recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        productos: state.productos.where((p) => p.id != producto.id).toList(),
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
  void _reemplazar(Producto actualizado) {
    final lista = state.productos
        .map((p) => p.id == actualizado.id ? actualizado : p)
        .toList();

    state = state.copyWith(productos: lista, limpiarError: true);
  }
}

final productosControllerProvider = NotifierProvider<ProductosController, ProductosState>(
  ProductosController.new,
);

/// Filtros de la lista de productos.
///
/// Un provider aparte del que carga: así el `build` de `ProductosController`
/// puede leerlos sin depender de su propio estado.
class FiltrosProductosController extends Notifier<FiltrosProductos> {
  @override
  FiltrosProductos build() => const FiltrosProductos();

  void filtrarPorUnidad(String? unidadMedida) {
    state = state.copyWith(unidadMedida: unidadMedida, limpiarUnidad: unidadMedida == null);
  }

  void alternarSoloInactivos() {
    state = state.copyWith(soloInactivos: !state.soloInactivos);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }

  void limpiar() {
    state = const FiltrosProductos();
  }
}

final filtrosProductosProvider = NotifierProvider<FiltrosProductosController, FiltrosProductos>(
  FiltrosProductosController.new,
);