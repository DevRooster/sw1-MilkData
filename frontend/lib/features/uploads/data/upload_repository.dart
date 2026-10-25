import '../../../core/error/app_exception.dart';
import '../domain/imagen.dart';
import 'upload_api.dart';

/// Coordina la subida y el borrado de imágenes.
///
/// La API ya deja el registro actualizado cuando se le pasa `id`, así que aquí
/// no se vuelve a escribir en la base: una subida es una sola operación.
class UploadRepository {
  UploadRepository({required UploadApi api}) : _api = api;

  // ignore: prefer_initializing_formals
  final UploadApi _api;

  /// Límites que impone el servidor.
  Future<ConfigImagenes> configuracion() => _api.configuracion();

  /// Abre la galería. Devuelve `null` si la persona se arrepiente.
  Future<ImagenElegida?> elegirDesdeGaleria() => _api.elegirArchivo();

  /// Abre la cámara. Devuelve `null` si no toma ninguna foto.
  Future<ImagenElegida?> elegirDesdeCamara() =>
      _api.elegirArchivo(desdeCamara: true);

  /// Sube la imagen y la adjunta al registro indicado.
  ///
  /// Comprueba el tamaño y el tipo antes de subir: sin `id` la operación es
  /// atómica y no deja archivos huérfanos, pero el archivo ya habría viajado
  /// entero por la red cuando el servidor lo rechace.
  Future<ImagenSubida> subirYAdjuntar({
    required ImagenElegida archivo,
    required RecursoImagen recurso,
    required ConfigImagenes config,
    int? id,
  }) async {
    if (archivo.bytes.length > config.limiteBytes) {
      throw ValidationException(
        'La imagen pesa ${(archivo.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB '
        'y el máximo es ${config.limiteMegaBytes.toStringAsFixed(0)} MB.',
      );
    }

    if (!config.admite(archivo.mimeType)) {
      throw ValidationException(
        'Ese tipo de imagen no se acepta. Vale: ${config.tipos.join(', ')}.',
      );
    }

    return _api.subir(
      bytes: archivo.bytes,
      nombreArchivo: archivo.nombre,
      mimeType: archivo.mimeType,
      recurso: recurso,
      id: id,
    );
  }

  /// Borra la imagen y la desvincula del registro.
  Future<void> borrarYDesvincular({
    required String ruta,
    required RecursoImagen recurso,
    required int id,
  }) {
    return _api.borrar(ruta: ruta, recurso: recurso, id: id);
  }
}