import 'package:dio/dio.dart';
import 'package:milkdata_app/features/notificaciones/data/notificacion_api.dart';
import 'package:milkdata_app/features/notificaciones/domain/notificacion.dart';

/// `NotificacionApi` de mentira: filtra, pagina y guarda en memoria.
///
/// Lo que no es negociable aquí es que **los dos caminos de guardado sean
/// distintos**, igual que en el servidor: `crear` deja un borrador y `crearEnviada`
/// pone `enviada` y `fechaEnvio`. Un doble que los hiciera iguales daría verde a
/// una pantalla que ofrece "guardar" y "enviar" como si fueran la misma cosa,
/// cuando lo que marca el servidor es justo que no lo son.
class FakeNotificacionApi extends NotificacionApi {
  FakeNotificacionApi({List<Notificacion>? notificaciones})
      : _notificaciones = notificaciones ?? <Notificacion>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Notificacion> _notificaciones;

  /// Lo que se pidió en la última llamada a `listar`.
  ({int pagina, int limite, String? tipo, bool? leida, bool? enviada})? ultimaConsulta;

  final List<int> eliminados = <int>[];

  /// Los ids de los avisos que se crearon **como borrador**, uno por llamada.
  final List<int> borradoresCreados = <int>[];

  /// Los ids de los avisos que se crearon **y mandaron**, uno por llamada.
  final List<int> enviadosCreados = <int>[];

  @override
  Future<NotificacionesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
    bool? enviada,
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      tipo: tipo,
      leida: leida,
      enviada: enviada,
    );

    var filtrados = _notificaciones;

    if (tipo != null && tipo.isNotEmpty) {
      filtrados = filtrados.where((n) => n.tipo == tipo).toList();
    }
    if (proveedorId != null) {
      filtrados = filtrados.where((n) => n.proveedorId == proveedorId).toList();
    }
    if (leida != null) {
      filtrados = filtrados.where((n) => n.leida == leida).toList();
    }
    if (enviada != null) {
      filtrados = filtrados.where((n) => n.enviada == enviada).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return NotificacionesPagina(
      notificaciones: filtrados.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Notificacion> ver(int id) async {
    return _notificaciones.firstWhere(
      (n) => n.id == id,
      orElse: () => notificacionDePrueba(id: id),
    );
  }

  @override
  Future<Notificacion> crear({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    // Un borrador: `enviada` en `false` y sin fecha. Es lo que sale de
    // `POST /notificaciones`.
    final nueva = Notificacion(
      id: _siguienteId(),
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      leida: false,
      enviada: false,
    );

    _notificaciones.insert(0, nueva);
    borradoresCreados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Notificacion> crearEnviada({
    required String tipo,
    required String titulo,
    required String mensaje,
    int? proveedorId,
    int? usuarioId,
  }) async {
    // Un envío: `enviada` en `true` y la fecha la pone el servidor. Es un
    // endpoint aparte, no un `crear` con un interruptor.
    final nueva = Notificacion(
      id: _siguienteId(),
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      leida: false,
      enviada: true,
      fechaEnvio: DateTime(2026, 10, 13, 9, 30),
    );

    _notificaciones.insert(0, nueva);
    enviadosCreados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Notificacion> editar(
    int id, {
    String? tipo,
    String? titulo,
    String? mensaje,
    int? proveedorId,
    int? usuarioId,
    bool? leida,
  }) async {
    final indice = _notificaciones.indexWhere((n) => n.id == id);
    final anterior = indice >= 0 ? _notificaciones[indice] : null;

    final actualizada = Notificacion(
      id: id,
      proveedorId: proveedorId ?? anterior?.proveedorId,
      usuarioId: usuarioId ?? anterior?.usuarioId,
      tipo: tipo ?? anterior?.tipo ?? Notificacion.adulteracion,
      titulo: titulo ?? anterior?.titulo ?? '',
      mensaje: mensaje ?? anterior?.mensaje ?? '',
      leida: leida ?? anterior?.leida ?? false,
      // `enviada` y `fechaEnvio` no se tocan en una edición, igual que en el
      // servidor. Esta es la regla que impide crear el estado imposible de un
      // "borrador con fecha de envío".
      enviada: anterior?.enviada ?? false,
      fechaEnvio: anterior?.fechaEnvio,
      proveedor: anterior?.proveedor,
      usuario: anterior?.usuario,
    );

    if (indice >= 0) {
      _notificaciones[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _notificaciones.removeWhere((n) => n.id == id);
  }

  int _siguienteId() {
    if (_notificaciones.isEmpty) {
      return 1;
    }
    return _notificaciones.map((n) => n.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Aviso de ejemplo para las pruebas.
///
/// Por defecto **borrador**: es el estado en el que empieza todo lo que se
/// guarda sin mandar, y el que más se confunde con "ya ha salido".
Notificacion notificacionDePrueba({
  int id = 1,
  String tipo = Notificacion.adulteracion,
  String titulo = 'Lote 12 sospechoso',
  String mensaje = 'El análisis dio agua añadida.',
  bool leida = false,
  bool enviada = false,
  DateTime? fechaEnvio,
  int? proveedorId,
  int? usuarioId = 1,
  String? nombreProveedor = 'Juan',
  String? apellidoProveedor = 'Pérez',
}) {
  return Notificacion(
    id: id,
    proveedorId: proveedorId,
    usuarioId: usuarioId,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    leida: leida,
    enviada: enviada,
    fechaEnvio: fechaEnvio,
    proveedor: proveedorId == null
        ? null
        : NotificacionProveedor(
            id: proveedorId,
            nombre: nombreProveedor ?? '',
            apellido: apellidoProveedor,
          ),
    usuario: usuarioId == null
        ? null
        : NotificacionUsuario(id: usuarioId, nombre: 'Super', apellido: 'Administrador'),
  );
}