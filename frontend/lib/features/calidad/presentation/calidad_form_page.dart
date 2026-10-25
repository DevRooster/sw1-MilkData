import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../recolecciones/domain/recoleccion.dart';
import '../domain/control_calidad.dart';
import 'providers/calidad_controller.dart';

/// Alta y edición de un control de calidad.
///
/// **Una recolección solo admite un análisis.** `recoleccionId` es único en la
/// base, y eso no lo avisa el formulario: se descubre al guardar, después de
/// haber escrito las siete medidas. Por eso el desplegable de recolección
/// no ofrece las que ya tienen análisis: la regla incómoda se cumple
/// enviando solo lo que el servidor acepta, en vez de dejar que se aprenda a
/// base de errores.
///
/// El `usuarioId` sale de la sesión. Es obligatorio, pero no es una decisión de
/// quien rellena.
class CalidadFormPage extends ConsumerStatefulWidget {
  const CalidadFormPage({super.key, this.control});

  /// El control a editar, o `null` para analizar una recolección nueva.
  final ControlCalidad? control;

  @override
  ConsumerState<CalidadFormPage> createState() => _CalidadFormPageState();
}

class _CalidadFormPageState extends ConsumerState<CalidadFormPage> {
  final _grasa = TextEditingController();
  final _proteina = TextEditingController();
  final _lactosa = TextEditingController();
  final _densidad = TextEditingController();
  final _aguaAnadida = TextEditingController();
  final _ph = TextEditingController();

  /// La recolección analizada, como texto de id para el desplegable.
  String? _recoleccionId;

  /// El veredicto guardado.
  ///
  /// Arranca calculado a partir de las medidas que ya hay, no en `pura` a pelo.
  /// Antes iba fijo a `pura` y eso era un problema: abrir un análisis que en la
  /// base está como `adulterada` lo enseña como `pura` hasta que alguien se
  /// acordara de tocarlo.
  String _resultado = ControlCalidad.pura;

  /// `true` cuando la persona ha cambiado el veredicto con la mano.
  ///
  /// En cuanto es `true` la app **deja de recalcular**: la regla propone, la
  /// persona manda. Sin esta marca, escribir el agua añadida después de haber
  /// corregido a `pura` volvería a imponer el `adulterada` sin avisar.
  bool _resultadoCorregido = false;

  /// Recalcula el veredicto con las medidas que hay ahora mismo.
  ///
  /// No hace nada si la persona ya lo corrigió a mano: la regla propone y el
  /// laboratorio dispone. Se llama al cambiar el agua añadida y el pH, que son
  /// las dos medidas que la regla mira; el resto no la tocan.
  void _recalcularResultado() {
    if (_resultadoCorregido) {
      return;
    }

    _resultado = calculaResultado(
      aguaAnadida: _numeroDe(_aguaAnadida.text),
      ph: _numeroDe(_ph.text),
    );
  }

  /// Lee un campo de medida como número, tolerando la coma.
  ///
  /// `6,7` y `6.7` son lo mismo y el laboratorio escribe con las dos, así que
  /// los dos separadores valen. Devuelve `null` si no hay nada o no es un
  /// número: una casilla a medio rellenar no debe poner `adulterada` por un `6,`
  /// suelto.
  double? _numeroDe(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) {
      return null;
    }

