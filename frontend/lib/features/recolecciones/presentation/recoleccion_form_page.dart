import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_time_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../proveedores/presentation/providers/proveedores_controller.dart';
import '../../unidades/presentation/providers/unidades_controller.dart';
import '../../zonas/presentation/providers/zonas_controller.dart';
import '../domain/recoleccion.dart';
import 'providers/recolecciones_controller.dart';

/// Alta y edición de una recolección.
///
/// **Siete cosas son obligatorias y el formulario no te deja salir sin ellas**:
/// proveedor, zona, unidad, cantidad, día y **dónde se anotó**. Los tres
/// desplegables no son opcionales porque el servidor los rechaza con un 400, y
/// descubrirlo en el móvil tras escribir veinte litros es la peor forma.
///
/// El `usuarioId` **no** es un desplegable: sale de la sesión. Es obligatorio,
/// pero no es una decisión de quien rellena, así que preguntarlo sería hacer que
/// el usuario elija algo que ya sabe.
class RecoleccionFormPage extends ConsumerStatefulWidget {
  const RecoleccionFormPage({super.key, this.recoleccion});

  /// La recolección a editar, o `null` para registrar una nueva.
  final Recoleccion? recoleccion;

  @override
  ConsumerState<RecoleccionFormPage> createState() => _RecoleccionFormPageState();
}

class _RecoleccionFormPageState extends ConsumerState<RecoleccionFormPage> {
  final _cantidad = TextEditingController();
  final _fecha = TextEditingController();
  final _temperatura = TextEditingController();

  String? _proveedorId;
  String? _zonaId;
  String? _unidadId;
  String? _hora;
  double? _temperaturaValor;

  /// Dónde se anotó. Por defecto `campo`, que es lo más común: el campo es
  /// donde se recoge la leche y la planta es donde se ya transformó.
  ///
  /// Es el único `ENUM` del formulario y **no lleva valor por defecto en la
  /// base**, así que hay que mandarlo siempre. Por eso se inicializa aquí en vez
  /// de dejar que el servidor lo suponga: si no, el alta falla con un 400 que
  /// habla de un campo que el usuario no vio nunca.
  String _registradoEn = Recoleccion.campo;

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.recoleccion == null;

  @override
  void initState() {
    super.initState();

    final recoleccion = widget.recoleccion;
    if (recoleccion == null) {
      // Sin registro se propone hoy: una recolección se anota el mismo día que
      // se hace, y tener que escribir la fecha a mano cada vez es un paso de más.
      //
      // **Proveedor, zona y unidad se dejan sin elegir a propósito.** Podrían
      // venir preelegidos tomando el primero de la lista, pero eso significaría
      // que el primer alta de la pantalla registra leche del primer proveedor de
      // la planta. Atribuir leche al productor equivocado es peor que hacer que
      // se elija.
      _fecha.text = _hoy();
      return;
    }

    _cantidad.text = _formatea(recoleccion.cantidad);
    _fecha.text = recoleccion.fecha;
    _proveedorId = recoleccion.proveedorId.toString();
    _zonaId = recoleccion.zonaId.toString();
    _unidadId = recoleccion.unidadId.toString();
    _hora = recoleccion.hora;
    _temperaturaValor = recoleccion.temperatura;
    _temperatura.text = recoleccion.temperatura == null
        ? ''
        : recoleccion.temperatura!.toStringAsFixed(1).replaceAll('.', ',');
    _registradoEn = recoleccion.registradoEn;
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _fecha.dispose();
    _temperatura.dispose();
    super.dispose();
  }

  /// El día de hoy en `YYYY-MM-DD`, que es lo que espera un `DATEONLY`.
  static String _hoy() {
    final ahora = DateTime.now();
    return '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
  }

  /// `25.5` a `25,5`, y `25.0` a `25`. Un `toStringAsFixed` fijo dejaría
  /// "25,50" en un campo donde se escribe a mano.
  static String _formatea(double valor) {
    if (valor == valor.truncateToDouble()) {
      return valor.truncate().toString();
    }
    return valor.toStringAsFixed(1).replaceAll('.', ',');
  }

