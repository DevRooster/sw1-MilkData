import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'providers/auth_controller.dart';

/// Pantalla de inicio de sesión.
///
/// Cupertino para que se parezca a una app de iPhone: `CupertinoPageScaffold`,
/// campos con etiqueta arriba y botón de ancho completo.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();

  /// Errores de validación local, por campo. Los del servidor van aparte, en el
  /// aviso de abajo, porque no van unidos a un campo concreto.
  String? _errorCorreo;
  String? _errorClave;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  /// Valida los campos y marca el primero que falle.
  bool _validar() {
    final correo = _correo.text.trim();
    final clave = _clave.text;

    final errorCorreo = correo.isEmpty
        ? 'Escribe tu correo.'
        : (!_formatoCorreoValido(correo) ? 'Ese correo no parece válido.' : null);
    final errorClave = clave.isEmpty ? 'Escribe tu contraseña.' : null;

    setState(() {
      _errorCorreo = errorCorreo;
      _errorClave = errorClave;
    });

    return errorCorreo == null && errorClave == null;
  }

  /// Validación deliberadamente simple: basta con un `@` y un punto después.
  static bool _formatoCorreoValido(String correo) {
    final partes = correo.split('@');
    return partes.length == 2 && partes[0].isNotEmpty && partes[1].contains('.');
  }

  Future<void> _enviar() async {
    if (!_validar()) {
      return;
    }

    FocusScope.of(context).unfocus();

    // El estado cambia solo: el `AppRouter` cambia a Home al autenticarse.
    await ref.read(authControllerProvider.notifier).login(
          email: _correo.text,
          password: _clave.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(authControllerProvider);
    final enviando = estado is SinSesion && estado.enviando;
    final errorServidor = estado is SinSesion ? estado.error : null;

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Espaciado.lg),
          children: [
            const SizedBox(height: Espaciado.xl),

            // --- cabecera ---
            const Center(
              child: Icon(CupertinoIcons.drop_fill, size: 56, color: AppTheme.verde),
            ),
            const SizedBox(height: Espaciado.md),
            const Center(
              child: Text(
                'MilkData',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                ),
              ),
            ),
            const SizedBox(height: Espaciado.xs),
            const Center(
              child: Text(
                'Recolección de leche',
                style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel),
              ),
            ),

            const SizedBox(height: Espaciado.xl),

            // --- formulario ---
            AppTextField(
              etiqueta: 'CORREO',
              controller: _correo,
              placeholder: 'tucorreo@ejemplo.com',
              icon: CupertinoIcons.envelope,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus: true,
              errorText: _errorCorreo,
              onChanged: (_) {
                // Al escribir se limpian los dos errores: el de campo y el del
                // servidor, que ya no corresponde a lo que el usuario está
                // corregiendo.
                if (_errorCorreo != null ||
                    (estado is SinSesion && estado.error != null)) {
                  setState(() => _errorCorreo = null);
                  ref.read(authControllerProvider.notifier).limpiarError();
                }
              },
            ),

            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'CONTRASEÑA',
              controller: _clave,
              placeholder: 'Tu contraseña',
              icon: CupertinoIcons.lock,
              obscureText: true,
              textInputAction: TextInputAction.go,
              errorText: _errorClave,
              onChanged: (_) {
                if (_errorClave != null ||
                    (estado is SinSesion && estado.error != null)) {
                  setState(() => _errorClave = null);
                  ref.read(authControllerProvider.notifier).limpiarError();
                }
              },
              onSubmitted: (_) => _enviar(),
            ),

            // --- error del servidor ---
            if (errorServidor != null) ...[
              const SizedBox(height: Espaciado.md),
              AppErrorBanner(mensaje: errorServidor.message),
            ],

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: 'Entrar',
              icon: CupertinoIcons.arrow_right,
              cargando: enviando,
              onPressed: _enviar,
            ),

            const SizedBox(height: Espaciado.xl),

            const Center(
              child: Text(
                'MilkData · Planta Ecológica Huata',
                style: TextStyle(fontSize: 12, color: CupertinoColors.tertiaryLabel),
              ),
            ),
            const SizedBox(height: Espaciado.xl),
          ],
        ),
      ),
    );
  }
}