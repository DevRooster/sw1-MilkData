import '../domain/notificacion.dart';
import 'notificacion_api.dart';

/// Repositorio de `/notificaciones`.
///
/// No guarda nada: el único que escribe el token es el repositorio de
/// autenticación.
class NotificacionRepository {
  NotificacionRepository({required this.api});

  // ignore: prefer_initializing_formals
  final NotificacionApi api;

  Future<NotificacionesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
    bool? enviada,
  }) {
    return api.listar(
      pagina: pagina,
      limite: limite,
      tipo: tipo,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      leida: leida,
      enviada: enviada,
    );
  }

  Future<Notificacion> ver(int id) => api.ver(id);

  Future<Notificacion> crear({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) {
    return api.crear(
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
    );
  }

  Future<Notificacion> crearEnviada({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) {
    return api.crearEnviada(
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
    );
  }

  Future<Notificacion> editar(
    int id, {
    String? tipo,
    String? titulo,
    String? mensaje,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
  }) {
    return api.editar(
      id,
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      leida: leida,
    );
  }

  Future<void> eliminar(int id) => api.eliminar(id);
}