import '../domain/usuario_lista.dart';
import 'usuario_api.dart';

/// Acceso a los datos de usuarios.
///
/// No hace nada más que delegar: cada método de la API es una petición y cada
/// petición devuelve su modelo. El repositorio existe para que la pantalla
/// dependa de una abstracción y no del cliente HTTP, que es lo que permite
/// sustituirlo en las pruebas.
class UsuarioRepository {
  UsuarioRepository({required UsuarioApi api}) : _api = api;

  // ignore: prefer_initializing_formals
  final UsuarioApi _api;

  Future<UsuariosPagina> listar({
    int pagina = 1,
    int limite = 10,
    int? rolId,
    bool? activo,
    String? busqueda,
  }) {
    return _api.listar(
      pagina: pagina,
      limite: limite,
      rolId: rolId,
      activo: activo,
      busqueda: busqueda,
    );
  }

  Future<UsuarioLista> editar(
    int id, {
    String? nombre,
    String? apellido,
    String? imagen,
  }) {
    return _api.editar(id, nombre: nombre, apellido: apellido, imagen: imagen);
  }

  Future<UsuarioLista> cambiarRol(int id, int rolId) => _api.cambiarRol(id, rolId);

  Future<UsuarioLista> cambiarActivo(int id, bool activo) => _api.cambiarActivo(id, activo);

  Future<void> eliminar(int id) => _api.eliminar(id);
}