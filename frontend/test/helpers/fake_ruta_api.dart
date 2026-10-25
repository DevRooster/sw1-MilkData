import 'package:dio/dio.dart';
import 'package:milkdata_app/features/rutas/data/ruta_api.dart';
import 'package:milkdata_app/features/rutas/domain/ruta.dart';

/// `RutaApi` de mentira: filtra, pagina y guarda en memoria, sin tocar la red.
///
/// Reproduce el comportamiento del servidor —que los filtros se combinan y que la
/// paginación va sobre el conjunto ya filtrado— porque un fake más permisivo
/// daría verde a una lista que en el móvil real saldría mal.
class FakeRutaApi extends RutaApi {
  FakeRutaApi({List<Ruta>? rutas})
      : _rutas = rutas ?? <Ruta>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Ruta> _rutas;

  /// Paradas por ruta, para que `ver` devuelva el detalle completo.
  final Map<int, List<ParadaRuta>> _paradas = <int, List<ParadaRuta>>{};

  /// Lo que se pidió en la última llamada a `listar`, para comprobar que los
  /// filtros viajan y no se filtran en la pantalla.
  ({int pagina, int limite, String? busqueda, bool? activa})? ultimaConsulta;

  final List<int> eliminados = [];
  final List<int> creados = [];
  final List<int> editados = [];

  /// Paradas que se registran para poder comprobarlas en las pruebas.
  void conParadas(int rutaId, List<ParadaRuta> paradas) {
    _paradas[rutaId] = paradas;
  }

  @override
  Future<RutasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activa,
  }) async {
    // La API real solo manda `busqueda` en la query si no viene vacía, y aquí se
    // registra igual. Si el doble guardara la cadena vacía, diría que viaja un
    // filtro que en realidad no viaja, y una prueba que lo comprobara estaría
    // comprobando una mentira.
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      busqueda: busqueda != null && busqueda.isNotEmpty ? busqueda : null,
      activa: activa,
    );

    var filtradas = _rutas;

    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtradas = filtradas
          .where(
            (r) =>
                r.nombre.toLowerCase().contains(texto) ||
                r.codigo.toLowerCase().contains(texto),
          )
          .toList();
    }
    if (activa != null) {
      filtradas = filtradas.where((r) => r.activa == activa).toList();
    }

    final totalPaginas = limite > 0 ? (filtradas.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return RutasPagina(
      rutas: filtradas.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtradas.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<RutaDetalle> ver(int id) async {
    final ruta = _rutas.firstWhere(
      (r) => r.id == id,
      orElse: () => Ruta(id: id, nombre: 'Desconocida', codigo: '???', activa: true),
    );

    return RutaDetalle(
      id: ruta.id,
      nombre: ruta.nombre,
      codigo: ruta.codigo,
      descripcion: ruta.descripcion,
      horaInicio: ruta.horaInicio,
      horaFin: ruta.horaFin,
      activa: ruta.activa,
      zonas: ruta.zonas,
      paradas: _paradas[id] ?? const <ParadaRuta>[],
    );
  }

  @override
  Future<Ruta> crear({
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    final nueva = Ruta(
      id: _siguienteId(),
      nombre: nombre,
      codigo: codigo,
      descripcion: descripcion,
      horaInicio: horaInicio,
      horaFin: horaFin,
      activa: activa,
    );

    _rutas.insert(0, nueva);
    creados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Ruta> editar(
    int id, {
    required String nombre,
    required String codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    required bool activa,
  }) async {
    editados.add(id);

    final indice = _rutas.indexWhere((r) => r.id == id);
    final anterior = indice >= 0 ? _rutas[indice] : null;

    final actualizada = Ruta(
      id: id,
      nombre: nombre,
      codigo: codigo,
      descripcion: descripcion,
      horaInicio: horaInicio,
      horaFin: horaFin,
      activa: activa,
      paradasCount: anterior?.paradasCount ?? 0,
      zonas: anterior?.zonas ?? const <ZonaRuta>[],
    );

    if (indice >= 0) {
      _rutas[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _rutas.removeWhere((r) => r.id == id);
  }

  int _siguienteId() {
    if (_rutas.isEmpty) {
      return 1;
    }
    return _rutas.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Ruta de ejemplo para las pruebas.
Ruta rutaDePrueba({
  int id = 1,
  String nombre = 'Ruta Norte',
  String codigo = 'RUTANORTE',
  String? descripcion = 'Recoge la zona norte',
  String? horaInicio = '06:00:00',
  String? horaFin = '11:00:00',
  bool activa = true,
  int paradasCount = 0,
  List<ZonaRuta> zonas = const <ZonaRuta>[],
}) {
  return Ruta(
    id: id,
    nombre: nombre,
    codigo: codigo,
    descripcion: descripcion,
    horaInicio: horaInicio,
    horaFin: horaFin,
    activa: activa,
    paradasCount: paradasCount,
    zonas: zonas,
  );
}

/// Parada de ejemplo para las pruebas.
ParadaRuta paradaDePrueba({
  int id = 1,
  int proveedorId = 1,
  int orden = 1,
  String? horaEstimada = '06:30:00',
  bool activa = true,
  String nombreProveedor = 'Juan',
  String? apellidoProveedor = 'Pérez',
}) {
  return ParadaRuta(
    id: id,
    proveedorId: proveedorId,
    orden: orden,
    horaEstimada: horaEstimada,
    activa: activa,
    proveedor: ProveedorRuta(
      id: proveedorId,
      nombre: nombreProveedor,
      apellido: apellidoProveedor,
      codigo: 'PROV-001',
    ),
  );
}
