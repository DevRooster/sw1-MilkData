import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../uploads/domain/imagen.dart';
import '../../uploads/presentation/selector_imagen.dart';
import '../../auth/presentation/providers/auth_controller.dart';

/// Pantalla de perfil: los datos de quien está conectado y su foto.
///
/// Es solo eso, a propósito. Registrar usuarios y cambiar de planta viven en
/// otra pestaña porque son cosas distintas: el perfil es de uno mismo, lo otro
/// es administrar la planta.
class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(authControllerProvider);

    if (estado is! Autenticado) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFF2F2F7),
        navigationBar: CupertinoNavigationBar(middle: Text('Perfil'), border: null),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final usuario = estado.usuario;
    final plantaActual = _plantaDe(estado);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Mi perfil'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaciado.md,
            Espaciado.md,
            Espaciado.md,
            Espaciado.xl,
          ),
          children: [
            AppCard(
              child: Row(
                children: [
                  _Foto(ruta: usuario.imagen, nombre: usuario.nombre),
                  const SizedBox(width: Espaciado.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombreCompleto,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Espaciado.xs),
                        Text(
                          usuario.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: Espaciado.sm),
                        AppPill(
                          texto: usuario.rol.nombre,
                          color: usuario.rol.nombre == 'superadmin'
                              ? const Color(0xFFAF52DE)
                              : AppTheme.verde,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Espaciado.md),

            // El selector de imágenes sube a la galería del usuario: puede tener
            // varias fotos y elegir cuál es la que sale en las listas.
            AppCard(
              child: SelectorImagen(
                etiqueta: 'MIS FOTOS',
                recurso: RecursoImagen.usuario,
                id: usuario.id,
                rutaActual: usuario.imagen,
              ),
            ),

            const SizedBox(height: Espaciado.md),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle('Sesión'),
                  const SizedBox(height: Espaciado.sm),
                  _Fila(
                    etiqueta: 'Rol',
                    valor: usuario.rol.nombre,
                  ),
                  _Fila(
                    etiqueta: 'Planta actual',
                    valor: plantaActual ?? 'Desconocida',
                  ),
                  _Fila(
                    etiqueta: 'Alcance',
                    valor: estado.plantas?.alcance.etiqueta ??
                        (usuario.rol.nombre == 'superadmin'
                            ? 'Todas las plantas'
                            : 'Solo tu planta'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Espaciado.lg),

            // El cierre llama a `POST /auth/logout` y después borra el token del
            // dispositivo: el servidor no puede revocarlo.
            AppButton(
              texto: 'Cerrar sesión',
              tono: AppButton.tonoSecundario,
              icon: CupertinoIcons.right_chevron,
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }

  /// Nombre de la planta del token, que es la que vale: la de origen del
  /// usuario puede ser otra distinta.
  static String? _plantaDe(Autenticado estado) {
    final plantas = estado.plantas;
    if (plantas == null) {
      return null;
    }

    for (final planta in plantas.plantas) {
      if (planta.id == estado.usuario.plantaId) {
        return '${planta.nombre} (${planta.codigo})';
      }
    }

    return null;
  }
}

/// Fila de etiqueta y valor.
class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Foto de perfil, o la inicial si no hay ninguna.
class _Foto extends StatelessWidget {
  const _Foto({required this.ruta, required this.nombre});

  final String? ruta;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);

    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey5,
        shape: BoxShape.circle,
      ),
      child: url.isEmpty
          ? _inicial()
          : Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              // Si el archivo ya no está en el servidor, la inicial es mejor que
              // un error rojo.
              errorBuilder: (context, error, stack) => _inicial(),
            ),
    );
  }

  Widget _inicial() => Center(
        child: Text(
          nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );
}