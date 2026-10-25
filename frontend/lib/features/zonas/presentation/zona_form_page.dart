import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_time_field.dart';
import '../domain/zona.dart';
import 'providers/zonas_controller.dart';

/// Alta y edición de una zona.
///
/// El mismo formulario para las dos cosas: `zona` a `null` es un alta.
///
/// **Ruta y unidad son opcionales y se pueden quitar.** Esa es la regla que más
/// fácil se equivoca: mandar el campo omitido deja el valor anterior, y mandar
/// `null` lo quita. El formulario manda siempre los dos, precisamente para que
/// "desasignar" sea una acción y no un olvido.
class ZonaFormPage extends ConsumerStatefulWidget {
  const ZonaFormPage({super.key, this.zona});

  /// La zona a editar, o `null` para dar de alta una nueva.
  final Zona? zona;

  @override
  ConsumerState<ZonaFormPage> createState() => _ZonaFormPageState();
}

class _ZonaFormPageState extends ConsumerState<ZonaFormPage> {
  final _nombre = TextEditingController();

  /// Las horas van en `HH:MM:SS` o a `null`, y las pone la rueda.
  ///
  /// Ya no hay un `TextEditingController` por hora: el valor sale de la rueda y
  /// entra aquí. Con un controlador, volver de la hoja a la pantalla dejaría el
  /// texto viejo si el usuario pulsaba "Cancelar".
  String? _horaInicio;
  String? _horaFin;

  late bool _activo;

  /// Ruta elegida, o `null` para ninguna. `String` porque el `AppSelector`
  /// trabaja con identificadores de texto.
  String? _rutaId;

  /// Unidad elegida, o `null` para ninguna.
  String? _unidadId;

  /// Errores por campo.
  ///
  /// `AppTextField` no valida por su cuenta: lleva `errorText` y quien lo usa
  /// decide el mensaje. Por eso no hay `Form` con `validator`, sino este mapa.
  final _errores = <String, String>{};

  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.zona == null;

  @override
  void initState() {
    super.initState();

    final zona = widget.zona;
    _nombre.text = zona?.nombre ?? '';
    _horaInicio = zona?.horaInicio;
    _horaFin = zona?.horaFin;
    _activo = zona?.activo ?? true;
    _rutaId = zona?.rutaId?.toString();
    _unidadId = zona?.unidadId?.toString();
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  /// `HH:MM` a `HH:MM:SS`, que es lo que espera la base.
  ///
  /// Devuelve `null` si no se escribió nada, y el error lo pone `_validar`.
  static String? _aHoraLarga(String texto) {
    if (texto.isEmpty) {
      return null;
    }
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(texto)) {
      return '${texto.padRight(5, '0')}:00';
    }
    return texto;
  }

  /// Valida en cliente y devuelve si se puede seguir.
  ///
  /// El servidor vuelve a validar todo; esto solo evita un viaje y hace que el
  /// error salga junto al campo en vez de en un aviso arriba.
  bool _validar() {
    final errores = <String, String>{};
    final nombre = _nombre.text.trim();

    if (nombre.isEmpty) {
      errores['nombre'] = 'Ponle un nombre a la zona.';
    } else if (nombre.length > 100) {
      errores['nombre'] = 'Máximo 100 caracteres.';
    }

    // No hay validación de formato: la hora sale de una rueda y no se teclea,
    // así que "06:00 mal escrito" ya no es un caso posible. La única regla que
    // queda es de sentido, y la rueda no la impide: se puede elegir que empiece
    // a las 10 y acabe a las 6.
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

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    // `int.tryParse` y no `int.parse`: un id mal formado tiene que acabar siendo
    // "sin ruta" y no un `FormatError` en plena pantalla.
    final rutaId = _rutaId == null ? null : int.tryParse(_rutaId!);
    final unidadId = _unidadId == null ? null : int.tryParse(_unidadId!);

    final controller = ref.read(zonasControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            // La rueda ya deja la hora larga. `_aHoraLarga` se queda por si
            // algún día vuelve a haber un campo de texto: es idempotente.
            horaInicio: _aHoraLarga(_horaInicio ?? ''),
            horaFin: _aHoraLarga(_horaFin ?? ''),
            rutaId: rutaId,
            unidadId: unidadId,
            activo: _activo,
          )
        : await controller.editar(
            widget.zona!,
            nombre: _nombre.text.trim(),
            horaInicio: _aHoraLarga(_horaInicio ?? ''),
            horaFin: _aHoraLarga(_horaFin ?? ''),
            rutaId: rutaId,
            unidadId: unidadId,
            activo: _activo,
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
          ref.read(zonasControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final opciones = ref.watch(opcionesZonaProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva zona' : 'Editar zona'),
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
              placeholder: 'Zona Norte',
              icon: CupertinoIcons.map,
              textInputAction: TextInputAction.next,
              errorText: _errores['nombre'],
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
                    errorText: _errores['horaInicio'],
                    onChanged: (v) => setState(() {
                      _horaInicio = v;
                      // Se borra el error de la hora final al tocar la inicial:
                      // el mensaje quejlándose de un orden se resuelve al
                      // cambiar cualquiera de las dos, no solo la última.
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

            // Ruta y unidad se piden de otros módulos. Mientras no llegan se
            // enseña el girando y no un desplegable vacío, que parecería un
            // fallo cuando solo es que aún no ha contestado.
            opciones.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Espaciado.md),
                  child: CupertinoActivityIndicator(),
                ),
              ),
              error: (error, _) => AppNotice(
                texto: 'No se pudieron cargar las rutas y unidades. '
                    'Puedes guardar la zona sin asignarlas.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => Column(
                children: [
                  AppSelector(
                    etiqueta: 'RUTA',
                    valor: _rutaId ?? '',
                    vacio: opciones.hayRutas ? 'Sin ruta' : 'No hay rutas',
                    items: [
                      SelectorItem(id: '', etiqueta: 'Sin ruta'),
                      ...opciones.rutas.map(
                        (r) => SelectorItem(id: r.id.toString(), etiqueta: r.nombre),
                      ),
                    ],
                    limpiar: _rutaId == null ? null : () => setState(() => _rutaId = null),
                    onChanged: (valor) => setState(
                      () => _rutaId = (valor == null || valor.isEmpty) ? null : valor,
                    ),
                  ),
                  const SizedBox(height: Espaciado.md),

                  AppSelector(
                    etiqueta: 'UNIDAD',
                    valor: _unidadId ?? '',
                    vacio: opciones.hayUnidades ? 'Sin unidad' : 'No hay unidades',
                    items: [
                      SelectorItem(id: '', etiqueta: 'Sin unidad'),
                      ...opciones.unidades.map(
                        (u) => SelectorItem(id: u.id.toString(), etiqueta: u.nombre),
                      ),
                    ],
                    limpiar:
                        _unidadId == null ? null : () => setState(() => _unidadId = null),
                    onChanged: (valor) => setState(
                      () => _unidadId = (valor == null || valor.isEmpty) ? null : valor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Espaciado.md),

            _Interruptor(
              titulo: 'Activa',
              subtitulo: 'Si no, deja de aparecer en los listados de recogida.',
              valor: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Crear zona' : 'Guardar cambios',
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
