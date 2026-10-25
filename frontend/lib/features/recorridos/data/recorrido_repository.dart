import '../domain/recorrido.dart';
import 'recorrido_api.dart';

/// Repositorio de `/recorridos`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class RecorridoRepository {
  RecorridoRepository({required this.api});

  // ignore: prefer_initializing_formals
  final RecorridoApi api;

  Future<RecorridosPagina> listar({
    int pagina = 1,
    int limite = 10,
    EstadoRecorrido? estado,
    String? fecha,
    int? unidadId,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      estado: estado,
      fecha: fecha,
      unidadId: unidadId,
    );
  }

  Future<Recorrido?> actual() => api.actual();

  Future<Recorrido> ver(int id) => api.ver(id);

  Future<Recorrido> crear({
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) {
    return api.crear(
      rutaId: rutaId,
      unidadId: unidadId,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      ayudanteUsuarioId: ayudanteUsuarioId,
      ayudanteNombre: ayudanteNombre,
      ayudanteApellido: ayudanteApellido,
      ayudanteDni: ayudanteDni,
      ayudanteCelular: ayudanteCelular,
      observaciones: observaciones,
    );
  }

  Future<Recorrido> editar(
    int id, {
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) {
    return api.editar(
      id,
      rutaId: rutaId,
      unidadId: unidadId,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      ayudanteUsuarioId: ayudanteUsuarioId,
      ayudanteNombre: ayudanteNombre,
      ayudanteApellido: ayudanteApellido,
      ayudanteDni: ayudanteDni,
      ayudanteCelular: ayudanteCelular,
      observaciones: observaciones,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);

  /// El ciclo de vida y las paradas. Devuelven el recorrido entero ya
  /// actualizado, porque **una transición cambia más cosas de las que parece**:
  /// iniciar sella las paradas y poner la hora real, y finalizar marca las
  /// pendientes como omitidas.
  Future<Recorrido> iniciar(int id) => api.iniciar(id);

  Future<Recorrido> finalizar(int id) => api.finalizar(id);

  Future<Recorrido> cancelar(int id, {String? observaciones}) =>
      api.cancelar(id, observaciones: observaciones);

  Future<Recorrido> atenderParada(int id, int paradaId) =>
      api.atenderParada(id, paradaId);

  Future<Recorrido> recolectarEnParada(
    int id,
    int paradaId, {
    double? cantidad,
    String? observaciones,
  }) {
    return api.recolectarEnParada(
      id,
      paradaId,
      cantidad: cantidad,
      observaciones: observaciones,
    );
  }
}
