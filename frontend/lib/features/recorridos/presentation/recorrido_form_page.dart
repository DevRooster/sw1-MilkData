import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_time_field.dart';
import '../../rutas/presentation/providers/rutas_controller.dart';
import '../../unidades/presentation/providers/unidades_controller.dart';
import '../domain/recorrido.dart';
import 'providers/recorridos_controller.dart';

/// Alta y edición de un recorrido.
///
/// El mismo formulario para las dos cosas: `recorrido` a `null` es un alta.
///
/// **Solo se edita mientras está planificado.** Una vez que arranca, sus paradas
/// quedan selladas con las que tuviera la ruta: cambiarle la ruta dejaría esas
/// paradas apuntando a una ruta que ya no es la suya, y el backend lo rechaza.
class RecorridoFormPage extends ConsumerStatefulWidget {
  const RecorridoFormPage({super.key, this.recorrido});

  /// El recorrido a editar, o `null` para planificar uno nuevo.
  final Recorrido? recorrido;

  @override
  ConsumerState<RecorridoFormPage> createState() => _RecorridoFormPageState();
}

class _RecorridoFormPageState extends ConsumerState<RecorridoFormPage> {
  final _fecha = TextEditingController();
  final _observaciones = TextEditingController();

  final _ayudanteNombre = TextEditingController();
  final _ayudanteApellido = TextEditingController();
  final _ayudanteDni = TextEditingController();
  final _ayudanteCelular = TextEditingController();

  String? _rutaId;
  String? _unidadId;
  String? _horaInicio;
  String? _horaFin;

  /// Si el recorrido lleva ayudante.
  ///
  /// **Estado propio, no derivado de los campos.** Antes se calculaba como
  /// "¿hay algo escrito?", y eso hacía el interruptor inusable: al pulsarlo sin
  /// haber escrito nada el valor seguía siendo `false` y la casilla se saltaba
  /// sola. Un control que depende de otros campos no se puede encender antes de
  /// rellenarlos, que es justo lo contrario de lo que se espera de un interruptor.
  ///
  /// Se enciende solo si el usuario empieza a escribir, para no perder lo que
  /// teclea cuando el interruptor está apagado; apagarlo borra los campos.
  bool _conAyudante = false;

  /// El ayudante va **entero o no va**.
  ///
  /// El servidor rechaza el alta si mandas el nombre sin el apellido y el DNI.
  /// Tres campos sueltos dejan esa combinación a un paso de teclear mal, así que
  /// aquí se valida antes de viajar y se explica cuál falta. El celular es
  /// libre: no forma parte del grupo.
  bool get _ayudanteVacio =>
      _ayudanteNombre.text.trim().isEmpty &&
      _ayudanteApellido.text.trim().isEmpty &&
      _ayudanteDni.text.trim().isEmpty;

  /// `true` si hay algo escrito del ayudante.
  ///
  /// Ya no decide el interruptor —para eso está `_conAyudante`— pero sigue
  /// haciendo falta: si el interruptor está apagado y aun así hay texto, es que
  /// el usuario lo escribió sin darse cuenta, y al guardar no se debe perder.
  bool get _ayudanteHayAlgo =>
      _ayudanteNombre.text.trim().isNotEmpty ||
      _ayudanteApellido.text.trim().isNotEmpty ||
      _ayudanteDni.text.trim().isNotEmpty ||
      _ayudanteCelular.text.trim().isNotEmpty;

  /// Lo que se manda al servidor: ayudante si el interruptor está encendido **o**
  /// si quedó algo escrito.
  ///
  /// La segunda mitad es a prueba de la torpeza: escribir el nombre Having no
  /// encender el interruptor no borra lo tecleado al guardar.
  bool get _mandarAyudante => _conAyudante || _ayudanteHayAlgo;

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.recorrido == null;

