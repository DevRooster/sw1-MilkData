import 'package:dio/dio.dart';
import 'package:milkdata_app/features/unidades/data/unidad_api.dart';
import 'package:milkdata_app/features/unidades/domain/unidad.dart';

/// `UnidadApi` de mentira: filtra, pagina y guarda en memoria, sin tocar la red.
///
/// Reproduce el comportamiento del servidor —incluido que los filtros se
/// combinan y que la paginación va sobre el conjunto ya filtrado— porque un fake
/// más permisivo daría verde a una lista que en el móvil real saldría mal.
class FakeUnidadApi extends UnidadApi {
  FakeUnidadApi({List<Unidad>? unidades})
      : _unidades = unidades ?? <Unidad>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Unidad> _unidades;

  /// Lo que se pidió en la última llamada a `listar`, para comprobar que los
  /// filtros viajan y no se filtran en la pantalla.
  ({int pagina, int limite, String? tipo, bool? activo, bool? cerrado, String? busqueda})?
      ultimaConsulta;

  /// Ids eliminados, en orden.
  final List<int> eliminados = [];

  /// Ids creados, en orden.
  final List<int> creados = [];

  /// Ids editados, en orden.
  final List<int> editados = [];

  @override
  Future<UnidadesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? tipo,
    bool? activo,
    bool? cerrado,
    String? busqueda,
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      tipo: tipo,
      activo: activo,
      cerrado: cerrado,
      busqueda: busqueda,
    );

    var filtradas = _unidades;

    if (tipo != null) {
      filtradas = filtradas.where((u) => u.tipo == tipo).toList();
    }
    if (activo != null) {
      filtradas = filtradas.where((u) => u.activo == activo).toList();
    }
    if (cerrado != null) {
      filtradas = filtradas.where((u) => u.cerrado == cerrado).toList();
    }
    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtradas = filtradas
          .where((u) => u.nombre.toLowerCase().contains(texto))
          .toList();
    }

    final totalPaginas = limite > 0 ? (filtradas.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return UnidadesPagina(
      unidades: filtradas.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtradas.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Unidad> crear({
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    final nueva = Unidad(
      id: _siguienteId(),
      nombre: nombre,
      tipo: tipo,
      capacidad: capacidad,
      cerrado: cerrado,
      activo: activo,
      plantaId: 1,
      acopiadorId: acopiadorId,
    );

    _unidades.insert(0, nueva);
    creados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Unidad> editar(
    int id, {
    required String nombre,
    required String tipo,
    required double capacidad,
    required bool cerrado,
    required bool activo,
    int? acopiadorId,
  }) async {
    editados.add(id);

    final indice = _unidades.indexWhere((u) => u.id == id);
    final anterior = indice >= 0 ? _unidades[indice] : null;

    final actualizada = Unidad(
      id: id,
      nombre: nombre,
      tipo: tipo,
      capacidad: capacidad,
      cerrado: cerrado,
      activo: activo,
      plantaId: anterior?.plantaId ?? 1,
      acopiadorId: acopiadorId,
    );

    if (indice >= 0) {
      _unidades[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _unidades.removeWhere((u) => u.id == id);
  }

  int _siguienteId() {
    if (_unidades.isEmpty) {
      return 1;
    }
    return _unidades.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Unidad de ejemplo para las pruebas.
Unidad unidadDePrueba({
  int id = 1,
  String nombre = 'Unidad Furgón 01',
  String tipo = 'furgon',
  double capacidad = 1500,
  bool cerrado = false,
  bool activo = true,
  int? acopiadorId,
}) {
  return Unidad(
    id: id,
    nombre: nombre,
    tipo: tipo,
    capacidad: capacidad,
    cerrado: cerrado,
    activo: activo,
    plantaId: 1,
    acopiadorId: acopiadorId,
  );
}