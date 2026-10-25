import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/upload_api.dart';
import '../../data/upload_repository.dart';
import '../../domain/imagen.dart';

final uploadApiProvider = Provider<UploadApi>((ref) {
  return UploadApi(ref.watch(apiClientProvider));
});

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(api: ref.watch(uploadApiProvider));
});

/// Estado de una operación sobre imágenes.
///
/// Se modela con una clase vacía para el estado inicial en vez de con `null`,
/// porque así los tipos no admiten un cuarto caso y no hace falta `!` al leer.
sealed class ImagenEstado {
  const ImagenEstado();
}

/// Nada en curso.
class ImagenQuieta extends ImagenEstado {
  const ImagenQuieta();
}

/// Leyendo el archivo o subiéndolo.
class ImagenOcupada extends ImagenEstado {
  const ImagenOcupada(this.queHace);

  /// Qué está pasando, para el texto del botón.
  final String queHace;
}

/// La operación terminó bien.
class ImagenLista extends ImagenEstado {
  const ImagenLista(this.ruta);

  final String ruta;
}

/// La operación falló.
class ImagenConError extends ImagenEstado {
  const ImagenConError(this.mensaje);

  final String mensaje;
}

class ImagenState {
  const ImagenState({
    this.estado = const ImagenQuieta(),
    this.config,
  });

  final ImagenEstado estado;

  /// Límites del servidor. Se piden una vez y se reutilizan.
  final ConfigImagenes? config;

  bool get ocupada => estado is ImagenOcupada;

  ImagenState copyWith({ImagenEstado? estado, ConfigImagenes? config}) {
    return ImagenState(
      estado: estado ?? this.estado,
      config: config ?? this.config,
    );
  }
}

/// Sube, cambia y borra imágenes de los registros.
///
/// Es el único punto donde se toca `imagen`, de modo que cualquier recurso
/// (usuario, producto, proveedor, planta) se comporte igual sin repetir lógica
/// en cada pantalla.
class ImagenController extends Notifier<ImagenState> {
  @override
  ImagenState build() => const ImagenState();

  UploadRepository get _repo => ref.read(uploadRepositoryProvider);

  /// Pide los límites al servidor la primera vez.
  ///
  /// Se guarda en el estado porque son los mismos para toda la app: volver a
  /// pedirlos por cada subida sería una ida y vuelta por cada foto.
  Future<ConfigImagenes> _config() async {
    final guardada = state.config;
    if (guardada != null) {
      return guardada;
    }

    final config = await _repo.configuracion();
    state = state.copyWith(config: config);
    return config;
  }

  /// Elige una imagen de la galería y la sube.
  Future<void> cambiarDesdeGaleria({
    required RecursoImagen recurso,
    required int id,
  }) =>
      _cambiar(recurso: recurso, id: id, desdeCamara: false);

  /// Toma una foto con la cámara y la sube.
  Future<void> cambiarDesdeCamara({
    required RecursoImagen recurso,
    required int id,
  }) =>
      _cambiar(recurso: recurso, id: id, desdeCamara: true);

  Future<void> _cambiar({
    required RecursoImagen recurso,
    required int id,
    required bool desdeCamara,
  }) async {
    state = state.copyWith(estado: ImagenOcupada('Abriendo…'));

    try {
      final config = await _config();

      final archivo = desdeCamara
          ? await _repo.elegirDesdeCamara()
          : await _repo.elegirDesdeGaleria();

      // `null` significa que la persona cerró la galería sin elegir nada. No es
      // un error, así que se sale sin tocar el estado de error.
      if (archivo == null) {
        state = state.copyWith(estado: const ImagenQuieta());
        return;
      }

      state = state.copyWith(estado: const ImagenOcupada('Subiendo…'));

      final subida = await _repo.subirYAdjuntar(
        archivo: archivo,
        recurso: recurso,
        config: config,
        id: id,
      );

      // El backend ya actualizó la columna del registro, así que aquí solo hace
      // falta reflejarlo en la sesión para que la cabecera no quede mostrando la
      // foto anterior.
      if (recurso == RecursoImagen.usuario) {
        await _refrescarUsuarioEnSesion();
      }

      state = state.copyWith(estado: ImagenLista(subida.ruta));
    } on AppException catch (error) {
      state = state.copyWith(estado: ImagenConError(error.message));
    } catch (_) {
      state = state.copyWith(
        estado: const ImagenConError('No se pudo subir la imagen.'),
      );
    }
  }

  /// Quita la imagen del registro y borra el archivo.
  Future<void> borrar({
    required RecursoImagen recurso,
    required int id,
    required String ruta,
  }) async {
    state = state.copyWith(estado: const ImagenOcupada('Borrando…'));

    try {
      await _repo.borrarYDesvincular(ruta: ruta, recurso: recurso, id: id);

      if (recurso == RecursoImagen.usuario) {
        await _refrescarUsuarioEnSesion();
      }

      state = state.copyWith(estado: const ImagenLista(''));
    } on AppException catch (error) {
      state = state.copyWith(estado: ImagenConError(error.message));
    } catch (_) {
      state = state.copyWith(
        estado: const ImagenConError('No se pudo borrar la imagen.'),
      );
    }
  }

  /// Vuelve a pedir el perfil para que la sesión tenga la imagen nueva.
  Future<void> _refrescarUsuarioEnSesion() {
    return ref.read(authControllerProvider.notifier).recargarPerfil();
  }

  /// Limpia el mensaje de error, para que desaparezca al reintentar.
  void limpiar() {
    if (state.estado is ImagenConError || state.estado is ImagenLista) {
      state = ImagenState(config: state.config);
    }
  }
}

final imagenControllerProvider = NotifierProvider<ImagenController, ImagenState>(
  ImagenController.new,
);