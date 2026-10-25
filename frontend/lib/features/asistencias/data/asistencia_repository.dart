import '../domain/asistencia.dart';
import 'asistencia_api.dart';

/// Repositorio de `/asistencias`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class AsistenciaRepository {
  AsistenciaRepository({required this.api});

  // ignore: prefer_initializing_formals
  final AsistenciaApi api;

  Future<AsistenciasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? evento,
    String? registradoPor,
    int? proveedorId,
    int? usuarioId,
    String? fecha,
    String? desde,
    String? hasta,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      evento: evento,
      registradoPor: registradoPor,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      fecha: fecha,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<Asistencia> ver(int id) => api.ver(id);

  Future<Asistencia> crear({
    required int proveedorId,
    required int usuarioId,
    required String fecha,
    required String evento,
    String registradoPor = Asistencia.manual,
    int? eventoId,
  }) {
    return api.crear(
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      evento: evento,
      fecha: fecha,
      registradoPor: registradoPor,
      eventoId: eventoId,
    );
  }

  Future<Asistencia> editar(
    int id, {
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String? registradoPor,
    int? eventoId,
  }) {
    return api.editar(
      id,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      evento: evento,
      fecha: fecha,
      registradoPor: registradoPor,
      eventoId: eventoId,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}