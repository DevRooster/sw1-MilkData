import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_time_field.dart';
import '../domain/ruta.dart';
import 'providers/rutas_controller.dart';

/// Alta y edición de una ruta.
///
/// El mismo formulario para las dos cosas: `ruta` a `null` es un alta.
class RutaFormPage extends ConsumerStatefulWidget {
  const RutaFormPage({super.key, this.ruta});

  /// La ruta a editar, o `null` para dar de alta una nueva.
  final Ruta? ruta;

  @override
  ConsumerState<RutaFormPage> createState() => _RutaFormPageState();
}

class _RutaFormPageState extends ConsumerState<RutaFormPage> {
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  final _descripcion = TextEditingController();

  /// Las horas van en `HH:MM:SS` o a `null`, y las pone la rueda.
  ///
  /// Ya no hay un `TextEditingController` por hora: el valor sale de la rueda y
  /// entra aquí. Con un controlador, volver de la hoja a la pantalla dejaría el
  /// texto viejo si el usuario pulsaba "Cancelar".
  String? _horaInicio;
  String? _horaFin;

  late bool _activa;

  /// Errores por campo.
  ///
  /// `AppTextField` no valida por su cuenta: lleva `errorText` y quien lo usa
  /// decide el mensaje. Por eso no hay `Form` con `validator`, sino este mapa.
  final _errores = <String, String>{};

  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.ruta == null;

  @override
  void initState() {
    super.initState();

    final ruta = widget.ruta;
    _nombre.text = ruta?.nombre ?? '';
    _codigo.text = ruta?.codigo ?? '';
    _descripcion.text = ruta?.descripcion ?? '';
    _horaInicio = ruta?.horaInicio;
    _horaFin = ruta?.horaFin;
    _activa = ruta?.activa ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// `HH:MM` a `HH:MM:SS`, que es lo que espera la base.
  ///
  /// Devuelve `null` si la hora no vale, y el error lo pone `_validar`.
  static String? _aHoraLarga(String texto) {
    if (texto.isEmpty) {
      return null;
    }
    final conDosPartes = RegExp(r'^\d{1,2}:\d{2}$');
    if (conDosPartes.hasMatch(texto)) {
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
    final codigo = _codigo.text.trim();

    if (nombre.isEmpty) {
      errores['nombre'] = 'Ponle un nombre a la ruta.';
    } else if (nombre.length > 120) {
      errores['nombre'] = 'Máximo 120 caracteres.';
    }

    // El código es corto y es lo que se teclea en la operativa, así que se
    // avisa de los espacios: "RUTA NORTE" no es lo mismo que "RUTANORTE" y el
    // fallo aparece luego, al buscar, no al guardar.
    if (codigo.isEmpty) {
      errores['codigo'] = 'Ponle un código a la ruta.';
    } else {
      if (codigo.length > 20) {
        errores['codigo'] = 'Máximo 20 caracteres.';
      }
      if (codigo.contains(' ')) {
        errores['codigo'] = 'El código no lleva espacios.';
      }
    }

    // No hay validación de formato: la hora sale de una rueda y no se teclea,
    // así que "06:00 mal escrito" ya no es un caso posible. La única regla que
    // queda es de sentido, y la rueda no la impide: se puede elegir que empiece
    // a las 11 y acabe a las 6.
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

    final descripcion = _descripcion.text.trim();

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(rutasControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            codigo: _codigo.text.trim(),
            descripcion: descripcion,
            // La rueda ya deja la hora larga. `_aHoraLarga` se queda por si
            // algún día vuelve a haber un campo de texto: es idempotente.
            horaInicio: _aHoraLarga(_horaInicio ?? ''),
            horaFin: _aHoraLarga(_horaFin ?? ''),
            activa: _activa,
          )
        : await controller.editar(
            widget.ruta!,
            nombre: _nombre.text.trim(),
            codigo: _codigo.text.trim(),
            descripcion: descripcion,
            horaInicio: _aHoraLarga(_horaInicio ?? ''),
            horaFin: _aHoraLarga(_horaFin ?? ''),
            activa: _activa,
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
      _errorGeneral = ref.read(rutasControllerProvider).error?.message
          ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva ruta' : 'Editar ruta'),
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
              placeholder: 'Ruta Norte',
              icon: CupertinoIcons.map,
              textInputAction: TextInputAction.next,
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'CÓDIGO',
              controller: _codigo,
              placeholder: 'RUTANORTE',
              icon: CupertinoIcons.number,
              // En mayúsculas y sin espacios: es lo que se teclea en la operativa
              // y escribirlo de otra forma acaba buscándose mal.
              textCapitalization: TextCapitalization.characters,
              onChanged: (valor) => _codigo.text = valor.toUpperCase().replaceAll(' ', ''),
              errorText: _errores['codigo'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DESCRIPCIÓN',
              controller: _descripcion,
              placeholder: 'Recoge la zona norte de 6 a 11',
              icon: CupertinoIcons.text_alignleft,
              maxLines: 3,
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
            const SizedBox(height: Espaciado.md),

            _Interruptor(
              titulo: 'Activa',
              subtitulo: 'Si no, no se puede planear ningún recorrido sobre ella.',
              valor: _activa,
              onChanged: (v) => setState(() => _activa = v),
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Crear ruta' : 'Guardar cambios',
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