import 'package:dio/dio.dart';
import 'package:milkdata_app/features/reportes/data/reporte_api.dart';
import 'package:milkdata_app/features/reportes/domain/reporte.dart';

/// `ReporteApi` de mentira con las cuatro formas reales medidas contra la API.
///
/// Los importes vienen **tal cual los devuelve el servidor**, con los flotantes
/// largos (`52.501000000000005`) y los `null` donde no hay muestra. Un doble que
/// redondeara los números daría verde a una pantalla que enseña `52.5` con punto
/// decimal y sin tildes, que es justo lo que hay que evitar.
class FakeReporteApi extends ReporteApi {
  FakeReporteApi({
    List<FilaContraste>? contraste,
    FilaCalidad? calidad,
    List<FilaCalidad>? calidadPorProveedor,
    List<FilaCalidad>? calidadDe,
  })  : _contraste = contraste ?? const <FilaContraste>[],
        _calidad = calidad,
        _calidadPorProveedor = calidadPorProveedor ?? const <FilaCalidad>[],
        _calidadDe = calidadDe ?? const <FilaCalidad>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<FilaContraste> _contraste;
  final FilaCalidad? _calidad;
  final List<FilaCalidad> _calidadPorProveedor;
  final List<FilaCalidad> _calidadDe;

  /// Cuántas veces se ha pedido cada reporte, y con qué id de proveedor.
  final List<String> peticiones = <String>[];

  /// Los proveedores pedidos uno por uno.
  final List<int> proveedoresPedidos = <int>[];

  @override
  Future<Reporte<FilaContraste>> contraste() async {
    peticiones.add('contraste');
    return Reporte<FilaContraste>(
      nombre: 'contraste',
      filas: _contraste,
      plantaId: 1,
    );
  }

  @override
  Future<Reporte<FilaCalidad>> calidad() async {
    peticiones.add('calidad');
    return Reporte<FilaCalidad>(
      nombre: 'calidad',
      filas: _calidad == null ? const <FilaCalidad>[] : <FilaCalidad>[_calidad],
      plantaId: 1,
    );
  }

  @override
  Future<Reporte<FilaCalidad>> calidadPorProveedor() async {
    peticiones.add('calidadPorProveedor');
    return Reporte<FilaCalidad>(
      nombre: 'calidadProveedor',
      filas: _calidadPorProveedor,
      plantaId: 1,
    );
  }

  @override
  Future<Reporte<FilaCalidad>> calidadDeProveedor(int proveedorId) async {
    peticiones.add('calidadDeProveedor');
    proveedoresPedidos.add(proveedorId);

    // **Reparte la regla incómoda**: un proveedor que no existe devuelve una fila
    // con cero muestras, no un 404. Medido contra la API con el 9999. Si el doble
    // devolviera un error, la prueba estaría midiendo una regla que el servidor no
    // tiene.
    return Reporte<FilaCalidad>(
      nombre: 'calidadProveedor',
      filas: _calidadDe,
      plantaId: 1,
    );
  }
}

/// Fila de contraste de ejemplo, con los números tal cual los manda el servidor.
FilaContraste filaContraste({
  int proveedorId = 1,
  String fecha = '2026-10-13',
  double cantidadCampo = 52.501,
  double cantidadPlanta = 25.5,
  double? porcentajeDiferencia = -51.42949658101751,
}) {
  return FilaContraste(
    proveedorId: proveedorId,
    fecha: fecha,
    cantidadCampo: cantidadCampo,
    cantidadPlanta: cantidadPlanta,
    diferencia: cantidadCampo - cantidadPlanta,
    porcentajeDiferencia: porcentajeDiferencia,
  );
}

/// Fila de calidad de ejemplo.
FilaCalidad filaCalidad({
  int? proveedorId,
  int muestras = 2,
  Map<String, double?>? promedios,
}) {
  return FilaCalidad(
    proveedorId: proveedorId,
    muestras: muestras,
    promedios: promedios ??
        const <String, double?>{
          'Grasa': 3.5,
          'Proteína': 3.2,
          'Lactosa': 4.8,
          'Densidad': null,
          'pH': null,
          'Temp.': null,
          'Agua añadida': null,
        },
  );
}