  bool _validar() {
    final errores = <String, String>{};

    if (_proveedorId == null) {
      errores['proveedor'] = 'De quién es la leche.';
    }
    if (_zonaId == null) {
      errores['zona'] = 'De qué zona es.';
    }
    if (_unidadId == null) {
      errores['unidad'] = 'Qué unidad la recogió.';
    }

    final textoCantidad = _cantidad.text.trim();
    if (textoCantidad.isEmpty) {
      errores['cantidad'] = 'Cuántos litros.';
    } else {
      final numero = double.tryParse(textoCantidad.replaceAll(',', '.'));
      if (numero == null) {
        errores['cantidad'] = 'Eso no es un número.';
      } else if (numero <= 0) {
        // El backend acepta negativos y cero —lo medí: -5, 0 y 0,001 pasan—,
        // pero una recogida de menos cinco litros no existe, y dejarlo pasar
        // metería basura en el reporte de calidad sin que nadie se entere.
        errores['cantidad'] = 'Los litros tienen que ser más de cero.';
      } else if (numero > 999999.99) {
        // `FLOAT`, así que el límite real es del orden de los millones; este es
        // un tope de sentido para detectar un punto decimal de más.
        errores['cantidad'] = 'Esa cantidad no es real.';
      }
    }

    final fecha = _fecha.text.trim();
    if (fecha.isEmpty) {
      errores['fecha'] = 'Ponle el día de la recogida.';
    } else if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)) {
      errores['fecha'] = 'La fecha se escribe como 2026-10-13.';
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

    // `int.tryParse` y no `int.parse`: un id mal formado tiene que acabar siendo
    // "nada elegido" y no un FormatError en plena pantalla.
    final cantidad = double.parse(_cantidad.text.trim().replaceAll(',', '.'));

    // El `usuarioId` es obligatorio pero no es una decisión de quien rellena:
    // sale de la sesión. `usuario` vive en `Autenticado`, no en `AuthState`, así
    // que hay que estrechar el tipo antes de leerlo — y si no hay sesión no se
    // puede dar de alta, porque sin eso el servidor rechaza el registro.
    final estado = ref.read(authControllerProvider);
    if (estado is! Autenticado) {
      setState(() {
        _guardando = false;
        _errorGeneral = 'Tu sesión se ha cerrado. Vuelve a entrar.';
      });
      return;
    }
    final usuarioId = estado.usuario.id;

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(recoleccionesControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            proveedorId: int.parse(_proveedorId!),
            zonaId: int.parse(_zonaId!),
            unidadId: int.parse(_unidadId!),
            usuarioId: usuarioId,
            cantidad: cantidad,
            fecha: _fecha.text.trim(),
            registradoEn: _registradoEn,
            hora: _hora,
            temperatura: _temperaturaValor,
          )
        : await controller.editar(
            widget.recoleccion!,
            proveedorId: int.parse(_proveedorId!),
            zonaId: int.parse(_zonaId!),
            unidadId: int.parse(_unidadId!),
            usuarioId: usuarioId,
            cantidad: cantidad,
            fecha: _fecha.text.trim(),
            registradoEn: _registradoEn,
            hora: _hora,
            temperatura: _temperaturaValor,
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
          ref.read(recoleccionesControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final proveedores = ref.watch(opcionesDeProveedorProvider);
    final zonas = ref.watch(opcionesDeZonaProvider);
    final unidades = ref.watch(opcionesDeUnidadProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva recolección' : 'Editar recolección'),
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

            proveedores.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar los proveedores.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => _DesplegableObligatorio(
                etiqueta: 'PROVEEDOR',
                valor: _proveedorId,
                vacio: opciones.isEmpty ? 'No hay proveedores' : 'Elige el proveedor',
                error: _errores['proveedor'],
                items: opciones
                    .map((p) => SelectorItem(id: p.id.toString(), etiqueta: p.nombreCompleto))
                    .toList(),
                alCambiar: (v) => setState(() {
                  _proveedorId = v;
                  _errores.remove('proveedor');
                }),
              ),
            ),
            const SizedBox(height: Espaciado.md),

            zonas.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las zonas.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => _DesplegableObligatorio(
                etiqueta: 'ZONA',
                valor: _zonaId,
                vacio: opciones.isEmpty ? 'No hay zonas' : 'Elige la zona',
                error: _errores['zona'],
                items: opciones
                    .map((z) => SelectorItem(id: z.id.toString(), etiqueta: z.nombre))
                    .toList(),
                alCambiar: (v) => setState(() {
                  _zonaId = v;
                  _errores.remove('zona');
                }),
              ),
            ),
            const SizedBox(height: Espaciado.md),

            unidades.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las unidades.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => _DesplegableObligatorio(
                etiqueta: 'UNIDAD',
                valor: _unidadId,
                vacio: opciones.isEmpty ? 'No hay unidades' : 'Elige la unidad',
                error: _errores['unidad'],
                items: opciones
                    .map((u) => SelectorItem(id: u.id.toString(), etiqueta: u.nombre))
                    .toList(),
                alCambiar: (v) => setState(() {
                  _unidadId = v;
                  _errores.remove('unidad');
                }),
              ),
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'LITROS',
              controller: _cantidad,
              placeholder: '25,5',
              icon: CupertinoIcons.drop,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _alTemperatura(v),
              errorText: _errores['cantidad'],
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
                    etiqueta: 'HORA',
                    valor: _hora,
                    icon: CupertinoIcons.clock,
                    onChanged: (v) => setState(() => _hora = v),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: AppTextField(
                    etiqueta: 'TEMPERATURA °C',
                    controller: _temperatura,
                    placeholder: '4,5',
                    icon: CupertinoIcons.thermometer,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (v) => setState(() => _temperaturaValor = _aNumero(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('¿Dónde se anotó?'),
            const SizedBox(height: Espaciado.xs),

            // Una casilla y no un desplegable: son dos opciones y una casilla deja
            // claro que es una decisión, no un dato que se busca.
            Row(
              children: [
                Expanded(
                  child: _Casilla(
                    texto: 'En el campo',
                    activo: _registradoEn == Recoleccion.campo,
                    onPressed: () => setState(() => _registradoEn = Recoleccion.campo),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: _Casilla(
                    texto: 'En la planta',
                    activo: _registradoEn == Recoleccion.planta,
                    onPressed: () => setState(() => _registradoEn = Recoleccion.planta),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.sm),
            const AppNotice(
              texto: 'El servidor no tiene valor por defecto para este campo: si no '
                  'se dice dónde se anotó, el alta falla.',
              color: CupertinoColors.secondaryLabel,
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Registrar recolección' : 'Guardar cambios',
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

  /// Traduce el texto de la temperatura a número, tolerando la coma.
  ///
  /// Vacío es `null` —no temperatura anotada— y no cero: cero grados son una
  /// medida y "no lo anoté" no lo es.
  static double? _aNumero(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) {
      return null;
    }
    return double.tryParse(limpio);
  }

  /// Limpia el error de los litros al escribir, sin tocar el de la temperatura.
  ///
  /// Van en métodos separados a propósito: un nombre que dijera "al escribir"
  /// invited a borrarlo todo, y el error de un campo no debe desaparecer por
  /// tocar otro.
  void _alTemperatura(String _) {
    if (_errores.containsKey('cantidad')) {
      setState(() => _errores.remove('cantidad'));
    }
  }
}

/// Desplegable con obligatorio y error debajo.
///
/// Envuelto en su propia clase porque son tres iguales y porque el error tiene
/// que salir **debajo** del desplegable, no dentro del `AppSelector`, que no lo
/// admite.
class _DesplegableObligatorio extends StatelessWidget {
  const _DesplegableObligatorio({
    required this.etiqueta,
    required this.valor,
    required this.vacio,
    required this.error,
    required this.items,
    required this.alCambiar,
  });

  final String etiqueta;
  final String? valor;
  final String vacio;
  final String? error;
  final List<SelectorItem> items;
  final ValueChanged<String?> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelector(
          etiqueta: etiqueta,
          valor: valor ?? '',
          vacio: vacio,
          items: items,
          limpiar: valor == null ? null : () => alCambiar(null),
          onChanged: (v) => alCambiar(v == null || v.isEmpty ? null : v),
        ),
        if (error != null) ...[
          const SizedBox(height: Espaciado.xs),
          Text(
            error!,
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
          ),
        ],
      ],
    );
  }
}

/// Casilla de dos estados, al estilo de iOS.
class _Casilla extends StatelessWidget {
  const _Casilla({required this.texto, required this.activo, required this.onPressed});

  final String texto;
  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.sm),
      color: activo ? AppTheme.verde : CupertinoColors.white,
      onPressed: onPressed,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 14,
          fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
          color: activo ? CupertinoColors.white : CupertinoColors.label,
        ),
      ),
    );
  }
}

/// Un hueco girando mientras llegan los desplegables.
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
