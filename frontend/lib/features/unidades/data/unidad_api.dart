import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/unidad.dart';

/// Peticiones de `/unidades`: listar, ver, crear, editar y borrar.
///
/// El listado acepta cuatro filtros —`tipo`, `activo`, `cerrado` y `busqueda`— y
/// ninguno más: el servidor rechaza con un 400 lo que no reconoce, en vez de
/// devolver la lista entera sin filtrar. Si algún día aparece un filtro nuevo,
/// sale aquí y en `_filtros()` del servicio, no solo en Dart.
class UnidadApi {
  UnidadApi(this._dio);

  final Dio _dio;

  /// `GET /unidades`
  ///
  /// Los filtros se combinan: `?tipo=furgon&activo=true` devuelve los furgones
  /// activos, no los furgones y por aparte los activos.
  Future<UnidadesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    bool? activo,
    bool? cerrado,
    String? busqueda,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/unidades',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'tipo': ?tipo,
          'activo': ?activo,
          'cerrado': ?cerrado,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return UnidadesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /unidades/{id}`
  Future<Unidad> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/unidades/$id'),
    );

    final datos = _datos(cuerpo);
    final unidad = datos['item'] as Map<String, dynamic>? ?? datos;

    if (unidad.isEmpty) {
      throw const ServerException('La API no devolvió la unidad.');
    }

    return Unidad.fromJson(unidad);
  }

  /// `POST /unidades`
  ///
  /// `acopiadorId` viaja siempre, incluso valiendo `null`: es el caso legítimo
  /// de una unidad recién creada y sin chófer, y omitirlo dejaría al servidor
  /// decidir por su cuenta.
  Future<Unidad> crear({
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/unidades',
        data: {
          'nombre': nombre,
          'tipo': tipo,
          'capacidad': capacidad,
          'cerrado': cerrado,
          'activo': activo,
          'acopiadorId': acopiadorId,
        },
      ),
    );

    return Unidad.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /unidades/{id}`
  ///
  /// El mismo criterio que en el alta: `acopiadorId` se manda siempre, para
  /// poder quitar un conductor y no solo ponerlo.
  Future<Unidad> editar(
    int id, {
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/unidades/$id',
        data: {
          'nombre': nombre,
          'tipo': tipo,
          'capacidad': capacidad,
          'cerrado': cerrado,
          'activo': activo,
          'acopiadorId': acopiadorId,
        },
      ),
    );

    return Unidad.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /unidades/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/unidades/$id'));
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