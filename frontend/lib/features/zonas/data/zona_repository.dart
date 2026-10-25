import '../domain/zona.dart';
import 'zona_api.dart';

/// Repositorio de `/zonas`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class ZonaRepository {
  ZonaRepository({required this.api});

  // ignore: prefer_initializing_formals
  final ZonaApi api;

  Future<ZonasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? rutaId,
    int? unidadId,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      busqueda: busqueda,
      activo: activo,
      rutaId: rutaId,
      unidadId: unidadId,
    );
  }

  Future<Zona> ver(int id) => api.ver(id);

  Future<Zona> crear({
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) {
    return api.crear(
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
      activo: activo,
    );
  }

  Future<Zona> editar(
    int id, {
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) {
    return api.editar(
      id,
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
      activo: activo,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}
