import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/recorrido.dart';

/// Peticiones de `/recorridos`.
///
/// No es un CRUD: aparte de listar y dar de alta, hay **el ciclo de vida** —
///iniciar, finalizar y cancelar— y **las paradas**, que solo existen a partir de
/// que el recorrido arranca.
class RecorridoApi {
  RecorridoApi(this._dio);

  final Dio _dio;

  /// `GET /recorridos`
  ///
  /// Acepta `estado`, `fecha` y `unidadId`, declarados en `nombresDeFiltro()` del
  /// servicio: `list` está sobrescrito y construye su propio `where`.
  Future<RecorridosPagina> listar({
    int pagina = 1,
    int limite = 10,
    EstadoRecorrido? estado,
    String? fecha,
    int? unidadId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/recorridos',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          // `estado` viaja como su texto del servidor (`EN_RUTA`), no como el
          // nombre del enumerado de Dart (`enRuta`): el enumerado es de la app y
          // el servidor no lo conoce.
          'estado': ?estado?.valor,
          'fecha': ?(fecha != null && fecha.isNotEmpty ? fecha : null),
          'unidadId': ?unidadId,
        },
      ),
    );

    return RecorridosPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /recorridos/actual`
  ///
  /// El recorrido en curso del acopiador. **Devuelve `null`, no un 404**, cuando
  /// no hay ninguno: que no haya recorrido en marcha es lo normal la mayor parte
  /// del día, no un error.
  ///
  /// La ruta va declarada antes que `/:id` en el servidor justamente para que
  /// `actual` no se lea como un id.
  Future<Recorrido?> actual() async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/recorridos/actual'),
    );

    final datos = _datos(cuerpo);
    final item = datos['item'];

    if (item is! Map<String, dynamic>) {
      return null;
    }

    return Recorrido.fromJson(item);
  }

  /// `GET /recorridos/{id}`
  Future<Recorrido> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/recorridos/$id'),
    );

    final datos = _datos(cuerpo);
    final recorrido = datos['item'] as Map<String, dynamic>? ?? datos;

    if (recorrido.isEmpty) {
      throw const ServerException('La API no devolvió el recorrido.');
    }

    return Recorrido.fromJson(recorrido);
  }

  /// `POST /recorridos`
  ///
  /// **Regla incómoda: el ayudante va entero o no va.** El servidor rechaza el
  /// alta si mandas `ayudanteNombre` sin `ayudanteApellido` y `ayudanteDni`:
  ///
  /// ```
  /// { ..., ayudanteNombre: "Luis" }                    → 400
  /// { ..., ayudanteNombre, ayudanteApellido }          → 400
  /// { ..., ayudanteNombre, ayudanteApellido, ayudanteDni } → 201
  /// { ..., ayudanteCelular: "999..." }                 → 201  (el celular va solo)
  /// ```
  ///
  /// Un ayudante sin DNI no se sabe identificar, y un DNI sin nombre no se sabe
  /// a quién pedir. El móvil es un `ayudante` interno —una cuenta de la
  /// planta— y entonces los campos sueltos sobran y el servidor los descarta.
  ///
  /// `acopiadorId` no se manda: el servidor lo saca de la sesión. Mandarlo con
  /// otro valor es ignorar de quién es el recorrido.
  Future<Recorrido> crear({
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/recorridos',
        data: _campos({
          'rutaId': rutaId,
          'unidadId': unidadId,
          'fecha': fecha,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'ayudanteUsuarioId': ayudanteUsuarioId,
          'ayudanteNombre': ayudanteNombre,
          'ayudanteApellido': ayudanteApellido,
          'ayudanteDni': ayudanteDni,
          'ayudanteCelular': ayudanteCelular,
          'observaciones': observaciones,
        }),
      ),
    );

    return Recorrido.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /recorridos/{id}`
  Future<Recorrido> editar(
    int id, {
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/recorridos/$id',
        data: _campos({
          'rutaId': rutaId,
          'unidadId': unidadId,
          'fecha': fecha,
          'horaInicio': horaInicio,
          'horaFin': horaFin,
          'ayudanteUsuarioId': ayudanteUsuarioId,
          'ayudanteNombre': ayudanteNombre,
          'ayudanteApellido': ayudanteApellido,
          'ayudanteDni': ayudanteDni,
          'ayudanteCelular': ayudanteCelular,
          'observaciones': observaciones,
        }),
      ),
    );

    return Recorrido.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /recorridos/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/recorridos/$id'));
  }

  /// `POST /recorridos/{id}/iniciar`
  ///
  /// Solo desde `PLANIFICADO`, y solo el acopiador del recorrido (o un
  /// administrador o supervisor). **Aquí se sellan las paradas de la ruta**, y por
  /// eso un recorrido planificado sale con cero paradas.
  Future<Recorrido> iniciar(int id) async {
    return _transicion(id, 'iniciar');
  }

  /// `POST /recorridos/{id}/finalizar`
  ///
  /// Solo desde `EN_RUTA`. Las paradas que sigan `PENDIENTE` pasan a `OMITIDA`.
  Future<Recorrido> finalizar(int id) async {
    return _transicion(id, 'finalizar');
  }

  /// `POST /recorridos/{id}/cancelar`
  ///
  /// Vale desde cualquier estado menos `FINALIZADO`. **No exige ser el
  /// acopiador**, a diferencia de iniciar y finalizar: cancelar es una decisión
  /// de quien coordina, no de quien va en el camión.
  Future<Recorrido> cancelar(int id, {String? observaciones}) async {
    return _transicion(id, 'cancelar', cuerpo: {'observaciones': observaciones ?? ''});
  }

  /// `POST /recorridos/{id}/paradas/{paradaId}/atender`
  ///
  /// Solo con el recorrido `EN_RUTA`.
  Future<Recorrido> atenderParada(int id, int paradaId) async {
    return _transicion(id, 'paradas/$paradaId/atender');
  }

  /// `POST /recorridos/{id}/paradas/{paradaId}/recolectar`
  Future<Recorrido> recolectarEnParada(
    int id,
    int paradaId, {
    double? cantidad,
    String? observaciones,
  }) async {
    return _transicion(
      id,
      'paradas/$paradaId/recolectar',
      cuerpo: _campos({'cantidad': cantidad, 'observaciones': observaciones}),
    );
  }

  /// Las tres transiciones y las dos de parada tienen la misma forma: un `POST`
  /// sin cuerpo útil y una respuesta con el recorrido entero. Se hacen juntas
  /// para que el cambio de una afecte a las cinco.
  Future<Recorrido> _transicion(
    int id,
    String accion, {
    Map<String, dynamic>? cuerpo,
  }) async {
    final respuesta = await _enviar(
      () => _dio.post<Map<String, dynamic>>('/recorridos/$id/$accion', data: cuerpo ?? const <String, dynamic>{}),
    );

    final datos = _datos(respuesta);
    final item = datos['item'] as Map<String, dynamic>? ?? datos;

    return Recorrido.fromJson(item);
  }

  /// Quita las claves que van vacías o a `null`.
  ///
  /// Sin esto saldrían `"ayudanteNombre": null` y `"ayudanteCelular": null` en
  /// cada alta, que el servidor lee como "quiero vaciarlo" en vez de como "no te
  /// he dicho nada". Y en el ayudante eso además rompe el alta: la regla de
  /// "los tres o ninguno" mira las claves presentes, no su valor.
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
