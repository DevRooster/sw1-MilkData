import 'package:dio/dio.dart';

import '../../../core/error/error_mapper.dart';
import '../domain/reporte.dart';

/// Peticiones de `/reportes`.
///
/// Los cuatro endpoints son **de solo lectura** y devuelven la misma envoltura:
/// `{ name, items, plantaId }`. No hay alta, ni edición, ni borrado, y **tampoco
/// paginación**: un reporte resume, no lista.
class ReporteApi {
  ReporteApi(this._dio);

  final Dio _dio;

  /// `GET /reportes/contraste`
  ///
  /// Lo recogido en el campo contra lo que entró en la planta, por proveedor y
  /// día. Es el reporte que busca leche que no llegó a destino.
  Future<Reporte<FilaContraste>> contraste() async {
    return _enviar(
      '/reportes/contraste',
      FilaContraste.fromJson,
    );
  }

  /// `GET /reportes/calidad`
  ///
  /// Los promedios de toda la planta, en **una sola fila**.
  ///
  /// Con `muestras: 0` los siete promedios vienen a `null`. No es que la leche
  /// esté mal: es que nadie ha analizado nada, y la pantalla lo dice.
  Future<Reporte<FilaCalidad>> calidad() async {
    return _enviar(
      '/reportes/calidad',
      FilaCalidad.fromJson,
    );
  }

  /// `GET /reportes/calidad-proveedor`
  ///
  /// Los promedios **por proveedor**, y devuelve una lista vacía si no hay ningún
  /// control de calidad: a diferencia de [calidad], aquí no sale una fila con
  /// ceros.
  Future<Reporte<FilaCalidad>> calidadPorProveedor() async {
    return _enviar(
      '/reportes/calidad-proveedor',
      FilaCalidad.fromJson,
    );
  }

  /// `GET /reportes/calidad/proveedor/{id}`
  ///
  /// **Un proveedor que no existe devuelve una fila con `muestras: 0`, no un 404.**
  /// Medido contra la API con el proveedor 9999. La app lo comprueba contra la
  /// lista de proveedores antes de pedirlo, porque una fila con cero muestras
  /// de alguien que no existe parece un análisis vacío y no lo que es.
  Future<Reporte<FilaCalidad>> calidadDeProveedor(int proveedorId) async {
    return _enviar(
      '/reportes/calidad/proveedor/$proveedorId',
      FilaCalidad.fromJson,
    );
  }

  Future<Reporte<T>> _enviar<T>(
    String ruta,
    T Function(Map<String, dynamic>) fila,
  ) async {
    try {
      final respuesta = await _dio.get<Map<String, dynamic>>(ruta);
      final cuerpo = respuesta.data ?? const <String, dynamic>{};
      final datos = (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return Reporte<T>.fromJson(datos, fila);
    } catch (error) {
      throw mapearError(error);
    }
  }
}

/// Los cuatro reportes, para el selector de la pantalla.
///
/// Va como enumerado y no como texto suelto porque el selector necesita una
/// etiqueta y el controller necesita saber cuál pedir; con un solo tipo se
/// evita que se separen.
enum TipoReporte {
  contraste('Contraste'),
  calidad('Calidad general'),
  calidadPorProveedor('Calidad por proveedor');

  const TipoReporte(this.etiqueta);

  /// Lo que ve el usuario.
  final String etiqueta;

  /// Lo que el reporte cuenta, en una línea, y que va bajo el título.
  String get descripcion {
    switch (this) {
      case TipoReporte.contraste:
        return 'Lo recogido en el campo contra lo que entró en la planta.';
      case TipoReporte.calidad:
        return 'Los promedios de los análisis de toda la planta.';
      case TipoReporte.calidadPorProveedor:
        return 'Los promedios de cada proveedor, uno por fila.';
    }
  }
}