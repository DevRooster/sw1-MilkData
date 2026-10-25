import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/ruta.dart';

/// Peticiones de `/rutas`: listar, ver, crear, editar y borrar.
///
/// **Las paradas no están aquí a propósito.** Son un proveedor en un orden, así
/// que dependen del módulo de Proveedores: `agregarParada`, `quitarParada` y
/// `reordenarParadas` no tienen sentido hasta que haya proveedores que poner en
/// una ruta. Cuando llegue ese módulo se añaden a esta misma clase.
class RutaApi {
  RutaApi(this._dio);

  final Dio _dio;

  /// `GET /rutas`
  ///
  /// Acepta `busqueda` (nombre o código) y `activa`. Ambos declarados en
  /// `_filtros()` del servicio: lo que no reconoce el servidor lo rechaza con un
  /// 400 en vez de devolver la lista entera sin filtrar.
  Future<RutasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activa,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/rutas',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'activa': ?activa,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return RutasPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /rutas/{id}`
  ///
  /// Aquí sí vienen las paradas, con su proveedor. En el listado solo viene el
  /// número, y por eso `Ruta` y `RutaDetalle` son tipos distintos.
  Future<RutaDetalle> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/rutas/$id'),
    );

    final datos = _datos(cuerpo);
    final ruta = datos['item'] as Map<String, dynamic>? ?? datos;

    if (ruta.isEmpty) {
      throw const ServerException('La API no devolvió la ruta.');
    }

    return RutaDetalle.fromJson(ruta);
  }

  /// `POST /rutas`
  ///
  /// `descripcion` viaja siempre, aunque valga cadena vacía: vaciar un campo es
  /// una edición legítima y omitirlo lo dejaría sin tocar.
  Future<Ruta> crear({
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/rutas',
        data: {
          'nombre': nombre,
          'codigo': codigo,
          'descripcion': descripcion ?? '',
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'activa': activa,
        },
      ),
    );

    return Ruta.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /rutas/{id}`
  Future<Ruta> editar(
    int id, {
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/rutas/$id',
        data: {
          'nombre': nombre,
          'codigo': codigo,
          'descripcion': descripcion ?? '',
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'activa': activa,
        },
      ),
    );

    return Ruta.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /rutas/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/rutas/$id'));
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