  @override
  void initState() {
    super.initState();

    final recorrido = widget.recorrido;
    if (recorrido == null) {
      // Sin recorrido se propone hoy: planificar un recorrido para dentro de
      // tres semanas es raro, y tener que escribir la fecha a mano cada vez es
      // un paso de más.
      _fecha.text = _hoy();
    } else {
      _fecha.text = recorrido.fecha;
      _rutaId = recorrido.rutaId.toString();
      _unidadId = recorrido.unidadId.toString();
      _horaInicio = recorrido.horaInicio;
      _horaFin = recorrido.horaFin;
      _observaciones.text = recorrido.observaciones ?? '';
      _ayudanteNombre.text = recorrido.ayudanteNombre ?? '';
      _ayudanteApellido.text = recorrido.ayudanteApellido ?? '';
      _ayudanteDni.text = recorrido.ayudanteDni ?? '';
      _ayudanteCelular.text = recorrido.ayudanteCelular ?? '';
    }

    // Editando, el interruptor arranca como estaba el registro: encendido si el
    // recorrido ya traía ayudante, apagado si no.
    _conAyudante = _ayudanteHayAlgo;

    // El nombre del ayudante se pasa a mayúscula y el apellido con mayúscula
    // inicial al perder el foco, para que "perez" y "Pérez" no acaben siendo dos
    // formas de escribir lo mismo.
    _ayudanteApellido.addListener(_normalizar);
  }

  @override
  void dispose() {
    _fecha.dispose();
    _observaciones.dispose();
    _ayudanteNombre.dispose();
    _ayudanteApellido.dispose();
    _ayudanteDni.dispose();
    _ayudanteCelular.dispose();
    super.dispose();
  }

  void _normalizar() {
    final texto = _ayudanteApellido.text;
    if (texto.isEmpty) {
      return;
    }
    final normalizado = texto[0].toUpperCase() + texto.substring(1);
    if (normalizado != texto) {
      _ayudanteApellido.value = TextEditingValue(
        text: normalizado,
        selection: TextSelection.collapsed(offset: normalizado.length),
      );
    }
  }

  /// El día de hoy en `YYYY-MM-DD`, que es lo que espera un `DATEONLY`.
  static String _hoy() {
    final ahora = DateTime.now();
    return '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
  }

