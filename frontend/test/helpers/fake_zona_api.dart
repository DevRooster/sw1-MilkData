import 'package:dio/dio.dart';
import 'package:milkdata_app/features/zonas/data/zona_api.dart';
import 'package:milkdata_app/features/zonas/domain/zona.dart';

/// `ZonaApi` de mentira: filtra, pagina y guarda en memoria, sin tocar la red.
///
/// Reproduce el comportamiento del servidor —que los filtros se combinan y que la
/// paginación va sobre el conjunto ya filtrado— porque un fake más permisivo
/// daría verde a una lista que en el móvil real saldría mal.
class FakeZonaApi extends ZonaApi {
  FakeZonaApi({List<Zona>? zonas})
      : _zonas = zonas ?? <Zona>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Zona> _zonas;

  /// Lo que se pidió en la última llamada a `listar`, para comprobar que los
  /// filtros viajan y no se filtran en la pantalla.
  ({int pagina, int limite, String? busqueda, bool? activo, int? rutaId, int? unidadId})?
      ultimaConsulta;

  final List<int> eliminados = [];
  final List<int> creados = [];
  final List<int> editados = [];

  /// Lo que se mandó en el último alta o edición.
  ///
  /// Se guarda entero, con `rutaId` y `unidadId` tal como llegaron, porque la
  /// diferencia entre mandarlos y no mandarlos es justo lo que hay que
  /// comprobar: `null` desasigna, omitir deja el valor anterior.
  ({String nombre, String? horaInicio, String? horaFin, int? rutaId, int? unidadId})?
      ultimaGuardada;

  @override
  Future<ZonasPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? rutaId,
    int? unidadId,
  }) async {
    // La API real solo manda `busqueda` en la query si no viene vacía, y aquí se
    // registra igual. Si el doble guardara la cadena vacía, diría que viaja un
    // filtro que en realidad no viaja, y una prueba que lo comprobara estaría
    // comprobando una mentira.
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      busqueda: busqueda != null && busqueda.isNotEmpty ? busqueda : null,
      activo: activo,
      rutaId: rutaId,
      unidadId: unidadId,
    );

    var filtradas = _zonas;

    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtradas = filtradas
          .where((z) => z.nombre.toLowerCase().contains(texto))
          .toList();
    }
    if (activo != null) {
      filtradas = filtradas.where((z) => z.activo == activo).toList();
    }
    if (rutaId != null) {
      filtradas = filtradas.where((z) => z.rutaId == rutaId).toList();
    }
    if (unidadId != null) {
      filtradas = filtradas.where((z) => z.unidadId == unidadId).toList();
    }

    final totalPaginas = limite > 0 ? (filtradas.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return ZonasPagina(
      zonas: filtradas.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtradas.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Zona> ver(int id) async {
    return _zonas.firstWhere(
      (z) => z.id == id,
      orElse: () => Zona(id: id, nombre: 'Desconocida', activo: true),
    );
  }

  @override
  Future<Zona> crear({
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    ultimaGuardada = (
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
    );

    final nueva = Zona(
      id: _siguienteId(),
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
      activo: activo,
    );

    _zonas.insert(0, nueva);
    creados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Zona> editar(
    int id, {
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    ultimaGuardada = (
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
    );

    editados.add(id);

    final indice = _zonas.indexWhere((z) => z.id == id);

    // Se reemplaza entero, sin `copyWith`: en la API `PUT` pone lo que venga,
    // y un `null` desasigna. Si este doble mezclara, se estaría tapando justo
    // el comportamiento que la prueba quiere ver.
    final actualizada = Zona(
      id: id,
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      rutaId: rutaId,
      unidadId: unidadId,
      activo: activo,
    );

    if (indice >= 0) {
      _zonas[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _zonas.removeWhere((z) => z.id == id);
  }

  int _siguienteId() {
    if (_zonas.isEmpty) {
      return 1;
    }
    return _zonas.map((z) => z.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Zona de ejemplo para las pruebas.
Zona zonaDePrueba({
  int id = 1,
  String nombre = 'Zona Norte',
  String? horaInicio = '06:00:00',
  String? horaFin = '10:00:00',
  int? rutaId = 1,
  int? unidadId = 1,
  bool activo = true,
}) {
  return Zona(
    id: id,
    nombre: nombre,
    horaInicio: horaInicio,
    horaFin: horaFin,
    rutaId: rutaId,
    unidadId: unidadId,
    activo: activo,
  );
}
