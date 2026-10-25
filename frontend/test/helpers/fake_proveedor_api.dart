import 'package:dio/dio.dart';
import 'package:milkdata_app/features/proveedores/data/proveedor_api.dart';
import 'package:milkdata_app/features/proveedores/domain/proveedor.dart';

/// `ProveedorApi` de mentira: filtra, pagina y guarda en memoria, sin tocar la
/// red.
class FakeProveedorApi extends ProveedorApi {
  FakeProveedorApi({List<Proveedor>? proveedores})
      : _proveedores = proveedores ?? <Proveedor>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Proveedor> _proveedores;

  /// Lo que se pidió en la última llamada a `listar`, para comprobar que los
  /// filtros viajan y no se filtran en la pantalla.
  ({int pagina, int limite, String? busqueda, bool? activo, int? zonaId})? ultimaConsulta;

  /// El cuerpo crudo del último alta o edición.
  ///
  /// Se guarda **el mapa entero**, no un modelo: lo que hay que comprobar aquí
  /// es si la clave `rutaId` aparece o no, y un modelo construido con campos
  /// nombrados no podría responder a esa pregunta —para él, la clave no existe
  /// nunca, vaya o no vaya.
  Map<String, dynamic>? ultimoCuerpo;

  final List<int> eliminados = [];
  final List<int> creados = [];
  final List<int> editados = [];

  @override
  Future<ProveedoresPagina> listar({
    int pagina = 1,
    int limite = 10,
    String? busqueda,
    bool? activo,
    int? zonaId,
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
      zonaId: zonaId,
    );

    var filtrados = _proveedores;

    if (busqueda != null && busqueda.isNotEmpty) {
      final texto = busqueda.toLowerCase();
      filtrados = filtrados
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(texto) ||
                p.apellido.toLowerCase().contains(texto) ||
                p.dni.contains(texto) ||
                p.codigo.toLowerCase().contains(texto),
          )
          .toList();
    }
    if (activo != null) {
      filtrados = filtrados.where((p) => p.activo == activo).toList();
    }
    if (zonaId != null) {
      filtrados = filtrados.where((p) => p.zonaId == zonaId).toList();
    }

    final totalPaginas = limite > 0 ? (filtrados.length / limite).ceil() : 0;
    final desde = (pagina - 1) * limite;

    return ProveedoresPagina(
      proveedores: filtrados.skip(desde).take(limite).toList(),
      pagina: pagina,
      totalPaginas: totalPaginas,
      total: filtrados.length,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    );
  }

  @override
  Future<Proveedor> ver(int id) async {
    return _proveedores.firstWhere(
      (p) => p.id == id,
      orElse: () => Proveedor(
        id: id,
        nombre: 'Desconocido',
        apellido: '',
        dni: '',
        codigo: '',
        activo: true,
      ),
    );
  }

  @override
  Future<Proveedor> crear({
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    ultimoCuerpo = {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'telefono': telefono ?? '',
      'direccion': direccion ?? '',
      'zonaId': zonaId,
      'activo': activo,
    };

    // La API real rechaza el alta si aparece `rutaId`, aunque valga `null`. El
    // doble hace lo mismo, para que una prueba que lo comprobara midiera el
    // comportamiento del servidor y no el de un doble más permisivo.
    if (ultimoCuerpo!.containsKey('rutaId')) {
      throw Exception('La ruta no se cambia con este endpoint.');
    }

    final nuevo = Proveedor(
      id: _siguienteId(),
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      // El código lo pone el servidor, no la app: `proveedor.codigo` es único y
      // la app solo ve una página de la lista. El doble lo genera igual que
      // `ProveedorService._siguienteCodigo`, para que una prueba que mirara el
      // código estuviera mirando el mismo algoritmo y no uno inventado aquí.
      codigo: _siguienteCodigo(),
      telefono: telefono,
      direccion: direccion,
      zonaId: zonaId,
      activo: activo,
    );

    _proveedores.insert(0, nuevo);
    creados.add(nuevo.id);

    return nuevo;
  }

  /// El siguiente `PROV-NNN` libre, con el mismo formato que el servidor.
  String _siguienteCodigo() {
    final numeros = _proveedores
        .map((p) => RegExp(r'^PROV-(\d+)$').firstMatch(p.codigo))
        .whereType<RegExpMatch>()
        .map((m) => int.parse(m.group(1)!))
        .toList();

    final mayor = numeros.isEmpty ? 0 : numeros.reduce((a, b) => a > b ? a : b);

    return 'PROV-${(mayor + 1).toString().padLeft(3, '0')}';
  }

  @override
  Future<Proveedor> editar(
    int id, {
    required String nombre,
    required String apellido,
    required String dni,
    String? telefono,
    String? direccion,
    int? zonaId,
    required bool activo,
  }) async {
    ultimoCuerpo = {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'telefono': telefono ?? '',
      'direccion': direccion ?? '',
      'zonaId': zonaId,
      'activo': activo,
    };

    if (ultimoCuerpo!.containsKey('rutaId')) {
      throw Exception('La ruta no se cambia con este endpoint.');
    }

    editados.add(id);

    final indice = _proveedores.indexWhere((p) => p.id == id);
    final anterior = indice >= 0 ? _proveedores[indice] : null;

    // Se reemplaza entero, sin `copyWith`: en la API `PUT` pone lo que venga, y
    // un `null` desasigna. Si este doble mezclara, se estaría tapando justo el
    // comportamiento que la prueba quiere ver.
    //
    // El código se conserva: la app no lo manda, así que el servidor lo deja
    // como estaba. Si este doble lo regenerara, una prueba vería que editar un
    // proveedor le cambia el código, que es justo lo que se quiere evitar.
    final actualizado = Proveedor(
      id: id,
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      codigo: anterior?.codigo ?? _siguienteCodigo(),
      telefono: telefono,
      direccion: direccion,
      zonaId: zonaId,
      activo: activo,
    );

    if (indice >= 0) {
      _proveedores[indice] = actualizado;
    }

    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _proveedores.removeWhere((p) => p.id == id);
  }

  int _siguienteId() {
    if (_proveedores.isEmpty) {
      return 1;
    }
    return _proveedores.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Proveedor de ejemplo para las pruebas.
Proveedor proveedorDePrueba({
  int id = 1,
  String nombre = 'Juan',
  String apellido = 'Pérez',
  String dni = '70000001',
  String codigo = 'PROV-001',
  String? telefono,
  String? direccion,
  int? zonaId = 1,
  bool activo = true,
  String? imagen,
}) {
  return Proveedor(
    id: id,
    nombre: nombre,
    apellido: apellido,
    dni: dni,
    codigo: codigo,
    telefono: telefono,
    direccion: direccion,
    zonaId: zonaId,
    activo: activo,
    imagen: imagen,
  );
}
