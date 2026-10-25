import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../domain/permisos.dart';
import '../domain/planta.dart';
import '../domain/sesion.dart';

/// Llamadas de autenticación contra la API.
///
/// Solo habla con el servidor: no sabe nada de Riverpod ni de la pantalla.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /auth/login`
  ///
  /// Lanza `AppException` si falla; nunca devuelve `null`.
  Future<Sesion> login({required String email, required String password}) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
        // El login se marca para no mandar un token viejo que confunda a la
        // API ni disparar el cierre de sesión ante un 401 esperado.
        options: Options(extra: const {marcaSinToken: true}),
      ),
    );

    final datos = _datos(cuerpo);

    if (!cuerpo.containsKey('success') || cuerpo['success'] != true) {
      throw ServerException(
        (cuerpo['message'] as String?) ?? 'No se pudo iniciar sesión.',
      );
    }

    final token = datos['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ServerException('La API no devolvió un token de sesión.');
    }

    return Sesion.fromJson(datos);
  }

  /// `GET /auth/perfil`
  ///
  /// Se usa al arrancar la app: si quedó un token guardado, hace falta saber
  /// quién es y con qué rol, y eso solo lo da el servidor.
  Future<UsuarioSesion> perfil() async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/auth/perfil'));
    final datos = _datos(cuerpo);

    // El endpoint responde `{ data: { user: {...} } }`.
    final usuario = datos['user'] as Map<String, dynamic>? ?? datos;

    if (cuerpo['success'] == true && usuario.isNotEmpty) {
      return UsuarioSesion.fromJson(usuario);
    }

    throw const ServerException('La API no devolvió el perfil del usuario.');
  }

  /// `POST /auth/verify`
  ///
  /// Confirma si el token guardado sigue siendo válido. No cambia nada: por eso
  /// no cierra sesión ni toca el almacén.
  Future<UsuarioSesion> verificarToken() async {
    final cuerpo = await _enviar(() => _dio.post<Map<String, dynamic>>('/auth/verify'));
    final datos = _datos(cuerpo);
    final usuario = datos['user'] as Map<String, dynamic>? ?? datos;

    if (cuerpo['success'] == true && usuario.isNotEmpty) {
      return UsuarioSesion.fromJson(usuario);
    }

    throw const ServerException('La API no confirmó el token.');
  }

  /// `POST /auth/refresh`
  ///
  /// Devuelve un token nuevo. El anterior sigue sirviendo hasta que expire, así
  /// que renovar no corta la sesión.
  Future<String> renovarToken() async {
    final cuerpo = await _enviar(() => _dio.post<Map<String, dynamic>>('/auth/refresh'));
    final token = _datos(cuerpo)['token'] as String?;

    if (token == null || token.isEmpty) {
      throw const ServerException('La API no devolvió un token nuevo.');
    }

    return token;
  }

  /// `POST /auth/logout`
  ///
  /// El servidor solo confirma: el token es stateless y no se puede revocar en
  /// el servidor, así que quitarlo del dispositivo es cosa de la app.
  Future<void> cerrarSesionRemota() async {
    await _enviar(() => _dio.post<Map<String, dynamic>>('/auth/logout'));
  }

  /// `PUT /auth/perfil`
  ///
  /// Solo admite nombre y apellido. Aunque se manden `email`, `password`,
  /// `rolId` o `plantaId`, el servidor los ignora: son de solo lectura.
  Future<UsuarioSesion> actualizarPerfil({String? nombre, String? apellido}) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/auth/perfil',
        data: {
          if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
          if (apellido != null && apellido.isNotEmpty) 'apellido': apellido,
        },
      ),
    );

    final datos = _datos(cuerpo);
    final usuario = datos['user'] as Map<String, dynamic>? ?? datos;

    if (usuario.isEmpty) {
      throw const ServerException('La API no devolvió el perfil actualizado.');
    }

    return UsuarioSesion.fromJson(usuario);
  }

  /// `GET /auth/plantas`
  ///
  /// A qué plantas tiene acceso la sesión actual.
  Future<PlantasDisponibles> plantasDisponibles() async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/auth/plantas'));

    if (cuerpo['success'] != true) {
      throw ServerException((cuerpo['message'] as String?) ?? 'No se pudieron listar las plantas.');
    }

    return PlantasDisponibles.fromJson(_datos(cuerpo));
  }

  /// `GET /auth/permisos`
  ///
  /// Qué recursos puede usar este token. Lo decide el servidor con la misma
  /// matriz que aplica a cada petición, así que el menú de la app se dibuja con
  /// lo que la API va a responder de verdad.
  Future<Permisos> permisos() async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/auth/permisos'));

    if (cuerpo['success'] != true) {
      throw ServerException((cuerpo['message'] as String?) ?? 'No se pudieron leer los permisos.');
    }

    return Permisos.fromJson(_datos(cuerpo));
  }

  /// `POST /auth/planta`
  ///
  /// Solo superadmin. Devuelve un token nuevo atado a esa planta: el aislamiento
  /// sigue igual, lo que cambia es sobre qué planta opera ese token. Por eso
  /// hay que guardar el token devuelto; con el anterior se sigue trabajando en
  /// la planta anterior.
  ///
  /// Acepta `plantaId` o `codigo`, que es como lo usa la app móvil.
  Future<({String token, Planta planta})> cambiarPlanta({int? plantaId, String? codigo}) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/planta',
        data: {
          'plantaId': ?plantaId,
          if (codigo != null && codigo.isNotEmpty) 'codigo': codigo,
        },
      ),
    );

    final datos = _datos(cuerpo);
    final token = datos['token'] as String?;
    final plantaJson = datos['planta'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty || plantaJson == null) {
      throw const ServerException('La API no devolvió la planta solicitada.');
    }

    return (token: token, planta: Planta.fromJson(plantaJson));
  }

  /// `POST /auth/register`
  ///
  /// Exige rol admin o superadmin, y `plantaId` siempre: el registro nunca
  /// deduce en qué planta va el usuario.
  Future<UsuarioSesion> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required int rolId,
    required int plantaId,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'nombre': nombre,
          'apellido': apellido,
          'email': email,
          'password': password,
          'rolId': rolId,
          'plantaId': plantaId,
        },
      ),
    );

    final datos = _datos(cuerpo);
    final usuario = datos['user'] as Map<String, dynamic>? ?? datos;

    if (usuario.isEmpty) {
      throw const ServerException('La API no devolvió el usuario creado.');
    }

    return UsuarioSesion.fromJson(usuario);
  }

  // ------------------------------------------------------------------
  // Utilidades compartidas por los 9 endpoints
  // ------------------------------------------------------------------

  /// Envuelve la llamada y deja todo error como `AppException`.
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

  /// Saca el objeto `data` de la envoltura común de la API.
  Map<String, dynamic> _datos(Map<String, dynamic> cuerpo) {
    return (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }
}