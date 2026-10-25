import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/evento.dart';

/// Peticiones de `/eventos`.
class EventoApi {
  EventoApi(this._dio);

  final Dio _dio;

  /// `GET /eventos`
  ///
  /// Acepta `nombre`, `busqueda`, `lugar`, `fecha`, `desde` y `hasta`. Los seis
  /// están declarados en `_filtros()` del servicio; lo que no reconoce el
  /// servidor lo rechaza con un 400 en vez de devolver la lista sin filtrar.
  ///
  /// `nombre` y `busqueda` van **por fragmento**: quien recuerda "reunion" tiene
  /// que encontrar "Reunión de ruta del Norte". El `LIKE` de MySQL no distingue
  /// mayúsculas ni acentos, así que buscar sin tilde también la encuentra.
  Future<EventosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? nombre,
    String? busqueda,
    String? lugar,
    String? fecha,
    String? desde,
    String? hasta,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/eventos',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'nombre': ?(nombre != null && nombre.isNotEmpty ? nombre : null),
          'busqueda': ?(busqueda != null && busqueda.isNotEmpty ? busqueda : null),
          'lugar': ?(lugar != null && lugar.isNotEmpty ? lugar : null),
          'fecha': ?(fecha != null && fecha.isNotEmpty ? fecha : null),
          'desde': ?(desde != null && desde.isNotEmpty ? desde : null),
          'hasta': ?(hasta != null && hasta.isNotEmpty ? hasta : null),
        },
      ),
    );

    return EventosPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /eventos/nombre/{nombre}`
  ///
  /// Coincidencia **exacta**, a diferencia del filtro `nombre` de la lista, que va
  /// por fragmento. La app usa el filtro de la lista.
  Future<EventosPagina> porNombre(String nombre, {int pagina = 1, int limite = 10}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/eventos/nombre/$nombre',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    return EventosPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /eventos/{id}`
  Future<Evento> ver(int id) async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/eventos/$id'));
    final datos = _datos(cuerpo);
    final item = datos['item'] as Map<String, dynamic>? ?? datos;

    if (item.isEmpty) {
      throw const ServerException('La API no devolvió el evento.');
    }

    return Evento.fromJson(item);
  }

  /// `POST /eventos`
  ///
  /// **`nombre` y `fecha` son obligatorios y los dos dan 400 si faltan.** La fecha
  /// con `""` daba un **500** hasta que se le puso validación: `allowNull` no coge
  /// la cadena vacía, MySQL la convertía en "Invalid date" y reventaba.
  ///
  /// `lugar` y `descripcion` son opcionales y **se omiten, no se mandan vacíos**:
  /// mandarlos en blanco los deja como cadena vacía en la base, y un evento con
  /// sitio "" se ve en el desplegable como "Reunión · ".
  Future<Evento> crear({
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/eventos',
        data: _campos({
          'nombre': nombre,
          'fecha': fecha,
          'lugar': lugar,
          'descripcion': descripcion,
        }),
      ),
    );

    return Evento.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /eventos/{id}`
  Future<Evento> editar(
    int id, {
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/eventos/$id',
        data: _campos({
          'nombre': nombre,
          'fecha': fecha,
          'lugar': lugar,
          'descripcion': descripcion,
        }),
      ),
    );

    return Evento.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /eventos/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/eventos/$id'));
  }

  /// Quita las claves vacías.
  ///
  /// Importa de verdad aquí: mandar `lugar: ""` guarda una cadena vacía, y quitar
  /// la clave la deja como estaba. Quitar un sitio de un evento y no vaciarlo es
  /// justo lo que quiere quien edita.
  Map<String, dynamic> _campos(Map<String, dynamic> campos) {
    final limpio = <String, dynamic>{};

    for (final entrada in campos.entries) {
      final valor = entrada.value;
      if (valor == null || (valor is String && valor.trim().isEmpty)) {
        continue;
      }
      limpio[entrada.key] = valor is String ? valor.trim() : valor;
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