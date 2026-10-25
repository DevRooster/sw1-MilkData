import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/control_calidad.dart';

/// Peticiones de `/calidad`.
class CalidadApi {
  CalidadApi(this._dio);

  final Dio _dio;

  /// `GET /calidad`
  ///
  /// Acepta `recoleccionId`, `usuarioId`, `resultado`, `desde` y `hasta`. Los
  /// cinco están declarados en `_filtros()` del servicio; lo que no reconoce el
  /// servidor lo rechaza con un 400 en vez de devolver la lista sin filtrar.
  ///
  /// `resultado` va como `pura` o `adulterada`, el texto del `ENUM` de la base.
  /// No como `Pura` ni como `adultero`: el `ENUM` de MySQL no distingue
  /// mayúsculas al escribir, pero el resto de la API sí es estricta y medio
  /// módulo depende de que esto sea exacto.
  Future<ControlesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? resultado,
    int? recoleccionId,
    int? usuarioId,
    String? desde,
    String? hasta,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/calidad',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'resultado': ?(resultado != null && resultado.isNotEmpty ? resultado : null),
          'recoleccionId': ?recoleccionId,
          'usuarioId': ?usuarioId,
          'desde': ?(desde != null && desde.isNotEmpty ? desde : null),
          'hasta': ?(hasta != null && hasta.isNotEmpty ? hasta : null),
        },
      ),
    );

    return ControlesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /calidad/recoleccion/{id}`
  ///
  /// Devuelve el control de una recolección, o `null` si todavía no tiene
  /// ninguno. Es la consulta que dice si una recogida ya se ha analizado, y
  /// devuelve 404 en vez de lista vacía cuando no existe.
  Future<ControlCalidad?> porRecoleccion(int recoleccionId) async {
    try {
      final cuerpo = await _enviar(
        () => _dio.get<Map<String, dynamic>>('/calidad/recoleccion/$recoleccionId'),
      );

      final datos = _datos(cuerpo);
      final item = datos['item'] as Map<String, dynamic>?;

      return item == null ? null : ControlCalidad.fromJson(item);
    } on NotFoundException {
      // Todavía sin analizar no es un error: es el estado normal de una
      // recolección recién recogida, y la app lo trata como "falta", no como
      // "falló".
      return null;
    }
  }

  /// `GET /calidad/{id}`
  Future<ControlCalidad> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/calidad/$id'),
    );

    final datos = _datos(cuerpo);
    final item = datos['item'] as Map<String, dynamic>? ?? datos;

    if (item.isEmpty) {
      throw const ServerException('La API no devolvió el control de calidad.');
    }

    return ControlCalidad.fromJson(item);
  }

  /// `POST /calidad`
  ///
  /// Solo dos campos son obligatorios: `recoleccionId` —que además tiene que
  /// existir en esta planta, y si no el error lo dice con nombre: *"la recolección
  /// indicada (7) no existe en esta planta"*— y `usuarioId`.
  ///
  /// `resultado` **no hace falta mandarlo**: tiene valor por defecto `pura` en la
  /// base. A diferencia de `registradoEn` en Recolecciones, que sí obliga a
  /// elegir. La app lo manda igualmente para que lo que se ve sea lo que se
  /// guarda.
  ///
  /// Las siete medidas son opcionales y se pueden dejar a `null`.
  Future<ControlCalidad> crear({
    required int recoleccionId,
    required int usuarioId,
    String resultado = ControlCalidad.pura,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/calidad',
        data: _campos({
          'recoleccionId': recoleccionId,
          'usuarioId': usuarioId,
          'resultado': resultado,
          'grasa': grasa,
          'proteina': proteina,
          'lactosa': lactosa,
          'densidad': densidad,
          'temperatura': temperatura,
          'aguaAnadida': aguaAnadida,
          'ph': ph,
        }),
      ),
    );

    return ControlCalidad.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /calidad/{id}`
  ///
  /// **Cambiar `recoleccionId` a una recolección que ya tiene control da 400**
  /// —"Ya existe un registro con ese valor único"—, igual que crear un segundo.
  /// El único `recoleccionId` es una restricción de la base, no del servicio, y
  /// se cumple también al editar. Medido.
  Future<ControlCalidad> editar(
    int id, {
    int? recoleccionId,
    int? usuarioId,
    String? resultado,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/calidad/$id',
        data: _campos({
          'recoleccionId': recoleccionId,
          'usuarioId': usuarioId,
          'resultado': resultado,
          'grasa': grasa,
          'proteina': proteina,
          'lactosa': lactosa,
          'densidad': densidad,
          'temperatura': temperatura,
          'aguaAnadida': aguaAnadida,
          'ph': ph,
        }),
      ),
    );

    return ControlCalidad.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /calidad/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/calidad/$id'));
  }

  /// Quita las claves vacías.
  ///
  /// En este módulo importa de verdad: mandar `"grasa": null` en un alta es
  /// indistinguible de no mandarlo, pero en una **edición** es lo contrario de
  /// omitirla —omitir deja el valor anterior y mandarla a `null` la quita—. Por
  /// eso el controlador de la app manda las siete explícitamente, y este helper
  /// solo sirve para no ensuciar el alta con `null` donde el servidor los tiene
  /// opcionales.
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