import 'package:dio/dio.dart';
import 'package:milkdata_app/features/recolecciones/data/recoleccion_api.dart';
import 'package:milkdata_app/features/recolecciones/domain/recoleccion.dart';

/// `RecoleccionApi` de mentira: filtra y pagina en memoria.
///
/// Lo necesitan los módulos de delante —Calidad lo usa para ofrecer solo las
/// recolecciones que no tienen análisis todavía—, así que vive aquí y no dentro
/// del módulo que lo consume.
class FakeRecoleccionApi extends RecoleccionApi {
  FakeRecoleccionApi({List<Recoleccion>? recolecciones})
      : _recolecciones = recolecciones ?? _porDefecto(),
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Recoleccion> _recolecciones;

  /// Lo que se pidió en la última llamada a `listar`.
  ({int pagina, int limite})? ultimaConsulta;

  @override
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
  }) async {
    ultimaConsulta = (pagina: pagina, limite: limite);

    var filtrados = _recolecciones;

    if (fecha != null && fecha.isNotEmpty) {
      filtrados = filtrados.where((r) => r.fecha == fecha).toList();
    }
    if (proveedorId != null) {
      filtrados = filtrados.where((r) => r.proveedorId == proveedorId).toList();
    }
    if (zonaId != null) {
      filtrados = filtrados.where((r) => r.zonaId == zonaId).toList();
    }
    if (registradoEn != null && registradoEn.isNotEmpty) {
      filtrados = filtrados.where((r) => r.registradoEn == registradoEn).toList();
    }
    if (sincronizado != null) {
      filtrados = filtrados.where((r) => r.sincronizado == sincronizado).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde_ = (pagina - 1) * limite;

    return RecoleccionesPagina(
      recolecciones: filtrados.skip(desde_).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Recoleccion> ver(int id) async {
    for (final recoleccion in _recolecciones) {
      if (recoleccion.id == id) {
        return recoleccion;
      }
    }
    // La API real responde 404; aquí se devuelve uno de ejemplo porque a
    // estas pruebas solo les llega un id que existe.
    return recoleccionDePrueba(id: id);
  }

  @override
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
  }) async {
    throw UnimplementedError('Las pruebas de Calidad no crean recolecciones.');
  }

  @override
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
  }) async {
    throw UnimplementedError('Las pruebas de Calidad no editan recolecciones.');
  }

  @override
  Future<void> eliminar(int id) async {
    _recolecciones.removeWhere((r) => r.id == id);
  }

  /// Tres recolecciones, de la 1 a la 3.
  ///
  /// Tres y no dos porque las pruebas de Calidad necesitan ocupar una y dejar
  /// otra libre: con dos habría que montar un caso distinto para cada una.
  static List<Recoleccion> _porDefecto() => [1, 2, 3]
      .map((id) => recoleccionDePrueba(id: id, litros: 20.0 + id))
      .toList();
}

/// Recolección de ejemplo para las pruebas.
Recoleccion recoleccionDePrueba({
  int id = 1,
  int proveedorId = 1,
  double litros = 25,
  String fecha = '2026-10-13',
  String registradoEn = Recoleccion.campo,
  bool sincronizado = false,
}) {
  return Recoleccion(
    id: id,
    proveedorId: proveedorId,
    zonaId: 1,
    unidadId: 1,
    usuarioId: 1,
    cantidad: litros,
    fecha: fecha,
    registradoEn: registradoEn,
    sincronizado: sincronizado,
    proveedor: RecoleccionProveedor(
      id: proveedorId,
      nombre: 'Juan',
      apellido: 'Pérez',
      codigo: 'PROV-001',
    ),
  );
}
