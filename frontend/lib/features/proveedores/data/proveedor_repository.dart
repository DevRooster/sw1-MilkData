import '../domain/proveedor.dart';
import 'proveedor_api.dart';

/// Repositorio de `/proveedores`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class ProveedorRepository {
  ProveedorRepository({required this.api});

  // ignore: prefer_initializing_formals
  final ProveedorApi api;

  Future<ProveedoresPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? zonaId,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      busqueda: busqueda,
      activo: activo,
      zonaId: zonaId,
    );
  }

  Future<Proveedor> ver(int id) => api.ver(id);

  Future<Proveedor> crear({
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) {
    return api.crear(
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      telefono: telefono,
      direccion: direccion,
      zonaId: zonaId,
      activo: activo,
    );
  }

  Future<Proveedor> editar(
    int id, {
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) {
    return api.editar(
      id,
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      telefono: telefono,
      direccion: direccion,
      zonaId: zonaId,
      activo: activo,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}
