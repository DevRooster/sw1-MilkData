import 'package:flutter/cupertino.dart';

import '../../core/theme/app_theme.dart';

/// Píldora de color, como las etiquetas de iOS.
///
/// El color lo elige quien la usa: el rol de la persona y no el estado de nada.
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.texto, required this.color});

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

/// Título de grupo dentro de una tarjeta.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.titulo, {super.key});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }
}

/// Aviso de una línea: verde si salió bien, rojo si no.
class AppNotice extends StatelessWidget {
  const AppNotice({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.sm),
      child: Text(texto, style: TextStyle(fontSize: 13, color: color, height: 1.3)),
    );
  }
}

/// Estado vacío: "aquí no hay nada todavía".
class AppEmpty extends StatelessWidget {
  const AppEmpty({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.lg),
      child: Center(
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: CupertinoColors.tertiaryLabel,
          ),
        ),
      ),
    );
  }
}