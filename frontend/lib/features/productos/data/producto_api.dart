import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/producto.dart';

/// Peticiones de `/productos`: listar, ver, crear, editar y borrar.
///
/// La imagen va aparte, por `PUT /productos/{id}/imagen` y por el módulo de
/// imágenes. No se manda en el alta ni en la edición porque la sube el
/// `SelectorImagen`, que primero la guarda en el servidor y luego pasa la ruta.
class ProductoApi {
  ProductoApi(this._dio);

  final Dio _dio;

  /// `GET /productos`
  ///
  /// Acepta `busqueda` (nombre o descripción), `estado` y `unidadMedida`.
  /// Los tres están declarados en `_filtros()` del servicio: si se mandara otro,
  /// el servidor lo rechaza con un 400 en vez de devolver la lista sin filtrar.
  Future<ProductosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? estado,
    String? unidadMedida,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/productos',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'estado': ?estado,
          'unidadMedida': ?unidadMedida,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return ProductosPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /productos/{id}`
  Future<Producto> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/productos/$id'),
    );

    final datos = _datos(cuerpo);
    final producto = datos['item'] as Map<String, dynamic>? ?? datos;

    if (producto.isEmpty) {
      throw const ServerException('La API no devolvió el producto.');
    }

    return Producto.fromJson(producto);
  }

  /// `POST /productos`
  ///
  /// `descripcion` y `unidadMedida` viajan siempre, aunque valgan cadena vacía:
  /// vaciar un campo es una edición legítima y omitirlo lo dejaría sin tocar.
  Future<Producto> crear({
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/productos',
        data: {
          'nombre': nombre,
          'descripcion': descripcion ?? '',
          'unidadMedida': unidadMedida ?? '',
          'precioVenta': precioVenta,
          'estado': estado,
        },
      ),
    );

    return Producto.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /productos/{id}`
  Future<Producto> editar(
    int id, {
    required String nombre,
    String? descripcion,
    String? unidadMedida,
    required double precioVenta,
    required bool estado,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/productos/$id',
        data: {
          'nombre': nombre,
          'descripcion': descripcion ?? '',
          'unidadMedida': unidadMedida ?? '',
          'precioVenta': precioVenta,
          'estado': estado,
        },
      ),
    );

    return Producto.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /productos/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/productos/$id'));
  }

  Future<Map<String, dynamic>> _enviar(
    Future<Response<Map<String, dynamic>>> Function() llamada,
  ) async {
    try {
      final respuesta = await llamada();
      return respuesta.data ?? const <String, dynamic>{};
    } catch (error) {
      throw mapearError(error);
    }
  }

  Map<String, dynamic> _datos(Map<String, dynamic> cuerpo) {
    return (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }
}