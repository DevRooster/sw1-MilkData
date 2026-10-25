import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../plantas/presentation/providers/plantas_controller.dart';
import '../domain/evento.dart';
import 'providers/eventos_controller.dart';

/// Alta y edición de un evento.
///
/// **Nombre y fecha son los dos obligatorios**, y los dos dan 400 si faltan. La
/// fecha con la cadena vacía daba un **500** hasta que se le puso validación:
/// `allowNull` no coge `""`, MySQL lo convertía en "Invalid date" y reventaba.
///
/// `lugar` y `descripcion` son opcionales y se **omiten** en vez de mandarse
/// vacíos: mandarlos en blanco deja una cadena vacía en la base, y un evento con
/// sitio "" se ve en el desplegable de asistencias como "Reunión · ".
class EventoFormPage extends ConsumerStatefulWidget {
  const EventoFormPage({super.key, this.evento});

  /// El evento a editar, o `null` para crear uno nuevo.
  final Evento? evento;

  @override
  ConsumerState<EventoFormPage> createState() => _EventoFormPageState();
}

class _EventoFormPageState extends ConsumerState<EventoFormPage> {
  final _nombre = TextEditingController();
  final _fecha = TextEditingController();
  final _lugar = TextEditingController();
  final _descripcion = TextEditingController();

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.evento == null;

  @override
  void initState() {
    super.initState();

    final evento = widget.evento;
    if (evento == null) {
      // Sin evento se propone hoy: uno se anota el día que ocurre y tener que
      // escribir la fecha a mano cada vez es un paso de más.
      _fecha.text = _hoy();
      return;
    }

    _nombre.text = evento.nombre;
    _fecha.text = evento.fecha;
    _lugar.text = evento.lugar ?? '';
    _descripcion.text = evento.descripcion ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _fecha.dispose();
    _lugar.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// El día de hoy en `YYYY-MM-DD`, que es lo que espera un `DATEONLY`.
  static String _hoy() {
    final ahora = DateTime.now();
    return '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
  }

  bool _validar() {
    final errores = <String, String>{};

    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      errores['nombre'] = 'Ponle nombre al evento.';
    } else if (nombre.length > Evento.maximoNombre) {
      // El backend responde 400 con el mismo tope, pero verlo en la caja es más
      // útil que descubrirlo después de escribir doscientas letras.
      errores['nombre'] = 'El nombre no puede pasar de ${Evento.maximoNombre} caracteres.';
    }

    final fecha = _fecha.text.trim();
    if (fecha.isEmpty) {
      errores['fecha'] = 'Ponle el día del evento.';
    } else if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)) {
      errores['fecha'] = 'La fecha se escribe como 2026-10-20.';
    }

    if (_lugar.text.trim().length > Evento.maximoLugar) {
      errores['lugar'] = 'El lugar no puede pasar de ${Evento.maximoLugar} caracteres.';
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

    final controller = ref.read(eventosControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            fecha: _fecha.text.trim(),
            lugar: _lugar.text.trim(),
            descripcion: _descripcion.text.trim(),
          )
        : await controller.editar(
            widget.evento!,
            nombre: _nombre.text.trim(),
            fecha: _fecha.text.trim(),
            lugar: _lugar.text.trim(),
            descripcion: _descripcion.text.trim(),
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
          ref.read(eventosControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final planta = ref.watch(plantaActualProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nuevo evento' : 'Editar evento'),
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

            // **La planta va en el propio formulario**, no solo en la lista: es
            // aquí donde se decide a qué planta pertenece, y verlo mientras se
            // escribe quita la duda de si lo estás creando donde debes.
            if (planta != null) ...[
              AppPill(texto: 'Planta $planta', color: CupertinoColors.systemGrey),
              const SizedBox(height: Espaciado.md),
            ],

            AppTextField(
              etiqueta: 'NOMBRE',
              controller: _nombre,
              placeholder: 'Reunión de ruta del Norte',
              icon: CupertinoIcons.textformat,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _errores.remove('nombre')),
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DÍA',
              controller: _fecha,
              placeholder: '2026-10-20',
              icon: CupertinoIcons.calendar,
              keyboardType: TextInputType.datetime,
              onChanged: (_) => setState(() => _errores.remove('fecha')),
              errorText: _errores['fecha'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'LUGAR',
              controller: _lugar,
              placeholder: 'Sala de reuniones',
              icon: CupertinoIcons.location,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _errores.remove('lugar')),
              errorText: _errores['lugar'],
            ),
            const SizedBox(height: Espaciado.xs),
            const AppNotice(
              texto: 'Opcional. Si no lo rellenas, se queda vacío.',
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DESCRIPCIÓN',
              controller: _descripcion,
              placeholder: 'De qué va la reunión.',
              icon: CupertinoIcons.doc_text,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Crear evento' : 'Guardar cambios',
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