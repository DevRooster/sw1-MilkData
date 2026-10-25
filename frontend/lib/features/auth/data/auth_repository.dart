import '../../../core/storage/token_storage.dart';
import '../domain/permisos.dart';
import '../domain/planta.dart';
import '../domain/sesion.dart';
import 'auth_api.dart';

/// Guarda la sesión y coordina login y logout.
///
/// Es el único lugar que escribe el token. La capa de red lo lee por su cuenta
/// en cada petición, así que nadie más necesita saber dónde está.
class AuthRepository {
  AuthRepository({required AuthApi api, required TokenStorage storage})
      : _api = api,
        _storage = storage;

  // ignore: prefer_initializing_formals
  final AuthApi _api;

  // ignore: prefer_initializing_formals
  final TokenStorage _storage;

  Future<Sesion> login({required String email, required String password}) async {
    final sesion = await _api.login(email: email, password: password);
    await _storage.guardar(sesion.token);
    return sesion;
  }

  Future<void> logout() => _storage.borrar();

  /// Si hay un token guardado, sin tocar la red.
  ///
  /// La app usa esto para decidir la pantalla inicial. Si el token ya no
  /// sirve, la primera petición protegida devolverá 401 y el interceptor
  /// cerrará la sesión.
  Future<bool> haySesion() => _storage.haySesion();

  // ------------------------------------------------------------------
  // El resto de endpoints de /auth
  //
  // Se delegan en la API porque son consultas o acciones sin efecto sobre el
  // token guardado. La única excepción es `cambiarPlanta`, que sí emite un
  // token nuevo y por eso guarda.
  // ------------------------------------------------------------------

  Future<UsuarioSesion> perfil() => _api.perfil();

  Future<UsuarioSesion> verificarToken() => _api.verificarToken();

  /// Renovar el token y **guardar el nuevo**: seguir usando el anterior
  /// funciona hasta que caduque, pero entonces la sesión se cae sola.
  Future<String> renovarToken() async {
    final token = await _api.renovarToken();
    await _storage.guardar(token);
    return token;
  }

  Future<void> confirmarLogoutRemoto() => _api.cerrarSesionRemota();

  Future<UsuarioSesion> actualizarPerfil({String? nombre, String? apellido}) =>
      _api.actualizarPerfil(nombre: nombre, apellido: apellido);

  Future<PlantasDisponibles> plantasDisponibles() => _api.plantasDisponibles();

  /// Qué módulos puede abrir esta sesión.
  ///
  /// No guarda nada: cambia con el token, y como el token cambia al cambiar de
  /// planta o de rol, quien lo necesita lo vuelve a pedir.
  Future<Permisos> permisos() => _api.permisos();

  /// Cambia de planta y guarda el token emitido.
  ///
  /// El token anterior queda ligado a la planta anterior: sin este `guardar`,
  /// la app seguiría operando donde estaba aunque la pantalla dijera otra cosa.
  Future<Planta> cambiarPlanta({int? plantaId, String? codigo}) async {
    final resultado = await _api.cambiarPlanta(plantaId: plantaId, codigo: codigo);
    await _storage.guardar(resultado.token);
    return resultado.planta;
  }

  Future<UsuarioSesion> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required int rolId,
    required int plantaId,
  }) =>
      _api.registrar(
        nombre: nombre,
        apellido: apellido,
        email: email,
        password: password,
        rolId: rolId,
        plantaId: plantaId,
      );
}