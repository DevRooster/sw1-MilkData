import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/imagen.dart';
import 'providers/imagen_controller.dart';

/// Foto de un registro, con opciones para cambiarla o quitarla.
///
/// Sirve igual para el perfil de un usuario, la foto de un producto, la de un
/// proveedor o el logo de una planta: el recurso y el id son los únicos datos
/// que cambian.
class SelectorImagen extends ConsumerWidget {
  const SelectorImagen({
    super.key,
    required this.recurso,
    required this.id,
    required this.rutaActual,
    this.esAvatar = false,
    this.etiqueta,
  });

  final RecursoImagen recurso;
  final int id;

  /// Ruta que tiene ahora el registro, o `null` si no tiene imagen.
  final String? rutaActual;

  /// `true` lo dibuja redondo, para fotos de perfil.
  final bool esAvatar;

  final String? etiqueta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(imagenControllerProvider);
    final tieneImagen = rutaActual != null && rutaActual!.isNotEmpty;
    final tieneArchivoLocal =
        estado.estado is ImagenOcupada && (estado.estado as ImagenOcupada).queHace == 'Subiendo…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (etiqueta != null) ...[
          Text(
            etiqueta!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: Espaciado.sm),
        ],

        Row(
          children: [
            _Vista(ruta: rutaActual, esAvatar: esAvatar, cargando: tieneArchivoLocal),

            const SizedBox(width: Espaciado.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppMiniBoton(
                          texto: 'Cambiar',
                          icono: CupertinoIcons.photo_on_rectangle,
                          cargando: estado.ocupada,
                          onPressed: estado.ocupada
                              ? null
                              : () => _elegir(context, ref, desdeCamara: false),
                        ),
                      ),
                      const SizedBox(width: Espaciado.sm),
                      Expanded(
                        child: AppMiniBoton(
                          texto: 'Cámara',
                          icono: CupertinoIcons.camera,
                          onPressed: estado.ocupada
                              ? null
                              : () => _elegir(context, ref, desdeCamara: true),
                        ),
                      ),
                    ],
                  ),

                  if (tieneImagen) ...[
                    const SizedBox(height: Espaciado.sm),
                    AppMiniBoton(
                      texto: 'Quitar',
                      icono: CupertinoIcons.trash,
                      tono: CupertinoColors.systemRed,
                      onPressed: estado.ocupada
                          ? null
                          : () => ref.read(imagenControllerProvider.notifier).borrar(
                                recurso: recurso,
                                id: id,
                                ruta: rutaActual!,
                              ),
                    ),
                  ],

                  if (estado.estado is ImagenConError) ...[
                    const SizedBox(height: Espaciado.sm),
                    Text(
                      (estado.estado as ImagenConError).mensaje,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemRed,
                        height: 1.3,
                      ),
                    ),
                  ],

                  if (tieneArchivoLocal) ...[
                    const SizedBox(height: Espaciado.sm),
                    const Text(
                      'Subiendo la imagen…',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Abre la hoja con las dos opciones, para no llenar la pantalla de botones.
  void _elegir(BuildContext context, WidgetRef ref, {required bool desdeCamara}) {
    final controller = ref.read(imagenControllerProvider.notifier);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (contexto) => CupertinoActionSheet(
        title: const Text('Imagen'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(contexto).pop();
              controller.cambiarDesdeCamara(recurso: recurso, id: id);
            },
            child: const Text('Tomar foto'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(contexto).pop();
              controller.cambiarDesdeGaleria(recurso: recurso, id: id);
            },
            child: const Text('Elegir de la galería'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }
}

/// La imagen o un marcador de "sin imagen".
class _Vista extends StatelessWidget {
  const _Vista({required this.ruta, required this.esAvatar, required this.cargando});

  final String? ruta;
  final bool esAvatar;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);
    final lado = esAvatar ? 72.0 : 88.0;

    final contenido = url.isEmpty
        ? const Icon(
            CupertinoIcons.photo,
            size: 26,
            color: CupertinoColors.systemGrey,
          )
        : Image.network(
            url,
            width: lado,
            height: lado,
            fit: BoxFit.cover,
            // Una imagen rota no debe romper la pantalla: se ve el marcador y ya
            // está. Puede pasar si el archivo se borró desde el servidor.
            errorBuilder: (context, error, stack) => const Icon(
              CupertinoIcons.photo,
              size: 26,
              color: CupertinoColors.systemGrey,
            ),
            loadingBuilder: (context, child, progreso) {
              if (progreso == null) {
                return child;
              }
              return const CupertinoActivityIndicator();
            },
          );

    return Container(
      width: lado,
      height: lado,
      // `Clip.antiAlias` con `BoxShape.circle` es lo que recorta en círculo:
      // no hay un `Clip.oval`.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        shape: esAvatar ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: esAvatar ? null : BorderRadius.circular(Espaciado.radio),
        border: Border.all(
          color: cargando ? AppTheme.verde : CupertinoColors.systemGrey4,
          width: cargando ? 2 : 1,
        ),
      ),
      child: contenido,
    );
  }
}

/// Botón compacto para las acciones de la imagen.
class AppMiniBoton extends StatelessWidget {
  const AppMiniBoton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.tono = CupertinoColors.systemGrey,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;
  final Color tono;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;

    return SizedBox(
      height: 38,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(Espaciado.sm),
        color: tono.withValues(alpha: activo ? 0.14 : 0.07),
        onPressed: activo ? onPressed : null,
        child: cargando
            ? const CupertinoActivityIndicator(radius: 8)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 15, color: tono),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    texto,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tono),
                  ),
                ],
              ),
      ),
    );
  }
}