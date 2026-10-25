import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/usuario_lista.dart';

/// Peticiones de `/usuarios`: listar, ver, editar, cambiar rol y borrar.
///
/// El alta no está aquí: pasa por `POST /auth/register`, que tiene reglas propias
/// que un `POST /usuarios` normal se saltaría.
class UsuarioApi {
  UsuarioApi(this._dio);

  final Dio _dio;

  /// `GET /usuarios`
  ///
  /// Acepta `pagina`, `limite`, `rolId`, `activo` y `busqueda`.
  Future<UsuariosPagina> listar({
    int pagina = 1,
    int limite = 10,
    int? rolId,
    bool? activo,
    String? busqueda,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/usuarios',
        queryParameters: {
          'pagina': pagina,
          'limite': limite,
          'rolId': ?rolId,
          'activo': ?activo,
          if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
        },
      ),
    );

    return UsuariosPagina.fromJson(_datos(cuerpo));
  }

  /// `GET /usuarios/{id}`
  Future<UsuarioLista> ver(int id) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/usuarios/$id'),
    );

    final datos = _datos(cuerpo);
    final usuario = datos['item'] as Map<String, dynamic>? ?? datos;

    if (usuario.isEmpty) {
      throw const ServerException('La API no devolvió el usuario.');
    }

    return UsuarioLista.fromJson(usuario);
  }

  /// `PUT /usuarios/{id}`
  ///
  /// Solo nombre, apellido, imagen y contraseña. El rol y la planta se cambian
  /// por su propio endpoint: el servidor lo rechaza aquí a propósito.
  Future<UsuarioLista> editar(
    int id, {
    String? nombre,
    String? apellido,
    String? imagen,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/usuarios/$id',
        data: {
          if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
          if (apellido != null && apellido.isNotEmpty) 'apellido': apellido,
          'imagen': ?imagen,
        },
      ),
    );

    return UsuarioLista.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /usuarios/{id}/rol`
  Future<UsuarioLista> cambiarRol(int id, int rolId) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/usuarios/$id/rol',
        data: {'rolId': rolId},
      ),
    );

    return UsuarioLista.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /usuarios/{id}/activo`
  ///
  /// Desactivar deja al usuario en la base pero le cierra la sesión. Es mejor
  /// que borrar cuando alguien deja de trabajar pero sus recolecciones tienen que
  /// seguir guardando quién las hizo.
  Future<UsuarioLista> cambiarActivo(int id, bool activo) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/usuarios/$id/activo',
        data: {'activo': activo},
      ),
    );

    return UsuarioLista.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /usuarios/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/usuarios/$id'));
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
