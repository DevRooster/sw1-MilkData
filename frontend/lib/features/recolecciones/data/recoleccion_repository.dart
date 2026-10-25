import '../domain/recoleccion.dart';
import 'recoleccion_api.dart';

/// Repositorio de `/recolecciones`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class RecoleccionRepository {
  RecoleccionRepository({required this.api});

  // ignore: prefer_initializing_formals
  final RecoleccionApi api;

  Future<RecoleccionesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? fecha,
    int? proveedorId,
    int? zonaId,
    int? unidadId,
    String? registradoEn,
    bool? sincronizado,
    String? desde,
    String? hasta,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      fecha: fecha,
      proveedorId: proveedorId,
      zonaId: zonaId,
      unidadId: unidadId,
      registradoEn: registradoEn,
      sincronizado: sincronizado,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<Recoleccion> ver(int id) => api.ver(id);

  Future<Recoleccion> crear({
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) {
    return api.crear(
      proveedorId: proveedorId,
      zonaId: zonaId,
      unidadId: unidadId,
      usuarioId: usuarioId,
      cantidad: cantidad,
      fecha: fecha,
      registradoEn: registradoEn,
      hora: hora,
      temperatura: temperatura,
      recorridoParadaId: recorridoParadaId,
    );
  }

  Future<Recoleccion> editar(
    int id, {
    required int proveedorId,
    required int zonaId,
    required int unidadId,
    required int usuarioId,
    required double cantidad,
    required String fecha,
    required String registradoEn,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
  }) {
    return api.editar(
      id,
      proveedorId: proveedorId,
      zonaId: zonaId,
      unidadId: unidadId,
      usuarioId: usuarioId,
      cantidad: cantidad,
      fecha: fecha,
      registradoEn: registradoEn,
      hora: hora,
      temperatura: temperatura,
      recorridoParadaId: recorridoParadaId,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}
