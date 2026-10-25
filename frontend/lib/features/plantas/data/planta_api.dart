import 'package:dio/dio.dart';

import '../../../core/error/error_mapper.dart';
import '../../auth/domain/planta.dart';

/// Peticiones de `/plantas`.
///
/// Reutiliza la clase `Planta` de autenticación y no tiene una propia: el
/// servidor devuelve los mismos campos en `/plantas` y en `/auth/plantas`, y dos
/// clases para lo mismo divergen en cuanto uno de los dos endpoints añade un
/// campo.
///
/// **El módulo es de solo lectura para el admin y de escritura para el
/// superadmin**, no porque lo imponga la app sino porque lo impone el servidor:
/// el admin tiene `plantas: ['read']` y el superadmin `['read', 'write']`. Por eso
/// el botón de alta se esconde según el permiso.
class PlantaApi {
  PlantaApi(this._dio);

  final Dio _dio;

  /// `GET /plantas`
  Future<List<Planta>> listar({int pagina = 1, int limite = 50}) async {
    final cuerpo = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/plantas',
        queryParameters: {'pagina': pagina, 'limite': limite},
      ),
    );

    // **`_datos(cuerpo)` y no `cuerpo` a secas.** `_enviar` devuelve el cuerpo
    // entero, `{ success, data }`, y la lista vive un nivel más abajo. Leer
    // `cuerpo['items']` da `null` y devuelve una lista vacía **sin decir nada**:
    // la pantalla enseña "no hay ninguna planta" con un 200 delante.
    //
    // Pasó aquí, y lo pilló el usuario en el móvil antes que ninguna prueba,
    // porque `FakePlantaApi` sobrescribe este método entero y el atajo se salta
    // justo la línea que estaba mal. Ver `planta_api_test.dart`, que sí ejercita
    // esta clase de verdad contra la forma real de la respuesta.
    final datos = _datos(cuerpo);

    return (datos['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Planta.fromJson)
        .toList();
  }

  /// `GET /plantas/{id}`
  Future<Planta> ver(int id) async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/plantas/$id'));
    final datos = _datos(cuerpo);

    return Planta.fromJson((datos['item'] as Map<String, dynamic>?) ?? datos);
  }

  /// `POST /plantas`
  ///
  /// **`nombre` y `codigo` son obligatorios** y `codigo` es único: es el que
  /// aparece en las etiquetas de las pantallas —`HUA`, `PRB`— y el que se escribe
  /// para entrar por código. Repetirlo da 409.
  Future<Planta> crear({
    required String nombre,
    required String codigo,
    String? direccion,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/plantas',
        data: _campos({'nombre': nombre, 'codigo': codigo, 'direccion': direccion}),
      ),
    );

    return Planta.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `PUT /plantas/{id}`
  Future<Planta> editar(
    int id, {
    required String nombre,
    required String codigo,
    String? direccion,
  }) async {
    final cuerpo = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/plantas/$id',
        data: _campos({'nombre': nombre, 'codigo': codigo, 'direccion': direccion}),
      ),
    );

    return Planta.fromJson(
      (_datos(cuerpo)['item'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// `DELETE /plantas/{id}`
  Future<void> eliminar(int id) async {
    await _enviar(() => _dio.delete<Map<String, dynamic>>('/plantas/$id'));
  }

  /// Quita las claves vacías.
  ///
  /// Importa con la dirección: mandarla en blanco **la borra**, que es justo lo
  /// que quiere quien edita una planta a la que le quita la dirección.
  Map<String, dynamic> _campos(Map<String, dynamic> campos) {
    final limpio = <String, dynamic>{};

    for (final entrada in campos.entries) {
      final valor = entrada.value;
      if (valor == null || (valor is String && valor.trim().isEmpty)) {
        continue;
      }
      limpio[entrada.key] = valor is String ? valor.trim() : valor;
    }

    return limpio;
  }

  Future<Map<String, dynamic>> _enviar(
    Future<Response<Map<String, dynamic>>> Function() llamada,
  ) async {
    try {
      final respuesta = await llamada();
      return respuesta.data ?? const <String, dynamic>{};
    } catch (error) {
      throw mapearError(error);
    }
  }

  Map<String, dynamic> _datos(Map<String, dynamic> cuerpo) {
    return (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }
}