import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/recoleccion.dart';

/// Peticiones de `/recolecciones`.
class RecoleccionApi {
  RecoleccionApi(this._dio);

  final Dio _dio;

  /// `GET /recolecciones`
  ///
  /// Acepta `fecha`, `proveedorId`, `zonaId`, `unidadId`, `recorridoParadaId`,
  /// `registradoEn`, `sincronizado`, `desde` y `hasta`. Los nueve están
  /// declarados en `_filtros()` del servicio: lo que no reconoce el servidor lo
  /// rechaza con un 400 en vez de devolver la lista entera sin filtrar.
  Future<RecoleccionesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? fecha,
    int? proveedorId,
    int? zonaId,
    int? unidadId,
    String? registradoEn,
    bool? sincronizado,
    String? desde,
    String? hasta,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/recolecciones',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'fecha': ?(fecha != null && fecha.isNotEmpty ? fecha : null),
          'proveedorId': ?proveedorId,
          'zonaId': ?zonaId,
          'unidadId': ?unidadId,
          'registradoEn': ?(registradoEn != null && registradoEn.isNotEmpty ? registradoEn : null),
          'sincronizado': ?sincronizado,
          'desde': ?(desde != null && desde.isNotEmpty ? desde : null),
          'hasta': ?(hasta != null && hasta.isNotEmpty ? hasta : null),
        },
      ),
    );

    return RecoleccionesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /recolecciones/{id}`
  Future<Recoleccion> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/recolecciones/$id'),
    );

    final datos = _datos(cuerpo);
    final recoleccion = datos['item'] as Map<String, dynamic>? ?? datos;

    if (recoleccion.isEmpty) {
      throw const ServerException('La API no devolvió la recolección.');
    }

    return Recoleccion.fromJson(recoleccion);
  }

  /// `POST /recolecciones`
  ///
  /// **Siete campos son obligatorios**: `proveedorId`, `zonaId`, `unidadId`,
  /// `usuarioId`, `cantidad`, `fecha` y `registradoEn`. Medido, no deducido: sin
  /// `registradoEn` el alta falla con
  /// `recoleccion.registradoEn cannot be null`, y no tiene valor por defecto en
  /// la base, así que **hay que decir explícitamente dónde se anotó la recogida**.
  ///
  /// `hora`, `temperatura` y `recorridoParadaId` son opcionales.
  ///
  /// `usuarioId` lo manda quien rellena, y sale de la sesión: el servidor no lo
  /// deduce, porque una recogida se puede registrar en nombre de otro.
  Future<Recoleccion> crear({
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/recolecciones',
        data: _campos({
          'proveedorId': proveedorId,
          'zonaId': zonaId,
          'unidadId': unidadId,
          'usuarioId': usuarioId,
          'cantidad': cantidad,
          'fecha': fecha,
          'registradoEn': registradoEn,
          'hora': hora,
          'temperatura': temperatura,
          'recorridoParadaId': recorridoParadaId,
        }),
      ),
    );

    return Recoleccion.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /recolecciones/{id}`
  Future<Recoleccion> editar(
    int id, {
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/recolecciones/$id',
        data: _campos({
          'proveedorId': proveedorId,
          'zonaId': zonaId,
          'unidadId': unidadId,
          'usuarioId': usuarioId,
          'cantidad': cantidad,
          'fecha': fecha,
          'registradoEn': registradoEn,
          'hora': hora,
          'temperatura': temperatura,
          'recorridoParadaId': recorridoParadaId,
        }),
      ),
    );

    return Recoleccion.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /recolecciones/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/recolecciones/$id'));
  }

  /// Quita las claves que van vacías o a `null`.
  ///
  /// Sin esto saldrían `"hora": null` y `"temperatura": null` en cada alta. Para
  /// esas dos da igual porque son opcionales, pero el mismo helper se usa en
  /// otros módulos donde la diferencia sí importa: omitir un campo deja el
  /// valor anterior, y mandarlo a `null` lo quita.
  Map<String, dynamic> _campos(Map<String, dynamic> campos) {
    final limpio = <String, dynamic>{};

    for (final entrada in campos.entries) {
      final valor = entrada.value;
      if (valor == null || (valor is String && valor.isEmpty)) {
        continue;
      }
      limpio[entrada.key] = valor;
    }

    return limpio;
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
