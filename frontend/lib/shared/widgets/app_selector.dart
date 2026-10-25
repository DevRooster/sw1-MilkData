import 'package:flutter/cupertino.dart';

import '../../core/theme/app_theme.dart';

/// Un valor de un [AppSelector].
class SelectorItem {
  const SelectorItem({required this.id, required this.etiqueta});

  final String id;
  final String etiqueta;
}

/// Selector desplegable con hoja modal y rueda, al estilo de iOS.
///
/// Lleva dentro su botón **Listo**. Fuera de él, en iOS no hay forma de cerrar
/// la hoja y quien la abrió se queda atrapado.
class AppSelector extends StatelessWidget {
  const AppSelector({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.items,
    required this.onChanged,
    this.vacio = 'Elige una opción',
    this.limpiar,
  });

  /// Texto sobre el campo, en mayúsculas.
  final String etiqueta;

  /// Id del valor elegido, o `null` si no hay ninguno.
  final String? valor;

  final List<SelectorItem> items;

  final ValueChanged<String?> onChanged;

  /// Lo que se ve cuando no hay nada elegido.
  final String vacio;

  /// Ponerlo pone una X dentro del campo que devuelve el valor a "nada".
  ///
  /// Sirve cuando el selector filtra y de verdad hace falta volver atrás. Sin
  /// él, quitar un filtro obliga a abrir la hoja y buscar la opción, que en un
  /// filtro son varios toques para deshacer lo que se hizo en uno.
  final VoidCallback? limpiar;

  @override
  Widget build(BuildContext context) {
    final seleccionado = items.where((i) => i.id == valor).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        GestureDetector(
          // **Sin nada que elegir no se abre nada.** Una hoja con una rueda sin
          // opciones sale en blanco, y quien la abre ve una pantalla vacía que
          // parece un fallo —cuando lo que pasa es que no hay nada. Se vio en
          // "Nuevo recorrido": en una planta recién creada no hay rutas y la
          // hoja salía blanca sin una palabra.
          onTap: items.isEmpty ? null : () => _abrirHoja(context, seleccionado),
          // `opaque` hace que el botón reciba el toque en toda su superficie. Sin
          // esto, `deferToChild` lo deja pasar si ningún hijo lo atrapa, y en
          // una zona vacía el selector parecería no responder.
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: Espaciado.altoCampo,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: Espaciado.md),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(Espaciado.radio),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
            // No puede ser `const`: depende del valor elegido.
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    seleccionado?.etiqueta ?? vacio,
                    style: TextStyle(
                      fontSize: 15,
                      color: seleccionado == null
                          ? CupertinoColors.tertiaryLabel
                          : CupertinoColors.label,
                    ),
                  ),
                ),
                if (limpiar != null)
                  CupertinoButton(
                    // Sin `minSize`: el CupertinoButton por defecto mide 44x44
                    // y en una fila de filtros descuadraría la caja.
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    onPressed: limpiar,
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 19,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                const SizedBox(width: Espaciado.xs),
                const Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _abrirHoja(BuildContext context, SelectorItem? seleccionado) {
    var indiceInicial = items.indexWhere((i) => i.id == seleccionado?.id);
    if (indiceInicial < 0) {
      indiceInicial = 0;
    }

    var indice = indiceInicial;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (contexto) => Container(
        height: 260,
        color: CupertinoColors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(contexto).pop(),
                    child: const Text('Cancelar'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      onChanged(items[indice].id);
                      Navigator.of(contexto).pop();
                    },
                    child: const Text(
                      'Listo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: indiceInicial,
                  ),
                  itemExtent: 34,
                  onSelectedItemChanged: (i) => indice = i,
                  children: items.map((i) => Center(child: Text(i.etiqueta))).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
