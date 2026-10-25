import 'package:dio/dio.dart';
import 'package:milkdata_app/features/productos/data/producto_api.dart';
import 'package:milkdata_app/features/productos/domain/producto.dart';

/// `ProductoApi` de mentira: filtra, pagina y guarda en memoria, sin tocar la
/// red.
///
/// Reproduce el comportamiento del servidor —que los filtros se combinan y que la
/// paginación va sobre el conjunto ya filtrado— porque un fake más permisivo
/// daría verde a una lista que en el móvil real saldría mal.
class FakeProductoApi extends ProductoApi {
  FakeProductoApi({List<Producto>? productos})
      : _productos = productos ?? <Producto>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Producto> _productos;

  /// Lo que se pidió en la última llamada a `listar`, para comprobar que los
  /// filtros viajan y no se filtran en la pantalla.
  ({int pagina, int limite, String? busqueda, bool? estado, String? unidadMedida})?
      ultimaConsulta;

  final List<int> eliminados = [];
  final List<int> creados = [];
  final List<int> editados = [];

  @override
  Future<ProductosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? estado,
    String? unidadMedida,
  }) async {
    // La API real solo manda `busqueda` en la query si no viene vacía, y aquí se
    // registra igual. Si el doble guardara la cadena vacía, diría que viaja un
    // filtro que en realidad no viaja, y una prueba que lo comprobara estaría
    // comprobando una mentira.
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      busqueda: busqueda != null && busqueda.isNotEmpty ? busqueda : null,
      estado: estado,
      unidadMedida: unidadMedida,
    );

    var filtrados = _productos;

    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtrados = filtrados
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(texto) ||
                (p.descripcion?.toLowerCase().contains(texto) ?? false),
          )
          .toList();
    }
    if (estado != null) {
      filtrados = filtrados.where((p) => p.estado == estado).toList();
    }
    if (unidadMedida != null) {
      filtrados = filtrados.where((p) => p.unidadMedida == unidadMedida).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return ProductosPagina(
      productos: filtrados.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Producto> ver(int id) async {
    return _productos.firstWhere(
      (p) => p.id == id,
      orElse: () => Producto(id: id, nombre: 'Desconocido', estado: true),
    );
  }

  @override
  Future<Producto> crear({
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    final nuevo = Producto(
      id: _siguienteId(),
      nombre: nombre,
      descripcion: descripcion,
      unidadMedida: unidadMedida,
      precioVenta: precioVenta,
      estado: estado,
      plantaId: 1,
    );

    _productos.insert(0, nuevo);
    creados.add(nuevo.id);

    return nuevo;
  }

  @override
  Future<Producto> editar(
    int id, {
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    editados.add(id);

    final indice = _productos.indexWhere((p) => p.id == id);
    final anterior = indice >= 0 ? _productos[indice] : null;

    final actualizado = Producto(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      unidadMedida: unidadMedida,
      precioVenta: precioVenta,
      estado: estado,
      imagen: anterior?.imagen,
      plantaId: anterior?.plantaId ?? 1,
    );

    if (indice >= 0) {
      _productos[indice] = actualizado;
    }

    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _productos.removeWhere((p) => p.id == id);
  }

  int _siguienteId() {
    if (_productos.isEmpty) {
      return 1;
    }
    return _productos.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Producto de ejemplo para las pruebas.
Producto productoDePrueba({
  int id = 1,
  String nombre = 'Yogurt natural 1 L',
  String? descripcion = 'Yogurt entero de leche fresca',
  String? unidadMedida = 'unidad',
  double precioVenta = 3.75,
  bool estado = true,
  String? imagen,
}) {
  return Producto(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    unidadMedida: unidadMedida,
    precioVenta: precioVenta,
    estado: estado,
    imagen: imagen,
    plantaId: 1,
  );
}