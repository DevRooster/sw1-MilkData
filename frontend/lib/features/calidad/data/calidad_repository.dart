import '../domain/control_calidad.dart';
import 'calidad_api.dart';

/// Repositorio de `/calidad`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class CalidadRepository {
  CalidadRepository({required this.api});

  // ignore: prefer_initializing_formals
  final CalidadApi api;

  Future<ControlesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? resultado,
    int? recoleccionId,
    int? usuarioId,
    String? desde,
    String? hasta,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      resultado: resultado,
      recoleccionId: recoleccionId,
      usuarioId: usuarioId,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<ControlCalidad?> porRecoleccion(int recoleccionId) => api.porRecoleccion(recoleccionId);

  Future<ControlCalidad> ver(int id) => api.ver(id);

  Future<ControlCalidad> crear({
    required int recoleccionId,
    required int usuarioId,
    String resultado = ControlCalidad.pura,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) {
    return api.crear(
      recoleccionId: recoleccionId,
      usuarioId: usuarioId,
      resultado: resultado,
      grasa: grasa,
      proteina: proteina,
      lactosa: lactosa,
      densidad: densidad,
      temperatura: temperatura,
      aguaAnadida: aguaAnadida,
      ph: ph,
    );
  }

  Future<ControlCalidad> editar(
    int id, {
    int? recoleccionId,
    int? usuarioId,
    String? resultado,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) {
    return api.editar(
      id,
      recoleccionId: recoleccionId,
      usuarioId: usuarioId,
      resultado: resultado,
      grasa: grasa,
      proteina: proteina,
      lactosa: lactosa,
      densidad: densidad,
      temperatura: temperatura,
      aguaAnadida: aguaAnadida,
      ph: ph,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}