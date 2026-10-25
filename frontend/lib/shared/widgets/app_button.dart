import 'package:flutter/cupertino.dart';

import '../../core/theme/app_theme.dart';

/// Botón principal a pantalla completa, al estilo de iOS.
///
/// Se usa el ancho completo y el fondo con opacidad cuando está deshabilitado,
/// que es el comportamiento que la gente espera de un botón de acción principal.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.deshabilitado = false,
    this.icon,
    this.tono = AppButton.tonoPrimario,
  });

  /// Verde de marca: la acción principal de la pantalla.
  static const Color tonoPrimario = AppTheme.verde;

  /// Gris: acciones secundarias o destructivas, para que no compitan con la
  /// principal. Cerrar sesión va con este tono, no con el verde.
  static const Color tonoSecundario = Color(0xFF8E8E93);

  final String texto;

  /// `null` deshabilita el botón.
  final VoidCallback? onPressed;

  /// Muestra el indicador de progreso y bloquea el toque.
  final bool cargando;

  /// Botón presente pero sin tocar: se ve apagado sin perder su lugar en la
  /// pantalla, que es distinto de esconderlo.
  final bool deshabilitado;

  final IconData? icon;

  final Color tono;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando && !deshabilitado;

    return SizedBox(
      width: double.infinity,
      height: Espaciado.altoCampo,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(Espaciado.radio),
        color: tono,
        // Con opacidad al estar deshabilitado, en vez de un color distinto.
        disabledColor: tono.withValues(alpha: 0.4),
        onPressed: activo ? onPressed : null,
        child: cargando
            ? CupertinoActivityIndicator(
                color: CupertinoColors.white,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: CupertinoColors.white),
                    const SizedBox(width: Espaciado.sm),
                  ],
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tarjeta con fondo blanco y esquinas redondeadas, como los grupos de iOS.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(Espaciado.md),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(Espaciado.radio),
      ),
      child: child,
    );
  }
}

/// Aviso inline para errores: el tipo de error decide el color y el icono, no
/// la pantalla que lo muestra.
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Espaciado.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(Espaciado.radio),
        border: Border.all(color: const Color(0xFFF5C6C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 18,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(width: Espaciado.sm),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 14, color: CupertinoColors.systemRed),
            ),
          ),
        ],
      ),
    );
  }
}