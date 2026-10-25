import '../domain/unidad.dart';
import 'unidad_api.dart';

/// Repositorio de `/unidades`.
///
/// No guarda nada: todas sus operaciones son sobre el recurso, y el que escribe
/// el token es el repositorio de autenticación.
class UnidadRepository {
  UnidadRepository({required this.api});

  // ignore: prefer_initializing_formals
  final UnidadApi api;

  Future<UnidadesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    bool? activo,
    bool? cerrado,
    String? busqueda,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      tipo: tipo,
      activo: activo,
      cerrado: cerrado,
      busqueda: busqueda,
    );
  }

  Future<Unidad> ver(int id) => api.ver(id);

  Future<Unidad> crear({
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) {
    return api.crear(
      nombre: nombre,
      tipo: tipo,
      capacidad: capacidad,
      cerrado: cerrado,
      activo: activo,
      acopiadorId: acopiadorId,
    );
  }

  Future<Unidad> editar(
    int id, {
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) {
    return api.editar(
      id,
      nombre: nombre,
      tipo: tipo,
      capacidad: capacidad,
      cerrado: cerrado,
      activo: activo,
      acopiadorId: acopiadorId,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}