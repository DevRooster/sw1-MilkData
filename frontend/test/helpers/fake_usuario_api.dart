import 'package:dio/dio.dart';
import 'package:milkdata_app/features/auth/domain/sesion.dart';
import 'package:milkdata_app/features/usuarios/data/usuario_api.dart';
import 'package:milkdata_app/features/usuarios/domain/usuario_lista.dart';

/// `UsuarioApi` de mentira: responde lo que el test le pida, sin tocar la red.
///
/// Se hereda de la clase real para no duplicar su constructor ni sus tipos.
class FakeUsuarioApi extends UsuarioApi {
  FakeUsuarioApi({List<UsuarioLista>? usuarios})
      : _usuarios = usuarios ?? <UsuarioLista>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<UsuarioLista> _usuarios;

  /// Ids a los que se pidió cambiar el rol, en orden.
  final List<({int id, int rolId})> cambiosRol = [];

  /// Ids a los que se pidió activar o desactivar.
  final List<({int id, bool activo})> cambiosActivo = [];

  /// Ids a los que se pidió eliminar.
  final List<int> eliminados = [];

  /// `(id, nombre, apellido)` de las ediciones.
  final List<({int id, String? nombre, String? apellido})> ediciones = [];

  @override
  Future<UsuariosPagina> listar({
    int pagina = 1,
    int limite = 10,
    int? rolId,
    bool? activo,
    String? busqueda,
  }) async {
    var filtrados = _usuarios;

    if (rolId != null) {
      filtrados = filtrados.where((u) => u.rol.id == rolId).toList();
    }

    if (activo != null) {
      filtrados = filtrados.where((u) => u.activo == activo).toList();
    }

    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtrados = filtrados
          .where(
            (u) =>
                u.nombre.toLowerCase().contains(texto) ||
                u.apellido.toLowerCase().contains(texto) ||
                u.email.toLowerCase().contains(texto),
          )
          .toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return UsuariosPagina(
      usuarios: filtrados.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<UsuarioLista> cambiarRol(int id, int rolId) async {
    cambiosRol.add((id: id, rolId: rolId));

    final actual = _buscar(id);
    return actual.copyWith(
      rol: Rol(
        id: rolId,
        nombre: _nombreDeRol(rolId),
        nivel: 3,
      ),
    );
  }

  @override
  Future<UsuarioLista> cambiarActivo(int id, bool activo) async {
    cambiosActivo.add((id: id, activo: activo));
    return _buscar(id).copyWith(activo: activo);
  }

  @override
  Future<UsuarioLista> editar(
    int id, {
    String? nombre,
    String? apellido,
    String? imagen,
  }) async {
    ediciones.add((id: id, nombre: nombre, apellido: apellido));
    return _buscar(id).copyWith(nombre: nombre, apellido: apellido);
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _usuarios.removeWhere((u) => u.id == id);
  }

  UsuarioLista _buscar(int id) {
    return _usuarios.firstWhere(
      (u) => u.id == id,
      orElse: () => UsuarioLista(
        id: id,
        nombre: 'Desconocido',
        apellido: '',
        email: 'desconocido@test.com',
        rol: const Rol(id: 3, nombre: 'supervisor', nivel: 3),
        activo: true,
      ),
    );
  }

  static String _nombreDeRol(int id) => switch (id) {
        2 => 'admin',
        3 => 'supervisor',
        4 => 'acopiador',
        5 => 'operador',
        6 => 'laboratorio',
        _ => 'proveedor',
      };
}

/// Usuario de ejemplo para las pruebas de la lista.
UsuarioLista usuarioDePrueba({
  int id = 1,
  String nombre = 'Ana',
  String apellido = 'Prueba',
  String email = 'ana@milkdata.com',
  String rol = 'supervisor',
  int rolId = 3,
  bool activo = true,
}) {
  return UsuarioLista(
    id: id,
    nombre: nombre,
    apellido: apellido,
    email: email,
    rol: Rol(id: rolId, nombre: rol, nivel: 3),
    activo: activo,
    plantaId: 1,
  );
}