import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/notificacion.dart';

/// Peticiones de `/notificaciones`.
class NotificacionApi {
  NotificacionApi(this._dio);

  final Dio _dio;

  /// `GET /notificaciones`
  ///
  /// Acepta `tipo`, `proveedorId`, `usuarioId`, `leida` y `enviada`. Los cinco
  /// están declarados en `_filtros()` del servicio; lo que no reconoce el
  /// servidor lo rechaza con un 400 en vez de devolver la lista sin filtrar.
  ///
  /// `leida` y `enviada` viajan como `true` o `false` de verdad, no como
  /// texto: el servicio los convierte, y mandarlos sin convertir no haría nada
  /// útil.
  Future<NotificacionesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
    bool? enviada,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/notificaciones',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'tipo': ?(tipo != null && tipo.isNotEmpty ? tipo : null),
          'proveedorId': ?proveedorId,
          'usuarioId': ?usuarioId,
          'leida': ?leida,
          'enviada': ?enviada,
        },
      ),
    );

    return NotificacionesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /notificaciones/tipo/{tipo}`
  Future<NotificacionesPagina> porTipo(String tipo, {int pagina = 1, int limite = 10}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/notificaciones/tipo/$tipo',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    return NotificacionesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /notificaciones/proveedor/{id}`
  Future<NotificacionesPagina> porProveedor(int proveedorId, {int pagina = 1, int limite = 10}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/notificaciones/proveedor/$proveedorId',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    return NotificacionesPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /notificaciones/{id}`
  Future<Notificacion> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/notificaciones/$id'),
    );

    final datos = _datos(cuerpo);
    final item = datos['item'] as Map<String, dynamic>? ?? datos;

    if (item.isEmpty) {
      throw const ServerException('La API no devolvió la notificación.');
    }

    return Notificacion.fromJson(item);
  }

  /// `POST /notificaciones` — **crea un borrador**.
  ///
  /// El aviso queda guardado pero `enviada` en `false` y sin fecha de envío: en
  /// esta planta existe, y el proveedor no lo ha visto. Para mandarlo de verdad
  /// está [crearEnviada].
  ///
  /// Obligatorios: `tipo` (uno de los tres del `ENUM`), `titulo` y `mensaje`.
  /// `proveedorId` y `usuarioId` son opcionales: un aviso puede ir a la planta
  /// entera.
  Future<Notificacion> crear({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/notificaciones',
        data: _campos({
          'tipo': tipo,
          'titulo': titulo,
          'mensaje': mensaje,
          'proveedorId': proveedorId,
          'usuarioId': usuarioId,
        }),
      ),
    );

    return Notificacion.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `POST /notificaciones/enviar` — **crea y manda en un solo paso**.
  ///
  /// Es un endpoint aparte, no un `crear` seguido de un cambio: el servidor pone
  /// `enviada` en `true` y `fechaEnvio` con la hora de ahora. Y **manda antes de
  /// guardar**, así que si el envío falla no queda un aviso marcado como enviado
  /// que en realidad no llegó a nadie.
  Future<Notificacion> crearEnviada({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/notificaciones/enviar',
        data: _campos({
          'tipo': tipo,
          'titulo': titulo,
          'mensaje': mensaje,
          'proveedorId': proveedorId,
          'usuarioId': usuarioId,
        }),
      ),
    );

    return Notificacion.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /notificaciones/{id}`
  ///
  /// Se usa sobre todo para marcar o desmarcar como leída: **no hay endpoint
  /// aparte** para eso.
  ///
  /// **No se manda `enviada` nunca, y por una razón concreta**: el servidor no
  /// borra `fechaEnvio` cuando la pone a `false`, así que un `PUT` así dejaría
  /// un borrador con fecha de envío. Medido. Si hay que retirar un aviso, se
  /// borra; desmandar no es una operación del modelo.
  ///
  /// Editar un aviso **ya enviado** sí se acepta: el servidor no lo bloquea. La
  /// app avisa antes, pero no puede impedirlo sin inventarse una regla.
  Future<Notificacion> editar(
    int id, {
    String? tipo,
    String? titulo,
    String? mensaje,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/notificaciones/$id',
        data: _campos({
          'tipo': tipo,
          'titulo': titulo,
          'mensaje': mensaje,
          'proveedorId': proveedorId,
          'usuarioId': usuarioId,
          'leida': leida,
        }),
      ),
    );

    return Notificacion.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /notificaciones/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/notificaciones/$id'));
  }

  /// Quita las claves vacías o a `null`.
  ///
  /// Importa de verdad en las ediciones: omitir un campo **deja** el valor
  /// anterior y mandarlo a `null` lo **quita**. Por eso el constructor de la
  /// pantalla decide explícitamente qué se manda, en vez de dejar que este
  /// helper decida por su cuenta.
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