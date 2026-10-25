import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/domain/planta.dart';
import 'providers/plantas_controller.dart';

/// Alta y edición de una planta.
///
/// **`nombre` y `codigo` son obligatorios**, y el código es único: si se repite el
/// servidor responde 409. Es el identificador corto que sale en las etiquetas de
/// todas las pantallas de esa planta, y el que se escribe para entrar por código,
/// así que conviene que se lea de un vistazo: de ahí el mayúsculas automático.
///
/// **La dirección es opcional y se manda en blanco para borrarla**: quitarle la
/// dirección a una planta es una edición legítima, y mandarla vacía la deja como
/// estaba.
class PlantaFormPage extends ConsumerStatefulWidget {
  const PlantaFormPage({super.key, this.planta});

  /// La planta a editar, o `null` para crear una nueva.
  final Planta? planta;

  @override
  ConsumerState<PlantaFormPage> createState() => _PlantaFormPageState();
}

class _PlantaFormPageState extends ConsumerState<PlantaFormPage> {
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  final _direccion = TextEditingController();

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.planta == null;

  @override
  void initState() {
    super.initState();

    final planta = widget.planta;
    if (planta == null) {
      return;
    }

    _nombre.text = planta.nombre;
    _codigo.text = planta.codigo;
    _direccion.text = planta.direccion ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _direccion.dispose();
    super.dispose();
  }

  bool _validar() {
    final errores = <String, String>{};

    if (_nombre.text.trim().isEmpty) {
      errores['nombre'] = 'Ponle nombre a la planta.';
    }

    final codigo = _codigo.text.trim();
    if (codigo.isEmpty) {
      errores['codigo'] = 'El código es obligatorio: es lo que sale en las etiquetas.';
    } else if (codigo.length > 20) {
      // Tope de la columna. El backend avisa con un 400, pero verlo en la caja es
      // más útil que descubrirlo al guardar.
      errores['codigo'] = 'El código no puede pasar de 20 caracteres.';
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(plantasControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            codigo: _codigo.text.trim(),
            direccion: _direccion.text.trim(),
          )
        : await controller.editar(
            widget.planta!,
            nombre: _nombre.text.trim(),
            codigo: _codigo.text.trim(),
            direccion: _direccion.text.trim(),
          );

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _guardando = false;
      _errorGeneral =
          ref.read(plantasControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva planta' : 'Editar planta'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaciado.md),
          children: [
            if (_errorGeneral != null) ...[
              AppErrorBanner(mensaje: _errorGeneral!),
              const SizedBox(height: Espaciado.md),
            ],

            AppTextField(
              etiqueta: 'NOMBRE',
              controller: _nombre,
              placeholder: 'Planta Ecológica Huata',
              icon: CupertinoIcons.building_2_fill,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _errores.remove('nombre')),
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'CÓDIGO',
              controller: _codigo,
              placeholder: 'HUA',
              icon: CupertinoIcons.number,
              // **Mayúsculas forzadas en el teclado y en el texto.** El código sale
              // suelto en las etiquetas de todas las pantallas, y tener `hua` y
              // `HUA` como dos plantas distintas es un lío que nadie quiere.
              textCapitalization: TextCapitalization.characters,
              onChanged: (valor) {
                final mayus = valor.toUpperCase();
                if (mayus != valor) {
                  _codigo.value = TextEditingValue(
                    text: mayus,
                    selection: TextSelection.collapsed(offset: mayus.length),
                  );
                }
                setState(() => _errores.remove('codigo'));
              },
              errorText: _errores['codigo'],
            ),
            const SizedBox(height: Espaciado.xs),
            const AppNotice(
              texto: 'Único y corto. Es lo que verás en cada pantalla de esta planta.',
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DIRECCIÓN',
              controller: _direccion,
              placeholder: 'Distrito de Huata',
              icon: CupertinoIcons.location,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: Espaciado.xs),
            const AppNotice(
              texto: 'Opcional. Si la borras, se queda sin dirección.',
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Crear planta' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: _guardar,
            ),
            const SizedBox(height: Espaciado.sm),

            AppButton(
              texto: 'Cancelar',
              tono: AppButton.tonoSecundario,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}