import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/asistencia.dart';

/// Peticiones de `/asistencias`.
class AsistenciaApi {
  AsistenciaApi(this._dio);

  final Dio _dio;

  /// `GET /asistencias`
  ///
  /// Acepta `evento`, `registradoPor`, `proveedorId`, `usuarioId`, `fecha`,
  /// `desde` y `hasta`. Los siete están declarados en `_filtros()` del
  /// servicio; lo que no reconoce el servidor lo rechaza con un 400 en vez de
  /// devolver la lista sin filtrar.
  ///
  /// `evento` busca **por fragmento** y no exacto: es texto libre, así que quien
  /// recuerda "reunion" tiene que encontrar "Reunión de ruta del Norte".
  ///
  /// `registradoPor` va como `QR` o `manual`, **en mayúsculas exactas**: el
  /// backend ahora distingue mayúsculas en los `ENUM` y `qr` sería un 400.
  Future<AsistenciasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? evento,
    String? registradoPor,
    int? proveedorId,
    int? usuarioId,
    String? fecha,
    String? desde,
    String? hasta,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/asistencias',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'evento': ?(evento != null && evento.isNotEmpty ? evento : null),
          'registradoPor': ?(registradoPor != null && registradoPor.isNotEmpty ? registradoPor : null),
          'proveedorId': ?proveedorId,
          'usuarioId': ?usuarioId,
          'fecha': ?(fecha != null && fecha.isNotEmpty ? fecha : null),
          'desde': ?(desde != null && desde.isNotEmpty ? desde : null),
          'hasta': ?(hasta != null && hasta.isNotEmpty ? hasta : null),
        },
      ),
    );

    return AsistenciasPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /asistencias/proveedor/{id}`
  Future<AsistenciasPagina> porProveedor(int proveedorId, {int pagina = 1, int limite = 10}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/asistencias/proveedor/$proveedorId',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    return AsistenciasPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /asistencias/evento/{evento}`
  ///
  /// Coincidencia **exacta**, a diferencia del filtro `evento` de la lista, que
  /// va por fragmento. Dos rutas distintas del servidor con comportamientos
  /// distintos: esta compara igualdad y aquella busca dentro. La app usa el
  /// filtro de la lista, no esta.
  Future<AsistenciasPagina> porEvento(String evento, {int pagina = 1, int limite = 10}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/asistencias/evento/$evento',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    return AsistenciasPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /asistencias/{id}`
  Future<Asistencia> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/asistencias/$id'),
    );

    final datos = _datos(cuerpo);
    final item = datos['item'] as Map<String, dynamic>? ?? datos;

    if (item.isEmpty) {
      throw const ServerException('La API no devolvió la asistencia.');
    }

    return Asistencia.fromJson(item);
  }

  /// `POST /asistencias`
  ///
  /// **Los cinco campos son obligatorios**, y `registradoPor` es el que sorprende:
  /// no tiene valor por defecto en la base, así que sin él el alta falla con
  /// `asistencia.registradoPor cannot be null`. Medido.
  ///
  /// `eventoId` es **opcional** y es el enlace al evento del catálogo. El texto
  /// `evento` sigue yendo siempre y también es obligatorio: hay asistencias ya
  /// escritas que no tienen evento del catálogo, y el texto es lo que dice qué
  /// pasó aunque no haya catálogo.
  ///
  /// Cuando hay `eventoId`, `evento` se rellena con el nombre del evento para que
  /// la fila se lea sola. Si el backend lo hiciera, la app no tendría que
  /// acordarse.
  ///
  /// `evento` no puede pasar de 150 caracteres —es el `VARCHAR(150)`— y el
  /// servidor responde 400 con un mensaje que lo dice. Antes de añadir esa
  /// validación era un **500** sin explicación.
  ///
  /// `usuarioId` lo manda quien rellena y sale de la sesión.
  Future<Asistencia> crear({
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String registradoPor = Asistencia.manual,
    int? eventoId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/asistencias',
        data: _campos({
          'proveedorId': proveedorId,
          'usuarioId': usuarioId,
          'evento': evento,
          'fecha': fecha,
          'registradoPor': registradoPor,
          'eventoId': eventoId,
        }),
      ),
    );

    return Asistencia.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /asistencias/{id}`
  ///
  /// **No avisa de duplicados y el servidor no los rechaza**: registrar dos veces
  /// al mismo proveedor al mismo evento el mismo día se acepta. No es una regla
  /// del modelo, es un hueco, y la app avisa antes de guardar en vez de dejar
  /// pasar el doble.
  Future<Asistencia> editar(
    int id, {
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String? registradoPor,
    int? eventoId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/asistencias/$id',
        data: _campos({
          'proveedorId': proveedorId,
          'usuarioId': usuarioId,
          'evento': evento,
          'fecha': fecha,
          'registradoPor': registradoPor,
          'eventoId': eventoId,
        }),
      ),
    );

    return Asistencia.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /asistencias/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/asistencias/$id'));
  }

  /// Quita las claves vacías.
  ///
  /// En los dos módulos anteriores esto era casi cosmético. Aquí importa en las
  /// ediciones: **omitir un campo deja el valor anterior y mandarlo a `null` lo
  /// quita**. Por eso el constructor de la pantalla decide qué manda en vez de
  /// dejar que este helper decida.
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