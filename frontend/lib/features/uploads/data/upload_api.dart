import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/imagen.dart';

/// Las tres peticiones de `/uploads/api`.
///
/// Igual que el resto de la capa de datos: solo habla con el servidor, no sabe
/// nada de Riverpod ni de las pantallas.
class UploadApi {
  UploadApi(this._dio, {ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final Dio _dio;

  // ignore: prefer_initializing_formals
  final ImagePicker _picker;

  /// `GET /uploads/api`
  ///
  /// Límites y recursos admitidos, para validar antes de subir y no gastar una
  /// subida entera en un archivo que el servidor va a rechazar.
  Future<ConfigImagenes> configuracion() async {
    final cuerpo = await _enviar(() => _dio.get<Map<String, dynamic>>('/uploads/api'));

    final datos = (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return ConfigImagenes.fromJson(datos);
  }

  /// Abre la galería o la cámara y devuelve los bytes del archivo elegido.
  ///
  /// Vive en la capa de datos y no en la pantalla porque elegir un archivo es
  /// una operación con efecto externo: una prueba no puede abrir la galería, y
  /// así se puede sustituir por un doble.
  Future<ImagenElegida?> elegirArchivo({bool desdeCamara = false}) async {
    try {
      final elegido = desdeCamara
          ? await _picker.pickImage(
              source: ImageSource.camera,
              // Limitar el tamaño en el dispositivo evita subir un archivo de
              // 8 MB que el servidor va a rechazar después de subirlo entero por
              // la red.
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 85,
            )
          : await _picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 85,
            );

      if (elegido == null) {
        return null;
      }

      return ImagenElegida(
        bytes: await elegido.readAsBytes(),
        nombre: elegido.name,
        mimeType: elegido.mimeType ?? 'image/jpeg',
      );
    } catch (error) {
      throw mapearError(error);
    }
  }

  /// `POST /uploads/api`
  ///
  /// multipart con `archivo`, `recurso` y, si se quiere adjuntar de una vez,
  /// `id`. Con `id` el backend guarda el archivo y actualiza la columna en la
  /// misma operación: si fallara la actualización, el archivo huérfano se
  /// borra, así que no quedan imágenes sin dueño.
  Future<ImagenSubida> subir({
    required Uint8List bytes,
    required String nombreArchivo,
    required String mimeType,
    required RecursoImagen recurso,
    int? id,
  }) async {
    final archivo = MultipartFile.fromBytes(bytes, filename: nombreArchivo);

    try {
      final respuesta = await _dio.post<Map<String, dynamic>>(
        '/uploads/api',
        data: FormData.fromMap({
          'archivo': archivo,
          'recurso': recurso.valor,
          if (id != null) 'id': '$id',
        }),
      );

      final cuerpo = respuesta.data ?? const <String, dynamic>{};
      final datos = (cuerpo['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      final ruta = datos['imagen'] as String?;
      if (ruta == null || ruta.isEmpty) {
        throw const ServerException('La API no devolvió la ruta de la imagen.');
      }

      return ImagenSubida(
        ruta: ruta,
        recurso: recurso,
        bytes: datos['bytes'] as int? ?? bytes.length,
      );
    } catch (error) {
      throw mapearError(error);
    }
  }

  /// `DELETE /uploads/api`
  ///
  /// Con `recurso` e `id` también desvincula la imagen del registro. La API solo
  /// borra archivos que ella misma guardó: una URL externa puede apuntar a algo
  /// ajeno.
  Future<void> borrar({
    required String ruta,
    RecursoImagen? recurso,
    int? id,
  }) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/uploads/api',
        data: {
          'imagen': ruta,
          if (recurso != null) 'recurso': recurso.valor,
          if (id != null) 'id': '$id',
        },
      );
    } catch (error) {
      throw mapearError(error);
    }
  }

  /// Ejecuta la llamada y deja todo error como `AppException`.
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
}

/// Archivo que la persona eligió, ya leído a memoria.
///
/// Lleva los bytes porque la subida va como `multipart` dentro de un `FormData`
/// de Dio, no como una URL.
class ImagenElegida {
  const ImagenElegida({
    required this.bytes,
    required this.nombre,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String nombre;
  final String mimeType;
}