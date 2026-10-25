import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/auth/domain/planta.dart';
import 'package:milkdata_app/features/plantas/data/planta_api.dart';

/// `PlantaApi` de mentira.
///
/// Reparte la regla del código duplicado, que el servidor rechaza con 409, y la
/// del nombre obligatorio. El doble no adivina: si el servidor acepta algo que el
/// doble rechaza, la prueba mide el doble, y al revés la pantalla dejaría pasar
/// lo que el servidor no acepta.
class FakePlantaApi extends PlantaApi {
  FakePlantaApi({List<Planta>? plantas})
      : _plantas = plantas ?? <Planta>[],
        super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<Planta> _plantas;

  final List<int> eliminados = <int>[];
  final List<int> creados = <int>[];
  final List<int> editados = <int>[];

  /// Los códigos que este doble ha rechazado por estar repetidos.
  final List<String> codigosRepetidos = <String>[];

  /// Los nombres vacíos que ha rechazado.
  final List<String> nombresVacios = <String>[];

  @override
  Future<List<Planta>> listar({int pagina = 1, int limite = 50}) async {
    return [..._plantas];
  }

  @override
  Future<Planta> ver(int id) async {
    return _plantas.firstWhere((p) => p.id == id, orElse: () => plantaDePrueba(id: id));
  }

  @override
  Future<Planta> crear({required String nombre, required String codigo, String? direccion}) async {
    _validar(nombre, codigo);

    final nueva = Planta(
      id: _siguienteId(),
      nombre: nombre,
      codigo: codigo,
      direccion: (direccion != null && direccion.trim().isNotEmpty) ? direccion.trim() : null,
    );

    _plantas.add(nueva);
    creados.add(nueva.id);

    return nueva;
  }

  @override
  Future<Planta> editar(
    int id, {
    required String nombre,
    required String codigo,
    String? direccion,
  }) async {
    _validar(nombre, codigo, propio: id);

    editados.add(id);

    final indice = _plantas.indexWhere((p) => p.id == id);

    final actualizada = Planta(
      id: id,
      nombre: nombre,
      codigo: codigo,
      direccion: (direccion != null && direccion.trim().isNotEmpty) ? direccion.trim() : null,
    );

    if (indice >= 0) {
      _plantas[indice] = actualizada;
    }

    return actualizada;
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados.add(id);
    _plantas.removeWhere((p) => p.id == id);
  }

  void _validar(String nombre, String codigo, {int? propio}) {
    if (nombre.trim().isEmpty) {
      nombresVacios.add(nombre);
      throw const ValidationException('Ponle nombre a la planta.');
    }

    // **El código es único** y es lo que sale en las etiquetas: tener `hua` y `HUA`
    // como dos plantas distintas sería un lío que nadie quiere. El servidor
    // responde 409 y aquí se reparte con una `ValidationException`, porque el
    // `mapearError` la traduce al mismo mensaje que vería la persona.
    final repetido = _plantas.any((p) => p.codigo == codigo && p.id != propio);

    if (repetido) {
      codigosRepetidos.add(codigo);
      throw const ValidationException('Ya hay una planta con ese código.');
    }
  }

  int _siguienteId() {
    if (_plantas.isEmpty) {
      return 1;
    }
    return _plantas.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Planta de ejemplo para las pruebas.
Planta plantaDePrueba({
  int id = 1,
  String nombre = 'Planta Ecológica Huata',
  String codigo = 'HUA',
  String? direccion = 'Distrito de Huata',
  bool activo = true,
}) {
  return Planta(id: id, nombre: nombre, codigo: codigo, direccion: direccion, activo: activo);
}