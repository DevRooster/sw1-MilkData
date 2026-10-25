import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/zona.dart';

/// Peticiones de `/zonas`: listar, ver, crear, editar y borrar.
class ZonaApi {
  ZonaApi(this._dio);

  final Dio _dio;

  /// `GET /zonas`
  ///
  /// Acepta `busqueda` (nombre), `activo`, `rutaId` y `unidadId`. Los cuatro
  /// están declarados en `_filtros()` del servicio: lo que no reconoce el
  /// servidor lo rechaza con un 400 en vez de devolver la lista entera sin
  /// filtrar.
  Future<ZonasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? rutaId,
    int? unidadId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/zonas',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'activo': ?activo,
          'rutaId': ?rutaId,
          'unidadId': ?unidadId,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return ZonasPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /zonas/{id}`
  Future<Zona> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/zonas/$id'),
    );

    final datos = _datos(cuerpo);
    final zona = datos['item'] as Map<String, dynamic>? ?? datos;

    if (zona.isEmpty) {
      throw const ServerException('La API no devolvió la zona.');
    }

    return Zona.fromJson(zona);
  }

  /// `POST /zonas`
  ///
  /// `descripcion` no existe en el recurso: los campos son nombre, horario,
  /// ruta, unidad y activo, y no se manda de más.
  ///
  /// `rutaId` y `unidadId` viajan **siempre**, aunque valgan `null`. Eso no es lo
  /// mismo que omitirlos: omitir el campo deja el valor anterior, y `null` lo
  /// quita. Sin esto no se podría desasignar una zona que ya tenía ruta.
  Future<Zona> crear({
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/zonas',
        data: {
          'nombre': nombre,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'rutaId': rutaId,
          'unidadId': unidadId,
          'activo': activo,
        },
      ),
    );

    return Zona.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /zonas/{id}`
  Future<Zona> editar(
    int id, {
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/zonas/$id',
        data: {
          'nombre': nombre,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'rutaId': rutaId,
          'unidadId': unidadId,
          'activo': activo,
        },
      ),
    );

    return Zona.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /zonas/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/zonas/$id'));
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
