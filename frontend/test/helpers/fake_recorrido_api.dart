import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/recorridos/data/recorrido_api.dart';
import 'package:milkdata_app/features/recorridos/domain/recorrido.dart';

/// `RecorridoApi` de mentira: filtra, pagina y guarda en memoria.
///
/// **Reparte el ciclo de vida igual que el servidor**, y esto no es opcional: la
/// parte difícil de este módulo es qué transición admite qué estado, y un doble
/// más permisivo daría verde a una pantalla que ofrece botones que en el móvil
/// real responden 400.
///
/// - `iniciar` solo desde `PLANIFICADO`, y **sella las paradas**.
/// - `finalizar` solo desde `EN_RUTA`, y **pasa las pendientes a `OMITIDA`**.
/// - `cancelar` desde cualquier estado menos `FINALIZADO`.
/// - `atenderParada` solo con el recorrido `EN_RUTA`.
class FakeRecorridoApi extends RecorridoApi {
  FakeRecorridoApi({List<Recorrido>? recorridos})
      : _recorridos = recorridos ?? <Recorrido>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Recorrido> _recorridos;

  /// Paradas que se sellan al iniciar, por id de recorrido.
  final Map<int, List<ParadaRecorrido>> _paradasPorRuta = <int, List<ParadaRecorrido>>{};

  /// Lo que se pidió en la última llamada a `listar`.
  ({int pagina, int limite, String? estado, String? fecha})? ultimaConsulta;

  /// El recorrido en curso, para `actual()`.
  Recorrido? _actual;

  final List<int> eliminados = [];
  final List<int> creados = [];
  final List<int> editados = [];

  /// Cada transición que se ha pedido, en orden. Sirve para comprobar que un
  /// doble toque no mandó dos.
  final List<String> transiciones = <String>[];

  /// Las paradas que se sellarán al iniciar este recorrido.
  ///
  /// Se registran por ruta, no por recorrido: el servidor copia las paradas de
  /// la ruta en el momento de iniciar, y esa es justamente la regla que hay que
  /// poder probar.
  void conParadasDeRuta(int rutaId, List<ParadaRecorrido> paradas) {
    _paradasPorRuta[rutaId] = paradas;
  }

