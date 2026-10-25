import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/proveedor.dart';

/// Peticiones de `/proveedores`: listar, ver, crear, editar y borrar.
class ProveedorApi {
  ProveedorApi(this._dio);

  final Dio _dio;

  /// `GET /proveedores`
  ///
  /// Acepta `busqueda` (nombre, apellido, DNI o código), `activo` y `zonaId`.
  /// Los tres están declarados en `_filtros()` del servicio: lo que no
  /// reconoce el servidor lo rechaza con un 400 en vez de devolver la lista
  /// entera sin filtrar.
  Future<ProveedoresPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? zonaId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/proveedores',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'activo': ?activo,
          'zonaId': ?zonaId,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return ProveedoresPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /proveedores/{id}`
  Future<Proveedor> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/proveedores/$id'),
    );

    final datos = _datos(cuerpo);
    final proveedor = datos['item'] as Map<String, dynamic>? ?? datos;

    if (proveedor.isEmpty) {
      throw const ServerException('La API no devolvió el proveedor.');
    }

    return Proveedor.fromJson(proveedor);
  }

  /// `POST /proveedores`
  ///
  /// **`codigo` no se manda: lo pone el servidor.** `proveedor.codigo` es único
  /// y la app solo ve una página de la lista, así que no puede saber qué códigos
  /// existen. Si lo generara el cliente, dos altas simultáneas pedirían el mismo
  /// número y una fallaría. El servidor devuelve `PROV-006`, `PROV-007`… según
  /// el último que haya, y la lista lo enseña.
  ///
  /// **`rutaId` tampoco aparece en el mapa, y no es un olvido.** En qué ruta está
  /// un proveedor se dice en las paradas de esa ruta, no en su ficha, y el
  /// backend rechaza la clave con un 400 aunque valga `null`:
  ///
  /// ```
  /// { ..., rutaId: 1 }    → 400
  /// { ..., rutaId: null } → 400  ← también
  /// { ... }                → 201
  /// ```
  ///
  /// Mandarla en `null` "por no poner nada" rompería el alta entera, y el error
  /// sería un 400 que habla de rutas cuando lo que falla es el alta de una
  /// persona. Por eso la clave se construye sin ella.
  Future<Proveedor> crear({
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/proveedores',
        data: {
          'nombre': nombre,
          'apellido': apellido,
          'dni': dni,
          'telefono': telefono ?? '',
          'direccion': direccion ?? '',
          'zonaId': zonaId,
          'activo': activo,
        },
      ),
    );

    return Proveedor.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /proveedores/{id}`
  ///
  /// Misma regla que en el alta: `rutaId` no se manda.
  Future<Proveedor> editar(
    int id, {
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/proveedores/$id',
        data: {
          'nombre': nombre,
          'apellido': apellido,
          'dni': dni,
          'telefono': telefono ?? '',
          'direccion': direccion ?? '',
          'zonaId': zonaId,
          'activo': activo,
        },
      ),
    );

    return Proveedor.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /proveedores/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/proveedores/$id'));
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