    return double.tryParse(limpio);
  }

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.control == null;

  @override
  void initState() {
    super.initState();

    final control = widget.control;
    if (control == null) {
      return;
    }

    _recoleccionId = control.recoleccionId.toString();
    _resultado = control.resultado;
    _grasa.text = _formatea(control.grasa);
    _proteina.text = _formatea(control.proteina);
    _lactosa.text = _formatea(control.lactosa);
    _densidad.text = _formatea(control.densidad);
    _aguaAnadida.text = _formatea(control.aguaAnadida);
    _ph.text = _formatea(control.ph);

    // Editando, el veredicto de la base manda. Que la regla lo recalcule al abrir
    // tiraría por los suelos la corrección que alguien ya hizo a mano en el
    // laboratorio, así que se marca como corregido y la app no vuelve a tocarlo.
    _resultado = control.resultado;
    _resultadoCorregido = true;
  }

  @override
  void dispose() {
    _grasa.dispose();
    _proteina.dispose();
    _lactosa.dispose();
    _densidad.dispose();
    _aguaAnadida.dispose();
    _ph.dispose();
    super.dispose();
  }

  /// `null` es "no medido" y se escribe como cadena vacía.
  ///
  /// Un `toStringAsFixed(1)` fijo dejaría "3,0" en un campo donde se escribe a
  /// mano, y "0,0" además no se distingue de una medida de cero.
  static String _formatea(double? valor) {
    if (valor == null) {
      return '';
    }
    return ControlCalidad.formatea(valor);
  }

  /// Traduce el texto de un campo de medida a número, tolerando la coma.
  ///
  /// Vacío es `null` —no medido— y no cero: cero es una medida.
  static double? _aNumero(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) {
      return null;
    }
    return double.tryParse(limpio);
  }

  /// Valida las siete medidas y la recolección.
  ///
  /// Ninguna medida es obligatoria —el servidor las admite todas a `null`—, pero
  /// sí se rechaza lo que no es un número, porque eso sí es un error de tecleo y
  /// no una medida ausente. Dejarlo pasar convertiría una letra en un `NaN`
  /// silencioso.
  bool _validar() {
    final errores = <String, String>{};

    if (_recoleccionId == null) {
      errores['recoleccion'] = 'Elige qué recolección se analiza.';
    }

    const campos = <String, String>{
      'grasa': 'Grasa',
      'proteina': 'Proteína',
      'lactosa': 'Lactosa',
      'densidad': 'Densidad',
      'aguaAnadida': 'Agua añadida',
      'ph': 'pH',
    };

    for (final entrada in campos.entries) {
      final texto = _controladorDe(entrada.key).text.trim();
      if (texto.isEmpty) {
        continue;
      }
      if (_aNumero(texto) == null) {
        errores[entrada.key] = 'Eso no es un número.';
      }
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  TextEditingController _controladorDe(String clave) {
    switch (clave) {
      case 'grasa':
        return _grasa;
      case 'proteina':
        return _proteina;
      case 'lactosa':
        return _lactosa;
      case 'densidad':
        return _densidad;
      case 'aguaAnadida':
        return _aguaAnadida;
      default:
        return _ph;
    }
  }

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    // El `usuarioId` es obligatorio pero no es una decisión de quien rellena:
    // sale de la sesión. `usuario` vive en `Autenticado`, no en `AuthState`, así
    // que hay que estrechar el tipo antes de leerlo.
    final estado = ref.read(authControllerProvider);
    if (estado is! Autenticado) {
      setState(() {
        _guardando = false;
        _errorGeneral = 'Tu sesión se ha cerrado. Vuelve a entrar.';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(calidadControllerProvider.notifier);
    final recoleccionId = int.parse(_recoleccionId!);

    final ok = esAlta
        ? await controller.crear(
            recoleccionId: recoleccionId,
            usuarioId: estado.usuario.id,
            resultado: _resultado,
            grasa: _aNumero(_grasa.text),
            proteina: _aNumero(_proteina.text),
            lactosa: _aNumero(_lactosa.text),
            densidad: _aNumero(_densidad.text),
            temperatura: null,
            aguaAnadida: _aNumero(_aguaAnadida.text),
            ph: _aNumero(_ph.text),
          )
        : await controller.editar(
            widget.control!,
            recoleccionId: recoleccionId,
            usuarioId: estado.usuario.id,
            resultado: _resultado,
            grasa: _aNumero(_grasa.text),
            proteina: _aNumero(_proteina.text),
            lactosa: _aNumero(_lactosa.text),
            densidad: _aNumero(_densidad.text),
            temperatura: null,
            aguaAnadida: _aNumero(_aguaAnadida.text),
            ph: _aNumero(_ph.text),
            // El campo de temperatura no tiene caja propia: es el único que se
            // manda siempre a `null` desde aquí, porque la app no lo edita. Los
            // otros seis, en cambio, se limpian cuando el usuario borra el
            // número, y eso hay que decirlo o el valor anterior se queda.
            limpiarGrasa: _grasa.text.trim().isEmpty,
            limpiarProteina: _proteina.text.trim().isEmpty,
            limpiarLactosa: _lactosa.text.trim().isEmpty,
            limpiarDensidad: _densidad.text.trim().isEmpty,
            limpiarAguaAnadida: _aguaAnadida.text.trim().isEmpty,
            limpiarPh: _ph.text.trim().isEmpty,
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
          ref.read(calidadControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = ref.watch(recoleccionesParaAnalizarProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nuevo análisis' : 'Editar análisis'),
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

            disponibles.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las recolecciones.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => _DesplegableRecoleccion(
                valor: _recoleccionId,
                error: _errores['recoleccion'],
                items: _itemsConLaPropia(opciones),
                alCambiar: (v) => setState(() {
                  _recoleccionId = v;
                  _errores.remove('recoleccion');
                }),
              ),
            ),
            const SizedBox(height: Espaciado.sm),
            const AppNotice(
              texto: 'Una recolección solo admite un análisis. Aquí solo salen las '
                  'que todavía no tienen ninguno.',
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('¿Qué salió?'),
            const SizedBox(height: Espaciado.xs),
            Row(
              children: [
                Expanded(
                  child: _Casilla(
                    texto: 'Pura',
                    activo: _resultado == ControlCalidad.pura,
                    onPressed: () => setState(() {
        _resultado = ControlCalidad.pura;
        _resultadoCorregido = true;
      }),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: _Casilla(
                    texto: 'Adulterada',
                    activo: _resultado == ControlCalidad.adulterada,
                    onPressed: () => setState(() {
        _resultado = ControlCalidad.adulterada;
        _resultadoCorregido = true;
      }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('Mediciones'),
            const SizedBox(height: Espaciado.xs),
            const AppNotice(
              texto: 'Todas son opcionales. Lo que se deje en blanco no se guarda, '
                  'y no es lo mismo que medir cero.',
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: Espaciado.sm),

            _Medida(
              etiqueta: 'GRASA %',
              controller: _grasa,
              error: _errores['grasa'],
            ),
            _Medida(
              etiqueta: 'PROTEÍNA %',
              controller: _proteina,
              error: _errores['proteina'],
            ),
            _Medida(
              etiqueta: 'LACTOSA %',
              controller: _lactosa,
              error: _errores['lactosa'],
            ),
            _Medida(
              etiqueta: 'DENSIDAD',
              controller: _densidad,
              error: _errores['densidad'],
            ),
            _Medida(
              etiqueta: 'AGUA AÑADIDA %',
              controller: _aguaAnadida,
              error: _errores['aguaAnadida'],
              // Es una de las dos medidas que la regla mira, así que al escribir
              // se recalcula el veredicto.
              onChanged: (_) => setState(_recalcularResultado),
            ),
            _Medida(
              etiqueta: 'pH',
              controller: _ph,
              error: _errores['ph'],
              onChanged: (_) => setState(_recalcularResultado),
            ),

            const SizedBox(height: Espaciado.xs),
            // Por qué dice lo que dice. Sin esta línea el veredicto aparece de la
            // nada y el laboratorio no tiene forma de saber qué medida mirar.
            _AvisoDelVeredicto(
              resultado: _resultado,
              corregido: _resultadoCorregido,
              aguaAnadida: _numeroDe(_aguaAnadida.text),
              ph: _numeroDe(_ph.text),
            ),

            const SizedBox(height: Espaciado.md),
            AppButton(
              texto: esAlta ? 'Guardar análisis' : 'Guardar cambios',
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

  /// Las opciones del desplegable, más la recolección del control que se edita.
  ///
  /// Se añade aunque no esté entre las libres: es la que ya tiene este control, y
  /// quitarla haría que el formulario mostrara una elección vacía con un valor
  /// guardado dentro. Sus datos vienen del propio control —el backend anida la
  /// recolección—, así que no hace falta ninguna petición extra.
  List<SelectorItem> _itemsConLaPropia(List<Recoleccion> libres) {
    final items = libres
        .map((r) => SelectorItem(
              id: r.id.toString(),
              // **El proveedor va delante** porque es lo que dice de quién es el
              // análisis: fecha y litros se parecen entre sí y hay que leerlos
              // enteros para distinguirlos, el nombre no se parece a nada de lo
              // demás. El backend ya anida el proveedor en cada recolección, así
              // que esto no cuesta ninguna petición.
              etiqueta: '${r.proveedor?.nombreCompleto ?? 'Proveedor #${r.proveedorId}'} · ${r.fecha} · ${r.cantidadFormateada}',
            ))
        .toList();

    final control = widget.control;
    final propia = control?.recoleccion;
    if (control == null || propia == null) {
      return items;
    }

    if (items.any((i) => i.id == control.recoleccionId.toString())) {
      return items;
    }

    final litros = propia.litrosLegibles;
    return [
      ...items,
      SelectorItem(
        id: control.recoleccionId.toString(),
        etiqueta: '${propia.fecha}${litros == null ? '' : ' · $litros'} (esta)',
      ),
    ];
  }
}

/// Por qué el veredicto dice lo que dice.
///
/// Three cosas distintas en un solo sitio, porque es lo que hay que distinguir:
/// lo que propuso la regla, lo que corrigió una persona y por qué.
/// El texto cambia de color con el veredicto: un «pura» y un «adulterada» no se
/// leen igual de lejos, y esto se mira de pie en una planta.
class _AvisoDelVeredicto extends StatelessWidget {
  const _AvisoDelVeredicto({
    required this.resultado,
    required this.corregido,
    this.aguaAnadida,
    this.ph,
  });

  final String resultado;

  /// `true` cuando una persona lo cambió a mano y la regla ya no manda.
  final bool corregido;

  final double? aguaAnadida;
  final double? ph;

  @override
  Widget build(BuildContext context) {
    final adulterada = resultado == ControlCalidad.adulterada;

    // Con la corrección a mano se dice, porque si no el laboratorio ve un
    // veredicto que contradice las medidas de arriba y no sabe por qué.
    final texto = corregido
        ? 'Puesto a mano. La app ya no lo recalcula.'
        : motivoDe(resultado, aguaAnadida: aguaAnadida, ph: ph);

    return AppNotice(
      texto: texto,
      color: corregido
          ? CupertinoColors.systemBlue
          : adulterada
              ? CupertinoColors.systemRed
              : CupertinoColors.systemGreen,
    );
  }
}

/// Un campo de medida: etiqueta, número y error debajo.
class _Medida extends StatelessWidget {
  const _Medida({
    required this.etiqueta,
    required this.controller,
    this.error,
    this.onChanged,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String? error;

  /// Se llama en cada tecla. Lo usan el agua añadida y el pH para recalcular el
  /// veredicto; las otras cinco medidas no lo necesitan porque la regla no las mira.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          etiqueta: etiqueta,
          controller: controller,
          placeholder: '—',
          icon: CupertinoIcons.waveform_path_ecg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: onChanged,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Espaciado.xs, left: Espaciado.xs),
            child: Text(
              error!,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
            ),
          ),
      ],
    );
  }
}

/// Desplegable de recolección con obligatorio y error debajo.
class _DesplegableRecoleccion extends StatelessWidget {
  const _DesplegableRecoleccion({
    required this.valor,
    required this.error,
    required this.items,
    required this.alCambiar,
  });

  final String? valor;
  final String? error;
  final List<SelectorItem> items;
  final ValueChanged<String?> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelector(
          etiqueta: 'RECOLECCIÓN',
          valor: valor ?? '',
          vacio: items.isEmpty ? 'No hay recolecciones sin analizar' : 'Elige la recolección',
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
      color: activo
          ? (texto == 'Pura' ? AppTheme.verde : CupertinoColors.systemRed)
          : CupertinoColors.white,
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

/// Un hueco girando mientras llegan las recolecciones.
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