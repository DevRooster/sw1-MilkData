import 'package:flutter/cupertino.dart';

import '../../core/theme/app_theme.dart';

/// Campo de hora con rueda, al estilo de los formularios de iOS.
///
/// Existe porque escribir una hora a mano pide un formato —`06:00`— que hay que
/// acertar, y fallar da un error rojo que no explica cuál de las dos partes está
/// mal. Con la rueda no hay formato que acertar: hay dos ruedas y se giran.
///
/// **No es un `CupertinoTextField`.** Es un botón que abre una hoja con el
/// `CupertinoPicker`. Un `CupertinoTextField` de solo lectura no serviría —
///estaría escribiendo en un campo que no deja escribir— y uno editable daría
/// justo el problema que viene a quitar.
class AppTimeField extends StatelessWidget {
  const AppTimeField({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.icon,
    this.errorText,
    this.vacio = 'Elige una hora',
    this.minutos = 5,
  });

  /// Hora elegida en formato largo, `HH:MM:SS`, o `null` si no hay ninguna.
  final String? valor;

  /// Recibe `HH:MM:SS` o `null` al quitar la hora.
  final ValueChanged<String?> onChanged;

  final String etiqueta;
  final IconData? icon;
  final String? errorText;

  /// Lo que se ve cuando no hay hora puesta.
  final String vacio;

  /// De cuánto en cuánto se puede girar la rueda de minutos.
  ///
  /// Cinco minutos es lo que se usa en una operativa real y, además, hace que la
  /// hoja no tenga sesenta filas. Se puede bajar a uno para cuando el minuto
  /// importa.
  final int minutos;

  @override
  Widget build(BuildContext context) {
    final tieneError = errorText != null && errorText!.isNotEmpty;
    final puesto = valor != null && valor!.isNotEmpty;

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
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _abrirHoja(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaciado.md,
                    vertical: Espaciado.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(Espaciado.radio),
                    border: Border.all(
                      color: tieneError
                          ? CupertinoColors.systemRed
                          : const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: CupertinoColors.secondaryLabel),
                        const SizedBox(width: Espaciado.sm),
                      ],
                      Expanded(
                        child: Text(
                          puesto ? horaLegible(valor!) : vacio,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            // El gris es el de los campos vacíos de iOS, no el
                            // de un campo deshabilitado: la hora se puede
                            // poner, así que no parece que no se pueda.
                            color: puesto
                                ? CupertinoColors.label
                                : CupertinoColors.placeholderText,
                          ),
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_up_chevron_down,
                        size: 14,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (puesto)
              CupertinoButton(
                padding: const EdgeInsets.only(left: Espaciado.sm),
                // El botón por defecto mide 44x44 y en una fila con otro campo
                // descuadraría la caja.
                minimumSize: const Size(32, 32),
                onPressed: () => onChanged(null),
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 19,
                  color: CupertinoColors.systemGrey,
                ),
              ),
          ],
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

  Future<void> _abrirHoja(BuildContext context) async {
    final elegida = await showCupertinoModalPopup<_Hora>(
      context: context,
      builder: (d) => _HojaHora(
        inicial: valor,
        minutos: minutos,
      ),
    );

    if (elegida != null) {
      onChanged(elegida.larga);
    }
  }
}

/// Una hora: partes sueltas, y las dos formas de escribirla.
class _Hora {
  const _Hora(this.hora, this.minuto);

  final int hora;
  final int minuto;

  String get larga =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}:00';
}

/// La hoja con las dos ruedas y el botón de listo.
class _HojaHora extends StatefulWidget {
  const _HojaHora({required this.inicial, required this.minutos});

  final String? inicial;
  final int minutos;

  @override
  State<_HojaHora> createState() => _HojaHoraState();
}

class _HojaHoraState extends State<_HojaHora> {
  late int _hora;
  late int _minuto;

  /// Controladores propios de cada rueda.
  ///
  /// Son dos y no uno compartido porque van a distinta velocidad, y hacerlos
  /// con un solo `FixedExtentScrollController` haría que girar los minutos
  /// moviera también las horas.
  late final FixedExtentScrollController _cHora = FixedExtentScrollController(
    initialItem: _hora,
  );
  late final FixedExtentScrollController _cMinuto = FixedExtentScrollController(
    initialItem: widget.minutos == 0 ? 0 : _minuto ~/ widget.minutos,
  );

  @override
  void initState() {
    super.initState();

    // Una hora que no se puede partir deja la rueda en las doce. Es el mismo
    // sitio donde estaría la hoja modal, que es la hora de apertura de la
    // planta, así que no se elige un valor absurdo sin querer.
    final partes = partirHora(widget.inicial) ?? (0, 0);
    _hora = partes.$1;
    _minuto = partes.$2;
  }

