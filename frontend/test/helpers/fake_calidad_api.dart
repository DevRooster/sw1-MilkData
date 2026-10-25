import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/calidad/data/calidad_api.dart';
import 'package:milkdata_app/features/calidad/domain/control_calidad.dart';

/// `CalidadApi` de mentira: filtra, pagina y guarda en memoria.
///
/// **Reparte la regla de la recolectora única igual que el servidor**, y aquí no
/// es opcional: es la razón de existir del módulo. Un doble más permisivo
/// daría verde a una pantalla cuyo desplegable ofrece una recolección que el
/// móvil real rechaza con un 400 después de haber escrito las siete medidas.
class FakeCalidadApi extends CalidadApi {
  FakeCalidadApi({List<ControlCalidad>? controles})
      : _controles = controles ?? <ControlCalidad>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<ControlCalidad> _controles;

  /// Lo que se pidió en la última llamada a `listar`.
  ({int pagina, int limite, String? resultado, int? recoleccionId})? ultimaConsulta;

  final List<int> eliminados = <int>[];
  final List<int> creados = <int>[];
  final List<int> editados = <int>[];

  /// Los ids de recolección que este doble ha rechazado por ya estar ocupada.
  ///
  /// Lo guarda aparte del error para que una prueba pueda comprobar **que** se
  /// rechazó, no solo que saltó una excepción.
  final List<int> rechazadosPorUnico = <int>[];

  @override
  Future<ControlesPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? resultado,
    int? recoleccionId,
    int? usuarioId,
    String? desde,
    String? hasta,
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      resultado: resultado,
      recoleccionId: recoleccionId,
    );

    var filtrados = _controles;

    if (resultado != null) {
      filtrados = filtrados.where((c) => c.resultado == resultado).toList();
    }
    if (recoleccionId != null) {
      filtrados = filtrados.where((c) => c.recoleccionId == recoleccionId).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde_ = (pagina - 1) * limite;

    return ControlesPagina(
      controles: filtrados.skip(desde_).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<ControlCalidad?> porRecoleccion(int recoleccionId) async {
    for (final control in _controles) {
      if (control.recoleccionId == recoleccionId) {
        return control;
      }
    }
    // Todavía sin analizar no es un error: es el estado normal.
    return null;
  }

  @override
  Future<ControlCalidad> ver(int id) async {
    return _controles.firstWhere(
      (c) => c.id == id,
      orElse: () => controlDePrueba(id: id),
    );
  }

  @override
  Future<ControlCalidad> crear({
    required int recoleccionId,
    required int usuarioId,
    String resultado = ControlCalidad.pura,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) async {
    // `recoleccionId` es único en la base: un segundo análisis de la misma
    // recogida da 400. Igual que el servidor.
    if (_controles.any((c) => c.recoleccionId == recoleccionId)) {
      rechazadosPorUnico.add(recoleccionId);
      throw const ValidationException('Ya existe un registro con ese valor único.');
    }

    final nuevo = ControlCalidad(
      id: _siguienteId(),
      recoleccionId: recoleccionId,
      usuarioId: usuarioId,
      resultado: resultado,
      grasa: grasa,
      proteina: proteina,
      lactosa: lactosa,
      densidad: densidad,
      temperatura: temperatura,
      aguaAnadida: aguaAnadida,
      ph: ph,
    );

    _controles.insert(0, nuevo);
    creados.add(nuevo.id);

    return nuevo;
  }

  @override
  Future<ControlCalidad> editar(
    int id, {
    int? recoleccionId,
    int? usuarioId,
    String? resultado,
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
  }) async {
    editados.add(id);

    final indice = _controles.indexWhere((c) => c.id == id);
    final anterior = indice >= 0 ? _controles[indice] : null;
    final destino = recoleccionId ?? anterior?.recoleccionId ?? 0;

    // La unicidad también se cumple al editar: mover un control a una
    // recolección que ya tiene uno da el mismo 400. Medido.
    if (_controles.any((c) => c.id != id && c.recoleccionId == destino)) {
      rechazadosPorUnico.add(destino);
      throw const ValidationException('Ya existe un registro con ese valor único.');
    }

    final actualizado = ControlCalidad(
      id: id,
      recoleccionId: destino,
      usuarioId: usuarioId ?? anterior?.usuarioId ?? 1,
      resultado: resultado ?? anterior?.resultado ?? ControlCalidad.pura,
      grasa: grasa ?? anterior?.grasa,
      proteina: proteina ?? anterior?.proteina,
      lactosa: lactosa ?? anterior?.lactosa,
      densidad: densidad ?? anterior?.densidad,
      temperatura: temperatura ?? anterior?.temperatura,
      aguaAnadida: aguaAnadida ?? anterior?.aguaAnadida,
      ph: ph ?? anterior?.ph,
      recoleccion: anterior?.recoleccion,
      usuario: anterior?.usuario,
    );

    if (indice >= 0) {
      _controles[indice] = actualizado;
    }

    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _controles.removeWhere((c) => c.id == id);
  }

  int _siguienteId() {
    if (_controles.isEmpty) {
      return 1;
    }
    return _controles.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Control de ejemplo para las pruebas.
///
/// Por defecto **sin ninguna medida**: es un caso real y frecuente —un
/// veredicto con una sola temperatura, o sin nada— y el formulario lo tiene que
/// enseñar sin que parezca un fallo.
ControlCalidad controlDePrueba({
  int id = 1,
  int recoleccionId = 1,
  int usuarioId = 1,
  String resultado = ControlCalidad.pura,
  double? grasa,
  double? proteina,
  double? lactosa,
  double? densidad,
  double? temperatura,
  double? aguaAnadida,
  double? ph,
  int? fechaRecoleccion,
  String fecha = '2026-10-13',
  double? litros,
}) {
  return ControlCalidad(
    id: id,
    recoleccionId: recoleccionId,
    usuarioId: usuarioId,
    resultado: resultado,
    grasa: grasa,
    proteina: proteina,
    lactosa: lactosa,
    densidad: densidad,
    temperatura: temperatura,
    aguaAnadida: aguaAnadida,
    ph: ph,
    recoleccion: CalidadRecoleccion(
      id: recoleccionId,
      proveedorId: recoleccionId,
      fecha: fecha,
      cantidad: litros,
    ),
    usuario: CalidadUsuario(
      id: usuarioId,
      nombre: 'Laboratorio',
      apellido: 'Norte',
      email: 'lab@milkdata.com',
    ),
  );
}