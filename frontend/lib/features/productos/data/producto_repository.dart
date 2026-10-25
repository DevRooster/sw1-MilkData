import '../domain/producto.dart';
import 'producto_api.dart';

/// Repositorio de `/productos`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación. Este solo habla del recurso.
class ProductoRepository {
  ProductoRepository({required this.api});

  // ignore: prefer_initializing_formals
  final ProductoApi api;

  Future<ProductosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? estado,
    String? unidadMedida,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      busqueda: busqueda,
      estado: estado,
      unidadMedida: unidadMedida,
    );
  }

  Future<Producto> ver(int id) => api.ver(id);

  Future<Producto> crear({
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) {
    return api.crear(
      nombre: nombre,
      descripcion: descripcion,
      unidadMedida: unidadMedida,
      precioVenta: precioVenta,
      estado: estado,
    );
  }

  Future<Producto> editar(
    int id, {
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) {
    return api.editar(
      id,
      nombre: nombre,
      descripcion: descripcion,
      unidadMedida: unidadMedida,
      precioVenta: precioVenta,
      estado: estado,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}