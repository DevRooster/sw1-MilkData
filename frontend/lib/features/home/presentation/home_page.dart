import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../auth/domain/planta.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/modulo.dart';

/// Inicio: la tarjeta de sesión y el lanzador de módulos.
///
/// Antes esta pantalla solo enseñaba quién estaba conectado. Ahora enseña además
/// los módulos, porque en una barra de pestañas aparte no caben once.
///
/// El lanzador se dibuja con `GET /auth/permisos` y no con el nombre del rol: la
/// lista sale de la misma matriz que aplica el servidor, así que un módulo que se
/// ve aquí es uno que la API va a dejar abrir.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(authControllerProvider);

    if (estado is! Autenticado) {
      // Solo se ve un instante al cambiar de estado; el `AuthGate` sustituye la
      // pantalla entera cuando la sesión se cierra.
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFF2F2F7),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final usuario = estado.usuario;
    final plantas = estado.plantas;
    final modulos = modulosPermitidos(ref.watch(permisosProvider));

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('MilkData'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaciado.md),
          children: [
            _TarjetaSesion(
              nombreCompleto: usuario.nombreCompleto,
              email: usuario.email,
              rol: usuario.rol.nombre,
              imagen: usuario.imagen,
            ),

            const SizedBox(height: Espaciado.sm),

            // El alcance se pide solo al entrar, así que mientras no llegue se
            // muestra lo que ya se sabe del rol en vez de un hueco vacío.
            //
            // **Es pulsable, y solo si hay algo que cambiar.** Un superadmin con
            // tres plantas puede entrar en cualquiera de las tres; un admin con
            // una sola no tiene a dónde ir, así que no se le pone un dedo encima
            // que no lleva a ninguna parte. La tarjeta estaba antes como texto
            // plano —`Todas las plantas / HUA`, sin `onTap` ni nada— y parecía
            // un rótulo cuando en realidad era el control de planta.
            _TarjetaAlcance(
              alcance: plantas?.alcance.etiqueta ?? _alcancePorRol(usuario.rol.nombre),
              detalle: plantas == null
                  ? 'Cargando…'
                  : plantas.plantas.map((p) => p.codigo).join(' · '),
              onTap: plantas != null && plantas.plantas.length > 1
                  ? () => _cambiarPlanta(context, ref, plantas)
                  : null,
            ),

            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('Módulos'),

            if (modulos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Espaciado.xl),
                child: AppEmpty(
                  texto: 'Tu rol todavía no tiene módulos asignados.',
                ),
              )
            else
              ...modulos.map((m) => _TarjetaModulo(modulo: m)),

            const SizedBox(height: Espaciado.lg),

            // El cierre de sesión llama a `POST /auth/logout` y después borra el
            // token del dispositivo: el servidor nunca puede revocarlo.
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

  /// Alcance deducido del rol, para no dejar la tarjeta a medias mientras llega
  /// la respuesta del servidor.
  static String _alcancePorRol(String rol) =>
      rol == 'superadmin' ? 'Todas las plantas' : 'Solo tu planta';

  /// Elige en qué planta se trabaja y recarga todo lo que depende del token.
  ///
  /// El cambio **no es un filtro de pantalla**: `POST /auth/planta` devuelve un
  /// token nuevo ligado a la planta elegida, y a partir de ahí el backend aísla
  /// cada consulta por esa planta. Por eso hay que recargar: una lista que ya
  /// está en memoria seguiría enseñando los datos de la planta anterior hasta que
  /// se vuelva a pedir.
  /// `ref` va como parámetro y no como propiedad porque `HomePage` es un
  /// `ConsumerWidget`: en un widget así el `ref` solo existe dentro de `build`, y
  /// un método de la clase no lo ve.
  Future<void> _cambiarPlanta(
    BuildContext contexto,
    WidgetRef ref,
    PlantasDisponibles plantas,
  ) async {
    final actual = ref.read(authControllerProvider);
    if (actual is! Autenticado) {
      return;
    }

    final elegida = await showCupertinoModalPopup<Planta>(
      context: contexto,
      builder: (hoja) => CupertinoActionSheet(
        title: const Text('¿En qué planta trabajas?'),
        // Sin esto, con nueve plantas hay que scrollar a ciegas por una hoja
        // que no dice cuántas hay ni cuál estás en.
        message: Text('${plantas.plantas.length} disponibles. Ahora: ${actual.usuario.plantaParaMostrar ?? 'sin planta'}'),
        actions: [
          for (final planta in plantas.plantas)
            CupertinoActionSheetAction(
              // La de ahora sale marcada y en gris: si se pulsa, no cambia nada y
              // parece un fallo.
              isDefaultAction: planta.id == actual.usuario.plantaId,
              onPressed: () => Navigator.of(hoja).pop(planta),
              child: Text(
                planta.id == actual.usuario.plantaId
                    ? '${planta.nombre} (${planta.codigo}) · ahora'
                    : '${planta.nombre} (${planta.codigo})',
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(hoja).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (elegida == null || elegida.id == actual.usuario.plantaId) {
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).cambiarPlanta(
          plantaId: elegida.id,
        );

    if (!ok) {
      return;
    }

    if (!contexto.mounted) {
      return;
    }

    // Aviso de que el cambio ha entrado. Sin él, la tarjeta cambia de texto y no
    // hay manera de saber si fue a propósito o si algo se cargó solo.
    await showCupertinoDialog<void>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('Planta cambiada'),
        content: Text('Ahora trabajas en ${elegida.nombre}.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Vale'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un módulo, con su icono y su resumen.
class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({required this.modulo});

  final Modulo modulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.sm),
      child: AppCard(
        // `HitTestBehavior.opaque` no es un detalle: sin él el `GestureDetector`
        // de la tarjeta solo recibe el toque justo encima del texto, y las zonas
        // en blanco de alrededor se quedan sin pulsar. Pasó con la lista de
        // plantas.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => modulo.destino()),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.verde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Espaciado.radio),
                ),
                child: Icon(modulo.icono, size: 21, color: AppTheme.verde),
              ),
              const SizedBox(width: Espaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modulo.titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modulo.resumen,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quién está conectado, con su rol.
class _TarjetaSesion extends StatelessWidget {
  const _TarjetaSesion({
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    this.imagen,
  });

  final String nombreCompleto;
  final String email;
  final String rol;
  final String? imagen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          _Avatar(ruta: imagen, nombre: nombreCompleto),
          const SizedBox(width: Espaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreCompleto,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Espaciado.xs),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: Espaciado.sm),
                _Pildora(
                  texto: rol,
                  color: rol == 'superadmin' ? const Color(0xFFAF52DE) : AppTheme.verde,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La planta o plantas sobre las que opera esta sesión.
class _TarjetaAlcance extends StatelessWidget {
  const _TarjetaAlcance({
    required this.alcance,
    required this.detalle,
    this.onTap,
  });

  final String alcance;
  final String detalle;

  /// Pulsar cambia de planta. `null` cuando no hay a dónde ir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pulsable = onTap != null;

    return GestureDetector(
      onTap: onTap,
      // `HitTestBehavior.opaque` no es un detalle: sin él el gesto solo llega
      // justo encima del texto y las zonas en blanco alrededor —que son casi
      // todas— se quedan sin pulsar. Pasa con tarjetas grandes de texto corto.
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.building_2_fill,
              size: 20,
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(width: Espaciado.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alcance, style: const TextStyle(fontSize: 15)),
                  Text(
                    detalle,
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                  ),
                ],
              ),
            ),
            // **La flecha solo aparece si la tarjeta hace algo.** Ponerla siempre
            // sería prometer una acción que no ocurre, que es como se veía esto:
            // una etiqueta que parecía un botón y no lo era.
            if (pulsable)
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
          ],
        ),
      ),
    );
  }
}

/// Foto de perfil, o la inicial si no hay ninguna.
///
/// Se muestra aquí y en la pestaña Perfil, así que vive en un widget y no se
/// duplica. La inicial evita una tarjeta vacía para quien aún no subió nada.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.ruta, required this.nombre});

  final String? ruta;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);

    return Container(
      width: 56,
      height: 56,
      // `Clip.antiAlias` con `BoxShape.circle` es lo que recorta en círculo: no
      // hay un `Clip.oval`.
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey5,
        shape: BoxShape.circle,
      ),
      child: url.isEmpty ? _inicial() : _foto(url),
    );
  }

  Widget _inicial() => Center(
        child: Text(
          inicial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );

  Widget _foto(String url) => Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        // Si el archivo ya no existe en el servidor, la inicial es mejor que un
        // error rojo en la cabecera.
        errorBuilder: (context, error, stack) => _inicial(),
      );

  /// Primera letra del nombre, en mayúscula.
  String get inicial => nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase();
}

/// Píldora de color, al estilo de las etiquetas de iOS.
class _Pildora extends StatelessWidget {
  const _Pildora({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espaciado.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}