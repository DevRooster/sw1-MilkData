/// Límites que impone la API a las imágenes.
///
/// Los devuelve `GET /uploads/api`. Se piden al servidor en lugar de fijarlos en
/// la app: si un día el backend cambia el tamaño máximo, la app se entera sola
/// en vez de fallar al subir.
class ConfigImagenes {
  const ConfigImagenes({
    required this.limiteBytes,
    required this.tipos,
    required this.recursos,
    required this.patron,
  });

  final int limiteBytes;
  final List<String> tipos;

  /// Recursos a los que se puede adjuntar una imagen.
  final List<String> recursos;

  /// Cómo nombra la API los archivos, para mostrarlo como información.
  final String patron;

  factory ConfigImagenes.fromJson(Map<String, dynamic> json) => ConfigImagenes(
        limiteBytes: json['limiteBytes'] as int? ?? 5242880,
        tipos: (json['tipos'] as List<dynamic>? ?? const <dynamic>[]).cast<String>(),
        recursos:
            (json['recursos'] as List<dynamic>? ?? const <dynamic>[]).cast<String>(),
        patron: json['patron'] as String? ?? '',
      );

  /// Límite en megabytes, para poder escribir "5 MB" en vez de "5242880".
  double get limiteMegaBytes => limiteBytes / (1024 * 1024);

  /// Si el tipo del archivo está entre los que acepta la API.
  bool admite(String? mimeType) => mimeType != null && tipos.contains(mimeType);
}

/// A qué recurso se adjunta una imagen.
///
/// Los nombres son los que espera la API en el campo `recurso`.
enum RecursoImagen {
  usuario('usuario'),
  producto('producto'),
  proveedor('proveedor'),
  planta('planta');

  const RecursoImagen(this.valor);

  /// Texto exacto que manda la API.
  final String valor;
}

/// Resultado de subir una imagen.
///
/// Trae la ruta con la que quedó guardada, que es lo que se guarda en la columna
/// `imagen` del registro.
class ImagenSubida {
  const ImagenSubida({
    required this.ruta,
    required this.recurso,
    this.bytes = 0,
  });

  /// Ruta relativa, por ejemplo `/uploads/1/usuario/abc.png`.
  final String ruta;

  final RecursoImagen recurso;
  final int bytes;
}