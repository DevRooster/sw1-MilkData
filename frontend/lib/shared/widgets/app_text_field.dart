import 'package:flutter/cupertino.dart';

import '../../core/theme/app_theme.dart';

/// Campo de texto con la etiqueta arriba, al estilo de los formularios de iOS.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.placeholder,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String? placeholder;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Texto de ayuda o error bajo el campo.
  final String? errorText;

  /// Cuántas líneas caben. Por defecto una, que es lo que quiere casi todo
  /// campo: nombre, correo, precio.
  ///
  /// Se sube a más de uno para los campos de texto libre y largo, como la
  /// descripción de un producto. Antes no existía y no había forma de escribir
  /// más de una línea sin construirse un `CupertinoTextField` aparte, que
  /// además se saltaría la etiqueta y el borde rojo de error.
  final int maxLines;

  /// Cómo se capitaliza lo que se escribe.
  ///
  /// Por defecto, nada. Sirve para los campos que solo tienen un formato
  /// válido, como el código de una ruta, que es de mayúsculas y sin espacios:
  /// forzarlo en el teclado y en el `onChanged` hace que no haya dos formas
  /// guardables del mismo dato.
  final TextCapitalization textCapitalization;

  /// El campo se ve pero no se puede escribir.
  ///
  /// Para cuando el valor lo pone otra cosa y escribirlo a mano no tiene sentido:
  /// el nombre de un evento que ya se eligió en el desplegable de arriba, o un
  /// código que genera el servidor. **No se usa `enabled: false`** a propósito,
  /// porque un campo deshabilido en iOS se ve en gris y no avisa de por qué: quien
  /// intenta escribir y no puede no entiende nada.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final tieneError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: Espaciado.xs),
        CupertinoTextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          placeholder: placeholder,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          // Con una sola línea no se fija mínimo: `minLines` distinto de
          // `maxLines` hace que el campo crezca al escribir, y eso en un campo
          // de una línea descuadra la fila de filtros.
          minLines: maxLines > 1 ? 2 : null,
          prefix: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: Espaciado.md),
                  child: Icon(icon, size: 18, color: CupertinoColors.secondaryLabel),
                ),
          padding: const EdgeInsets.symmetric(
            horizontal: Espaciado.md,
            vertical: Espaciado.sm + 2,
          ),
          style: const TextStyle(fontSize: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(Espaciado.radio),
            // El borde se pone rojo solo cuando hay error, como en iOS.
            border: Border.all(
              color: tieneError ? CupertinoColors.systemRed : const Color(0xFFE5E5EA),
            ),
          ),
        ),
        if (tieneError) ...[
          const SizedBox(height: Espaciado.xs),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
          ),
        ],
      ],
    );
  }
}