  @override
  Future<RecorridosPagina> listar({
    int pagina = 1,
    int limite = 10,
    EstadoRecorrido? estado,
    String? fecha,
    int? unidadId,
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      limite: limite,
      estado: estado?.valor,
      fecha: fecha != null && fecha.isNotEmpty ? fecha : null,
    );

    var filtrados = _recorridos;

    if (estado != null) {
      filtrados = filtrados.where((r) => r.estado == estado).toList();
    }
    if (fecha != null && fecha.isNotEmpty) {
      filtrados = filtrados.where((r) => r.fecha == fecha).toList();
    }
    if (unidadId != null) {
      filtrados = filtrados.where((r) => r.unidadId == unidadId).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return RecorridosPagina(
      recorridos: filtrados.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Recorrido?> actual() async => _actual;

  @override
  Future<Recorrido> ver(int id) async {
    return _recorridos.firstWhere(
      (r) => r.id == id,
      orElse: () => recorridoDePrueba(id: id),
    );
  }

  @override
  Future<Recorrido> crear({
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    // El servidor rechaza el alta si mandas el nombre del ayudante sin el
    // apellido y el DNI. El doble hace lo mismo, o una prueba que lo comprobara
    // mediría un doble más permisivo que el servidor.
    final nombre = ayudanteNombre?.trim() ?? '';
    final apellido = ayudanteApellido?.trim() ?? '';
    final dni = ayudanteDni?.trim() ?? '';

    if (nombre.isNotEmpty && (apellido.isEmpty || dni.isEmpty)) {
      throw ValidationException('El ayudante necesita nombre, apellido y DNI.');
    }

    final nuevo = Recorrido(
      id: _siguienteId(),
      rutaId: rutaId,
      unidadId: unidadId,
      acopiadorId: 1,
      estado: EstadoRecorrido.planificado,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      ayudanteNombre: nombre.isEmpty ? null : nombre,
      ayudanteApellido: apellido.isEmpty ? null : apellido,
      ayudanteDni: dni.isEmpty ? null : dni,
      ayudanteCelular: ayudanteCelular,
      observaciones: observaciones,
      // Sin paradas: se sellan al iniciar, igual que en el servidor.
    );

    _recorridos.insert(0, nuevo);
    creados.add(nuevo.id);

    return nuevo;
  }

  @override
  Future<Recorrido> editar(
    int id, {
    required int rutaId,
    required int unidadId,
    required String fecha,
    String? horaInicio,
    String? horaFin,
    int? ayudanteUsuarioId,
    String? ayudanteNombre,
    String? ayudanteApellido,
    String? ayudanteDni,
    String? ayudanteCelular,
    String? observaciones,
  }) async {
    editados.add(id);

    final indice = _recorridos.indexWhere((r) => r.id == id);
    final anterior = indice >= 0 ? _recorridos[indice] : null;

    final actualizado = Recorrido(
      id: id,
      rutaId: rutaId,
      unidadId: unidadId,
      acopiadorId: anterior?.acopiadorId ?? 1,
      estado: anterior?.estado ?? EstadoRecorrido.planificado,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      ayudanteNombre: ayudanteNombre,
      ayudanteApellido: ayudanteApellido,
      ayudanteDni: ayudanteDni,
      ayudanteCelular: ayudanteCelular,
      observaciones: observaciones,
      paradas: anterior?.paradas ?? const <ParadaRecorrido>[],
    );

    if (indice >= 0) {
      _recorridos[indice] = actualizado;
    }

    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _recorridos.removeWhere((r) => r.id == id);
  }

  @override
  Future<Recorrido> iniciar(int id) async {
    final actual = _buscar(id);
    if (actual.estado != EstadoRecorrido.planificado) {
      throw ValidationException('El recorrido ya está en estado ${actual.estado.valor}.');
    }

    transiciones.add('iniciar:$id');

    // Sellar las paradas de la ruta es lo que hace `iniciar` y lo que no hace
    // `crear`: es la diferencia entre un recorrido planificado y uno en marcha.
    final selladas = (_paradasPorRuta[actual.rutaId] ?? const <ParadaRecorrido>[])
        .map((p) => ParadaRecorrido(
              id: p.id,
              orden: p.orden,
              estado: EstadoRecorrido.pendiente,
              rutaParadaId: p.rutaParadaId,
              proveedor: p.proveedor,
            ))
        .toList();

    return _reemplazar(actual, copia: (r) => r.copyWith(
          estado: EstadoRecorrido.enRuta,
          horaInicioReal: '06:00:00',
          fechaInicio: actual.fecha,
          paradas: selladas,
        ));
  }

  @override
  Future<Recorrido> finalizar(int id) async {
    final actual = _buscar(id);
    if (actual.estado != EstadoRecorrido.enRuta) {
      throw ValidationException('Solo un recorrido EN RUTA se puede finalizar.');
    }

    transiciones.add('finalizar:$id');

    // Lo que seguía pendiente pasa a omitida, para que el reporte cuadre.
    return _reemplazar(actual, copia: (r) => r.copyWith(
          estado: EstadoRecorrido.finalizado,
          horaFinReal: '11:00:00',
          paradas: r.paradas
              .map((p) => p.pendiente
                  ? ParadaRecorrido(
                      id: p.id,
                      orden: p.orden,
                      estado: EstadoRecorrido.omitida,
                      rutaParadaId: p.rutaParadaId,
                      proveedor: p.proveedor,
                    )
                  : p)
              .toList(),
        ));
  }

  @override
  Future<Recorrido> cancelar(int id, {String? observaciones}) async {
    final actual = _buscar(id);
    if (actual.estado == EstadoRecorrido.finalizado) {
      throw ValidationException('Un recorrido finalizado no se puede cancelar.');
    }

    transiciones.add('cancelar:$id');

    return _reemplazar(actual, copia: (r) => r.copyWith(
          estado: EstadoRecorrido.cancelado,
          observaciones: observaciones ?? r.observaciones,
        ));
  }

  @override
  Future<Recorrido> atenderParada(int id, int paradaId) async {
    final actual = _buscar(id);
    if (actual.estado != EstadoRecorrido.enRuta) {
      throw ValidationException('Solo un recorrido EN RUTA tiene paradas que atender.');
    }

    transiciones.add('atender:$id:$paradaId');

    return _reemplazar(actual, copia: (r) => r.copyWith(
          paradas: r.paradas
              .map((p) => p.id == paradaId
                  ? ParadaRecorrido(
                      id: p.id,
                      orden: p.orden,
                      estado: EstadoRecorrido.atendida,
                      horaLlegada: '06:30:00',
                      rutaParadaId: p.rutaParadaId,
                      proveedor: p.proveedor,
                    )
                  : p)
              .toList(),
        ));
  }

  Recorrido _buscar(int id) {
    return _recorridos.firstWhere(
      (r) => r.id == id,
      orElse: () => recorridoDePrueba(id: id),
    );
  }

  /// Aplica la copia al recorrido guardado y devuelve el nuevo.
  ///
  /// Va en un método y no repetido en cada transición porque las cinco hacen lo
  /// mismo: cambiar la fila de la lista y, si era el de `actual()`, también esa.
  Recorrido _reemplazar(
    Recorrido actual, {
    required Recorrido Function(Recorrido) copia,
  }) {
    final actualizado = copia(actual);
    final indice = _recorridos.indexWhere((r) => r.id == actual.id);

    if (indice >= 0) {
      _recorridos[indice] = actualizado;
    }

    if (_actual?.id == actual.id) {
      _actual = actualizado;
    }

    return actualizado;
  }

  int _siguienteId() {
    if (_recorridos.isEmpty) {
      return 1;
    }
    return _recorridos.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Recorrido de ejemplo para las pruebas.
Recorrido recorridoDePrueba({
  int id = 1,
  int rutaId = 1,
  int unidadId = 1,
  int acopiadorId = 1,
  EstadoRecorrido estado = EstadoRecorrido.planificado,
  String fecha = '2026-10-13',
  String? horaInicio,
  String? horaFin,
  String? horaInicioReal,
  String? horaFinReal,
  String? observaciones,
  String? ayudanteNombre,
  String? ayudanteApellido,
  List<ParadaRecorrido> paradas = const <ParadaRecorrido>[],
}) {
  return Recorrido(
    id: id,
    rutaId: rutaId,
    unidadId: unidadId,
    acopiadorId: acopiadorId,
    estado: estado,
    fecha: fecha,
    horaInicio: horaInicio,
    horaFin: horaFin,
    horaInicioReal: horaInicioReal,
    horaFinReal: horaFinReal,
    observaciones: observaciones,
    ayudanteNombre: ayudanteNombre,
    ayudanteApellido: ayudanteApellido,
    ruta: RutaRecorrido(id: rutaId, nombre: 'Ruta Norte', codigo: 'RUTANORTE'),
    unidad: UnidadRecorrido(id: unidadId, nombre: 'Furgón 01', tipo: 'furgon'),
    acopiador: AcopiadorRecorrido(id: acopiadorId, nombre: 'Juan', apellido: 'Pérez'),
    paradas: paradas,
  );
}

/// Parada de recorrido de ejemplo para las pruebas.
ParadaRecorrido paradaRecorridoDePrueba({
  int id = 1,
  int orden = 1,
  String estado = EstadoRecorrido.pendiente,
  String? horaLlegada,
  int? rutaParadaId = 1,
  String nombreProveedor = 'Juan',
  String? apellidoProveedor = 'Pérez',
}) {
  return ParadaRecorrido(
    id: id,
    orden: orden,
    estado: estado,
    horaLlegada: horaLlegada,
    rutaParadaId: rutaParadaId,
    proveedor: ProveedorParada(
      id: id,
      nombre: nombreProveedor,
      apellido: apellidoProveedor,
      dni: '7000000$id',
      codigo: 'PROV-00$id',
    ),
  );
}