  @override
  void dispose() {
    _cHora.dispose();
    _cMinuto.dispose();
    super.dispose();
  }

  int get _pasosMinuto => widget.minutos == 0 ? 60 : 60 ~/ widget.minutos;

  List<int> get _minutosPosibles => List<int>.generate(_pasosMinuto, (i) => i * widget.minutos);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // El botón de listo va arriba y no abajo: en una hoja modal el pulgar
            // tapa la parte de abajo, y arriba siempre se ve.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(_Hora(_hora, _minuto)),
                  child: const Text(
                    'Listo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _Rueda(
                      controlador: _cHora,
                      cantidad: 24,
                      etiqueta: (i) => i.toString().padLeft(2, '0'),
                      alCambiar: (i) => setState(() => _hora = i),
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFFE5E5EA)),
                  Expanded(
                    child: _Rueda(
                      controlador: _cMinuto,
                      cantidad: _pasosMinuto,
                      etiqueta: (i) => _minutosPosibles[i].toString().padLeft(2, '0'),
                      alCambiar: (i) => setState(
                        () => _minuto = _minutosPosibles[i.clamp(0, _pasosMinuto - 1)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una rueda: una lista de `cantidad` elementos con la etiqueta que toque.
class _Rueda extends StatelessWidget {
  const _Rueda({
    required this.controlador,
    required this.cantidad,
    required this.etiqueta,
    required this.alCambiar,
  });

  final FixedExtentScrollController controlador;
  final int cantidad;
  final String Function(int) etiqueta;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controlador,
      itemExtent: 36,
      // 5 filas visibles: la del centro es la elegida y se ve elegida por el
      // alto de la hoja, no por un resaltado que habría que dibujar aparte.
      onSelectedItemChanged: alCambiar,
      children: List<Widget>.generate(
        cantidad,
        (i) => Center(
          child: Text(
            etiqueta(i),
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}

/// `06:00:00` pasa a `06:00`, que es como se lee una hora.
///
/// Vive aquí y no en cada formulario porque Rutas, Zonas y Recorridos enseñan la
/// misma hora en cuatro sitios, y cuatro copias de este `substring` acabarían
/// divergiendo en cuanto una cambiara.
String horaLegible(String? valor) {
  final partes = partirHora(valor);
  if (partes == null) {
    return '';
  }
  return '${partes.$1.toString().padLeft(2, '0')}:${partes.$2.toString().padLeft(2, '0')}';
}

/// Descompone `HH:MM:SS` en hora y minuto.
///
/// Devuelve `null` si no se puede, para que quien llame decida qué hacer con un
/// valor raro en vez de recibir un cero y no enterarse.
(int, int)? partirHora(String? valor) {
  if (valor == null || valor.isEmpty) {
    return null;
  }

  final partes = valor.split(':');
  if (partes.length < 2) {
    return null;
  }

  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) {
    return null;
  }

  return (h.clamp(0, 23), m.clamp(0, 59));
}

/// `HH:MM` o `HH:MM:SS` pasa a `HH:MM:SS`, que es lo que guarda la base.
///
/// Devuelve `null` si viene vacía, que es lo que significa "sin hora".
String? horaLarga(String? valor) {
  if (valor == null || valor.trim().isEmpty) {
    return null;
  }

  final partes = partirHora(valor);
  if (partes == null) {
    return null;
  }

  return '${partes.$1.toString().padLeft(2, '0')}:'
      '${partes.$2.toString().padLeft(2, '0')}:00';
}

/// Dos horas ordenables, para el "la final va después de la inicial".
///
/// Compara los minutos desde medianoche en vez de comparar cadenas, porque
/// `10:00` y `9:00` como texto salen en el orden equivocado.
int? minutosDesdeMedianoche(String? valor) {
  final partes = partirHora(valor);
  if (partes == null) {
    return null;
  }
  return partes.$1 * 60 + partes.$2;
}

/// El error si la hora final no es posterior a la inicial, o `null` si lo es.
///
/// Vive aquí y no en cada formulario por dos razones. La primera es que Rutas,
/// Zonas y Recorridos tienen exactamente la misma regla, y tres copias
/// divergirían en cuanto una se cambiara. La segunda es que **es una función y
/// no una línea dentro de `_validar`**: una regla metida en el `build` de un
/// widget solo se puede probar montando el widget y arrastrando una rueda, que
/// en pruebas no es determinista.
String? errorDeRangoHoras(String? desde, String? hasta) {
  final a = minutosDesdeMedianoche(desde);
  final b = minutosDesdeMedianoche(hasta);

  // Falta una de las dos: no hay rango que comprobar. La rueda permite no poner
  // ninguna, y eso no es un error.
  if (a == null || b == null) {
    return null;
  }

  if (b > a) {
    return null;
  }

  return 'La hora final debe ser posterior a la inicial.';
}
