import '../domain/ruta.dart';
import 'ruta_api.dart';

/// Repositorio de `/rutas`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class RutaRepository {
  RutaRepository({required this.api});

  // ignore: prefer_initializing_formals
  final RutaApi api;

  Future<RutasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activa,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      busqueda: busqueda,
      activa: activa,
    );
  }

  Future<RutaDetalle> ver(int id) => api.ver(id);

  Future<Ruta> crear({
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) {
    return api.crear(
      nombre: nombre,
      codigo: codigo,
      descripcion: descripcion,
      horaInicio: horaInicio,
      horaFin: horaFin,
      activa: activa,
    );
  }

  Future<Ruta> editar(
    int id, {
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) {
    return api.editar(
      id,
      nombre: nombre,
      codigo: codigo,
      descripcion: descripcion,
      horaInicio: horaInicio,
      horaFin: horaFin,
      activa: activa,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}