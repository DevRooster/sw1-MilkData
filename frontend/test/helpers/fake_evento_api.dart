import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/eventos/data/evento_api.dart';
import 'package:milkdata_app/features/eventos/domain/evento.dart';

/// `EventoApi` de mentira, con la forma real que devuelve el servidor.
///
/// Reparte las dos validaciones que el backend hace y que antes de añadirlas
/// contestaban **500** en vez de 400: el nombre de más de 150 caracteres y la fecha
/// en blanco. Un doble más permisivo daría verde a una pantalla que deja pasar lo
/// que el servidor no acepta.
class FakeEventoApi extends EventoApi {
  FakeEventoApi({List<Evento>? eventos})
      : _eventos = eventos ?? <Evento>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Evento> _eventos;

  /// Lo que se pidió en la última llamada a `listar`.
  ({int pagina, String? busqueda, String? desde, String? hasta})? ultimaConsulta;

  final List<int> eliminados = <int>[];
  final List<int> creados = <int>[];
  final List<int> editados = <int>[];

  /// Los nombres demasiado largos que este doble ha rechazado.
  final List<String> nombresLargos = <String>[];

  /// Las fechas que ha rechazado, en el orden en que llegaron.
  final List<String> fechasRechazadas = <String>[];

  /// `false` para simular que el servidor se cae al cargar la lista de eventos.
  bool fallarAlListar = false;

  @override
  Future<EventosPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? nombre,
    String? busqueda,
    String? lugar,
    String? fecha,
    String? desde,
    String? hasta,
  }) async {
    ultimaConsulta = (
      pagina: pagina,
      busqueda: (busqueda != null && busqueda.isNotEmpty) ? busqueda : null,
      desde: (desde != null && desde.isNotEmpty) ? desde : null,
      hasta: (hasta != null && hasta.isNotEmpty) ? hasta : null,
    );

    if (fallarAlListar) {
      throw const ServerException('No se pudieron cargar los eventos.');
    }

    var filtrados = _eventos;

    // Por fragmento y **sin tildes**, como el `LIKE` de MySQL: quien busca
    // "reunion" tiene que encontrar "Reunión de ruta del Norte".
    final texto = (busqueda != null && busqueda.isNotEmpty) ? _sinTildes(busqueda) : null;
    if (texto != null) {
      filtrados = filtrados
          .where(
            (e) =>
                _sinTildes(e.nombre).contains(texto) ||
                _sinTildes(e.lugar ?? '').contains(texto) ||
                _sinTildes(e.descripcion ?? '').contains(texto),
          )
          .toList();
    }

    final desdeF = (desde != null && desde.isNotEmpty) ? desde : null;
    final hastaF = (hasta != null && hasta.isNotEmpty) ? hasta : null;
    if (desdeF != null) {
      filtrados = filtrados.where((e) => e.fecha.compareTo(desdeF) >= 0).toList();
    }
    if (hastaF != null) {
      filtrados = filtrados.where((e) => e.fecha.compareTo(hastaF) <= 0).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde_ = (pagina - 1) * limite;

    return EventosPagina(
      eventos: filtrados.skip(desde_).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Evento> ver(int id) async {
    return _eventos.firstWhere(
      (e) => e.id == id,
      orElse: () => eventoDePrueba(id: id),
    );
  }

  @override
  Future<Evento> crear({
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    _validar(nombre, fecha);

    final nuevo = Evento(
      id: _siguienteId(),
      plantaId: 1,
      nombre: nombre,
      fecha: fecha,
      lugar: (lugar != null && lugar.trim().isNotEmpty) ? lugar.trim() : null,
      descripcion:
          (descripcion != null && descripcion.trim().isNotEmpty) ? descripcion.trim() : null,
    );

    _eventos.add(nuevo);
    creados.add(nuevo.id);

    return nuevo;
  }

  @override
  Future<Evento> editar(
    int id, {
    required String nombre,
    required String fecha,
    String? lugar,
    String? descripcion,
  }) async {
    _validar(nombre, fecha);

    editados.add(id);

    final indice = _eventos.indexWhere((e) => e.id == id);
    final anterior = indice >= 0 ? _eventos[indice] : null;

    final actualizado = Evento(
      id: id,
      plantaId: anterior?.plantaId ?? 1,
      nombre: nombre,
      fecha: fecha,
      lugar: (lugar != null && lugar.trim().isNotEmpty) ? lugar.trim() : null,
      descripcion:
          (descripcion != null && descripcion.trim().isNotEmpty) ? descripcion.trim() : null,
    );

    if (indice >= 0) {
      _eventos[indice] = actualizado;
    }

    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _eventos.removeWhere((e) => e.id == id);
  }

  /// Las dos validaciones del servidor, con los mismos topes.
  void _validar(String nombre, String fecha) {
    if (nombre.trim().length > Evento.maximoNombre) {
      nombresLargos.add(nombre);
      throw const ValidationException('El nombre del evento no puede pasar de 150 caracteres.');
    }

    // **La fecha en blanco daba un 500** hasta que la entidad lleva `isDate`:
    // `allowNull` no coge `""`, MySQL lo convertía en "Invalid date".
    final limpia = fecha.trim();
    if (limpia.isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(limpia)) {
      fechasRechazadas.add(fecha);
      throw const ValidationException('La fecha no es válida. Se escribe como AAAA-MM-DD.');
    }
  }

  int _siguienteId() {
    if (_eventos.isEmpty) {
      return 1;
    }
    return _eventos.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Minúsculas y sin tildes, como hace MySQL al comparar.
  static String _sinTildes(String texto) {
    const mapa = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };

    final salida = StringBuffer();
    for (final caracter in texto.toLowerCase().split('')) {
      salida.write(mapa[caracter] ?? caracter);
    }

    return salida.toString();
  }
}

/// Evento de ejemplo para las pruebas.
Evento eventoDePrueba({
  int id = 1,
  String nombre = 'Reunion de ruta del Norte',
  String fecha = '2026-10-20',
  String? lugar = 'Sala de reuniones',
  String? descripcion = 'Repaso de la ruta de octubre',
  int plantaId = 1,
}) {
  return Evento(
    id: id,
    plantaId: plantaId,
    nombre: nombre,
    fecha: fecha,
    lugar: lugar,
    descripcion: descripcion,
  );
}