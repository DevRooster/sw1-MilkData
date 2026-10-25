import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/asistencias/data/asistencia_api.dart';
import 'package:milkdata_app/features/asistencias/domain/asistencia.dart';

/// `AsistenciaApi` de mentira: filtra, pagina y guarda en memoria.
///
/// Reparte la regla del `ENUM` igual que el servidor: `registradoPor` fuera de
/// `QR`/`manual` se rechaza con un 400. Antes de añadir la validación `isIn` en
/// la entidad, ese mismo caso devolvía un **500** sin explicación; el doble
/// reparte ya la versión buena.
class FakeAsistenciaApi extends AsistenciaApi {
  FakeAsistenciaApi({List<Asistencia>? asistencias})
      : _asistencias = asistencias ?? <Asistencia>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Asistencia> _asistencias;

  /// Lo que se pidió en la última llamada a `listar`.
  ({
    int pagina,
    int limite,
    String? evento,
    String? registradoPor,
    String? fecha,
  })? ultimaConsulta;

  final List<int> eliminados = <int>[];
  final List<int> creados = <int>[];
  final List<int> editados = <int>[];

  /// Los valores de `registradoPor` que este doble ha rechazado.
  final List<String> registrosRechazados = <String>[];

  /// Los `evento` demasiado largos que ha rechazado.
  final List<String> eventosLargos = <String>[];

  static const List<String> _registrosValidos = [Asistencia.qr, Asistencia.manual];

  @override
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
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      evento: (evento != null && evento.isNotEmpty) ? evento : null,
      registradoPor:
          (registradoPor != null && registradoPor.isNotEmpty) ? registradoPor : null,
      fecha: (fecha != null && fecha.isNotEmpty) ? fecha : null,
    );

    var filtrados = _asistencias;

    // Por fragmento, no exacto: `evento` es texto libre y quien busca "reunion"
    // tiene que encontrar "Reunión de ruta del Norte".
    //
    // **Y sin distinguir acentos**, porque el `LIKE` de MySQL con la collation
    // `utf8mb4_0900_ai_ci` tampoco los distingue: buscar "reunion" sí encuentra
    // "Reunión". Un doble más estricto que el servidor daría verde a una
    // pantalla donde alguien escribe sin tilde y no ve nada.
    final texto = (evento != null && evento.isNotEmpty) ? _sinTildes(evento) : null;
    if (texto != null) {
      filtrados = filtrados.where((a) => _sinTildes(a.evento).contains(texto)).toList();
    }
    if (registradoPor != null && registradoPor.isNotEmpty) {
      filtrados = filtrados.where((a) => a.registradoPor == registradoPor).toList();
    }
    if (proveedorId != null) {
      filtrados = filtrados.where((a) => a.proveedorId == proveedorId).toList();
    }
    if (fecha != null && fecha.isNotEmpty) {
      filtrados = filtrados.where((a) => a.fecha == fecha).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde_ = (pagina - 1) * limite;

    return AsistenciasPagina(
      asistencias: filtrados.skip(desde_).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Asistencia> ver(int id) async {
    return _asistencias.firstWhere(
      (a) => a.id == id,
      orElse: () => asistenciaDePrueba(id: id),
    );
  }

  @override
  Future<Asistencia> crear({
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String registradoPor = Asistencia.manual,
    int? eventoId,
  }) async {
    if (!_registrosValidos.contains(registradoPor)) {
      registrosRechazados.add(registradoPor);
      throw const ValidationException('Solo se admite QR o manual.');
    }

    if (evento.length > Asistencia.maximoEvento) {
      eventosLargos.add(evento);
      throw const ValidationException('El evento no puede pasar de 150 caracteres.');
    }

    final nueva = Asistencia(
      id: _siguienteId(),
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      evento: evento,
      fecha: fecha,
      registradoPor: registradoPor,
      // El `eventoId` se guarda tal cual para que la prueba pueda comprobar
      // que la asistencia apunta al evento del catálogo.
      eventoId: eventoId,
      eventoCatalogo: eventoId == null
          ? null
          : EventoAsistencia(id: eventoId, nombre: evento),
    );

    _asistencias.insert(0, nueva);
    creados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Asistencia> editar(
    int id, {
    required int proveedorId,
    required int usuarioId,
    required String evento,
    required String fecha,
    String? registradoPor,
    int? eventoId,
  }) async {
    final registro = registradoPor ?? Asistencia.manual;
    if (!_registrosValidos.contains(registro)) {
      registrosRechazados.add(registro);
      throw const ValidationException('Solo se admite QR o manual.');
    }

    editados.add(id);

    final indice = _asistencias.indexWhere((a) => a.id == id);
    final anterior = indice >= 0 ? _asistencias[indice] : null;

    final actualizada = Asistencia(
      id: id,
      proveedorId: proveedorId,
      usuarioId: usuarioId,
      evento: evento,
      fecha: fecha,
      registradoPor: registro,
      eventoId: eventoId,
      eventoCatalogo: eventoId == null
          ? null
          : EventoAsistencia(id: eventoId, nombre: evento),
      proveedor: anterior?.proveedor,
      usuario: anterior?.usuario,
    );

    if (indice >= 0) {
      _asistencias[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _asistencias.removeWhere((a) => a.id == id);
  }

  int _siguienteId() {
    if (_asistencias.isEmpty) {
      return 1;
    }
    return _asistencias.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Pasa el texto a minúsculas y **sin tildes**, como hace MySQL al comparar.
  ///
  /// Hecho con un mapa y no con `String.normalize`: quitar las tildes es
  /// exactamente lo que se necesita aquí, y un mapa deja claro cuál es cada
  /// carácter en vez de confiar en que el sistema normalice Unicode igual en
  /// todas las máquinas.
  static String _sinTildes(String texto) {
    const mapa = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };

    // `split('')` y no `codeUnits`: los code units son UTF-16 y la `ñ` ocupa
    // dos, así que quitar tildes carácter a carácter sobre ellos parte palabras.
    final salida = StringBuffer();
    for (final caracter in texto.toLowerCase().split('')) {
      salida.write(mapa[caracter] ?? caracter);
    }

    return salida.toString();
  }
}

/// Asistencia de ejemplo para las pruebas.
Asistencia asistenciaDePrueba({
  int id = 1,
  int proveedorId = 1,
  int usuarioId = 1,
  String evento = 'Reunión de ruta del Norte',
  String fecha = '2026-10-13',
  String registradoPor = Asistencia.manual,
  String? nombreProveedor = 'Juan',
  String? apellidoProveedor = 'Pérez',
}) {
  return Asistencia(
    id: id,
    proveedorId: proveedorId,
    usuarioId: usuarioId,
    evento: evento,
    fecha: fecha,
    registradoPor: registradoPor,
    proveedor: AsistenciaProveedor(
      id: proveedorId,
      nombre: nombreProveedor ?? '',
      apellido: apellidoProveedor,
    ),
    usuario: AsistenciaUsuario(
      id: usuarioId,
      nombre: 'Super',
      apellido: 'Administrador',
    ),
  );
}