  /// Valida en cliente y devuelve si se puede seguir.
  bool _validar() {
    final errores = <String, String>{};

    if (_rutaId == null) {
      errores['ruta'] = 'Elige la ruta que se va a recorrer.';
    }
    if (_unidadId == null) {
      errores['unidad'] = 'Elige la unidad que la recorre.';
    }

    final fecha = _fecha.text.trim();
    if (fecha.isEmpty) {
      errores['fecha'] = 'Ponle el día del recorrido.';
    } else if (!_fechaValida(fecha)) {
      errores['fecha'] = 'La fecha se escribe como 2026-10-13.';
    }

    final dni = _ayudanteDni.text.trim();
    if (dni.isNotEmpty && !RegExp(r'^\d{6,12}$').hasMatch(dni)) {
      errores['ayudanteDni'] = 'El DNI va solo con números.';
    }

    // El servidor exige nombre, apellido y DNI juntos. Aquí se avisa antes de
    // viajar, porque un 400 hablando del ayudante no dice cuál de los tres
    // falta.
    final nombre = _ayudanteNombre.text.trim();
    final apellido = _ayudanteApellido.text.trim();
    if (!(_ayudanteVacio || (nombre.isNotEmpty && apellido.isNotEmpty && dni.isNotEmpty))) {
      errores['ayudante'] = 'Ponle nombre, apellido y DNI del ayudante, o déjalo vacío.';
    }

    // `errorDeRangoHoras` devuelve `null` cuando no hay problema, y un `null` no
    // cabe en un mapa de texto a texto: la clave se quita en vez de ponerse a
    // null, que es lo que dejaría el aviso pegado en pantalla para siempre.
    final errorFin = errorDeRangoHoras(_horaInicio, _horaFin);
    if (errorFin == null) {
      errores.remove('horaFin');
    } else {
      errores['horaFin'] = errorFin;
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  static bool _fechaValida(String texto) {
    final partes = texto.split('-');
    if (partes.length != 3 || partes[0].length != 4) {
      return false;
    }
    final y = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final d = int.tryParse(partes[2]);
    if (y == null || m == null || d == null) {
      return false;
    }
    return m >= 1 && m <= 12 && d >= 1 && d <= 31;
  }

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final conAyudante = _mandarAyudante;
    final controller = ref.read(recorridosControllerProvider.notifier);

    // `_campos` está en la capa de API y quita las claves vacías: por eso aquí
    // se puede mandar `null` sin miedo en el nombre del ayudante cuando no
    // hay ayudante.
    final ok = esAlta
        ? await controller.crear(
            rutaId: int.parse(_rutaId!),
            unidadId: int.parse(_unidadId!),
            fecha: _fecha.text.trim(),
            horaInicio: _horaInicio,
            horaFin: _horaFin,
            ayudanteNombre: conAyudante ? _ayudanteNombre.text.trim() : null,
            ayudanteApellido: conAyudante ? _ayudanteApellido.text.trim() : null,
            ayudanteDni: conAyudante ? _ayudanteDni.text.trim() : null,
            ayudanteCelular: conAyudante ? _ayudanteCelular.text.trim() : null,
            observaciones: _observaciones.text.trim(),
          )
        : await controller.editar(
            widget.recorrido!,
            rutaId: int.parse(_rutaId!),
            unidadId: int.parse(_unidadId!),
            fecha: _fecha.text.trim(),
            horaInicio: _horaInicio,
            horaFin: _horaFin,
            ayudanteNombre: conAyudante ? _ayudanteNombre.text.trim() : null,
            ayudanteApellido: conAyudante ? _ayudanteApellido.text.trim() : null,
            ayudanteDni: conAyudante ? _ayudanteDni.text.trim() : null,
            ayudanteCelular: conAyudante ? _ayudanteCelular.text.trim() : null,
            observaciones: _observaciones.text.trim(),
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
      _errorGeneral = ref.read(recorridosControllerProvider).error?.message
          ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final rutas = ref.watch(opcionesDeRutaProvider);
    final unidades = ref.watch(opcionesDeUnidadProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nuevo recorrido' : 'Editar recorrido'),
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

            rutas.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las rutas. Cierra y vuelve a abrir.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => Column(
                children: [
                  AppSelector(
                    etiqueta: 'RUTA',
                    valor: _rutaId ?? '',
                    vacio: opciones.isEmpty ? 'No hay rutas' : 'Elige la ruta',
                    items: [
                      ...opciones.map(
                        (r) => SelectorItem(id: r.id.toString(), etiqueta: r.nombre),
                      ),
                    ],
                    limpiar: _rutaId == null ? null : () => setState(() => _rutaId = null),
                    onChanged: (valor) => setState(() {
                      _rutaId = valor;
                      _errores.remove('ruta');
                    }),
                  ),
                  if (_errores['ruta'] != null) ...[
                    const SizedBox(height: Espaciado.xs),
                    Text(
                      _errores['ruta']!,
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Espaciado.md),

            unidades.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las unidades. Cierra y vuelve a abrir.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => Column(
                children: [
                  AppSelector(
                    etiqueta: 'UNIDAD',
                    valor: _unidadId ?? '',
                    vacio: opciones.isEmpty ? 'No hay unidades' : 'Elige la unidad',
                    items: [
                      ...opciones.map(
                        (u) => SelectorItem(id: u.id.toString(), etiqueta: u.nombre),
                      ),
                    ],
                    limpiar:
                        _unidadId == null ? null : () => setState(() => _unidadId = null),
                    onChanged: (valor) => setState(() {
                      _unidadId = valor;
                      _errores.remove('unidad');
                    }),
                  ),
                  if (_errores['unidad'] != null) ...[
                    const SizedBox(height: Espaciado.xs),
                    Text(
                      _errores['unidad']!,
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DÍA',
              controller: _fecha,
              placeholder: '2026-10-13',
              icon: CupertinoIcons.calendar,
              keyboardType: TextInputType.datetime,
              onChanged: (_) => setState(() => _errores.remove('fecha')),
              errorText: _errores['fecha'],
            ),
            const SizedBox(height: Espaciado.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTimeField(
                    etiqueta: 'HORA INICIO',
                    valor: _horaInicio,
                    icon: CupertinoIcons.clock,
                    onChanged: (v) => setState(() {
                      _horaInicio = v;
                      _errores.remove('horaFin');
                    }),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: AppTimeField(
                    etiqueta: 'HORA FIN',
                    valor: _horaFin,
                    icon: CupertinoIcons.clock,
                    errorText: _errores['horaFin'],
                    onChanged: (v) => setState(() {
                      _horaFin = v;
                      _errores.remove('horaFin');
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('Ayudante'),
            const SizedBox(height: Espaciado.xs),

            // Interruptor en vez de tres campos a la vista: el ayudante es
            // opcional, y enseñarlo siempre llenaría el formulario de campos que
            // casi nadie usa.
            _Interruptor(
              titulo: 'Lleva ayudante',
              subtitulo: 'Sin ayudante, el recorrido lo hace solo el acopiador.',
              valor: _conAyudante,
              onChanged: (v) => setState(() {
                _conAyudante = v;
                if (!v) {
                  _ayudanteNombre.clear();
                  _ayudanteApellido.clear();
                  _ayudanteDni.clear();
                  _ayudanteCelular.clear();
                }
                _errores.remove('ayudante');
              }),
            ),

            if (_conAyudante) ...[
              const SizedBox(height: Espaciado.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      etiqueta: 'NOMBRE',
                      controller: _ayudanteNombre,
                      placeholder: 'Luis',
                      icon: CupertinoIcons.person,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {
                  // Escribir un campo enciende el interruptor: si el usuario no
                  // lo pulsa y teclea igualmente, lo que quiere es un ayudante.
                  // Sin esto, escribiría a ciegas en unos campos invisibles.
                  _conAyudante = true;
                  _errores.remove('ayudante');
                }),
                    ),
                  ),
                  const SizedBox(width: Espaciado.sm),
                  Expanded(
                    child: AppTextField(
                      etiqueta: 'APELLIDO',
                      controller: _ayudanteApellido,
                      placeholder: 'Gómez',
                      icon: CupertinoIcons.person,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {
                  // Escribir un campo enciende el interruptor: si el usuario no
                  // lo pulsa y teclea igualmente, lo que quiere es un ayudante.
                  // Sin esto, escribiría a ciegas en unos campos invisibles.
                  _conAyudante = true;
                  _errores.remove('ayudante');
                }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaciado.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      etiqueta: 'DNI',
                      controller: _ayudanteDni,
                      placeholder: '45678912',
                      icon: CupertinoIcons.creditcard,
                      keyboardType: TextInputType.number,
                      errorText: _errores['ayudanteDni'],
                    ),
                  ),
                  const SizedBox(width: Espaciado.sm),
                  Expanded(
                    child: AppTextField(
                      etiqueta: 'CELULAR',
                      controller: _ayudanteCelular,
                      placeholder: '999888777',
                      icon: CupertinoIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              if (_errores['ayudante'] != null) ...[
                const SizedBox(height: Espaciado.xs),
                Text(
                  _errores['ayudante']!,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
                ),
              ],
              const SizedBox(height: Espaciado.sm),
              const AppNotice(
                texto: 'Nombre, apellido y DNI van juntos: el servidor no acepta '
                    'uno sin los otros dos.',
                color: CupertinoColors.secondaryLabel,
              ),
            ],

            const SizedBox(height: Espaciado.lg),

            AppTextField(
              etiqueta: 'OBSERVACIONES',
              controller: _observaciones,
              placeholder: 'Algo que deba saber quien salga',
              icon: CupertinoIcons.text_alignleft,
              maxLines: 3,
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Planificar recorrido' : 'Guardar cambios',
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

/// Un hueco girando mientras llegan las rutas o las unidades.
class _Esperando extends StatelessWidget {
  const _Esperando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Espaciado.lg),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

/// Interruptor con título y explicación debajo.
class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
