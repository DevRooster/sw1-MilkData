import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../proveedores/presentation/providers/proveedores_controller.dart';
import '../data/reporte_api.dart';
import '../domain/reporte.dart';
import 'providers/reportes_controller.dart';

/// Los cuatro reportes de la planta.
///
/// **Todos de solo lectura y todos bajo el mismo permiso**, `reportes`. Es
/// deliberado: una pantalla que mezclase módulos con permisos distintos
/// devolvería "no se ve" sin decir cuál, y eso no se puede diagnosticar.
///
/// Tres pestañas —contraste, calidad y calidad por proveedor— en vez de una por
/// endpoint: son cuatro consultas distintas contra tablas distintas, y se piden
/// **solo cuando se abre la pestaña**, no las cuatro al entrar.
class ReportesPage extends ConsumerStatefulWidget {
  const ReportesPage({super.key});

  @override
  ConsumerState<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends ConsumerState<ReportesPage> {
  @override
  void initState() {
    super.initState();
    // La carga va aquí y no en el `build` del controlador: el módulo solo se pide
    // si alguien abre la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaitedCargar();
      }
    });
  }

  void unawaitedCargar() {
    ref.read(reportesControllerProvider.notifier).cargar();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(reportesControllerProvider);
    final controller = ref.read(reportesControllerProvider.notifier);
    final proveedores = ref.watch(opcionesDeProveedorProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Reportes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: estado.cargando ? null : unawaitedCargar,
          child: estado.cargando
              ? const CupertinoActivityIndicator(radius: 9)
              : const Icon(CupertinoIcons.refresh),
        ),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Selector(
              tipo: estado.tipo,
              onChanged: controller.ver,
            ),

            if (estado.tipo == TipoReporte.calidad)
              Padding(
                padding: const EdgeInsets.fromLTRB(Espaciado.md, 0, Espaciado.md, Espaciado.sm),
                child: AppSelector(
                  etiqueta: 'PROVEEDOR',
                  valor: estado.proveedorId?.toString() ?? '',
                  vacio: 'Toda la planta',
                  items: [
                    const SelectorItem(id: '', etiqueta: 'Toda la planta'),
                    for (final proveedor in proveedores.maybeWhen(
                      data: (lista) => lista,
                      orElse: () => const <ReferenciaProveedor>[],
                    ))
                      SelectorItem(
                        id: proveedor.id.toString(),
                        etiqueta: proveedor.nombreCompleto,
                      ),
                  ],
                  limpiar: estado.proveedorId == null ? null : controller.verTodaLaPlanta,
                  onChanged: (valor) {
                    final id = int.tryParse(valor ?? '');
                    if (id == null) {
                      controller.verTodaLaPlanta();
                    } else {
                      controller.verProveedor(id);
                    }
                  },
                ),
              ),

            Expanded(
              child: estado.cargando && estado.total == 0
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(estado: estado, controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las tres pestañas, al estilo de iOS.
class _Selector extends StatelessWidget {
  const _Selector({required this.tipo, required this.onChanged});

  final TipoReporte tipo;
  final ValueChanged<TipoReporte> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemGroupedBackground,
      padding: const EdgeInsets.fromLTRB(
        Espaciado.md,
        Espaciado.sm,
        Espaciado.md,
        Espaciado.sm,
      ),
      child: CupertinoSlidingSegmentedControl<TipoReporte>(
        groupValue: tipo,
        onValueChanged: (valor) {
          if (valor != null) {
            onChanged(valor);
          }
        },
        children: {
          for (final t in TipoReporte.values)
            t: Padding(
              padding: const EdgeInsets.symmetric(vertical: Espaciado.xs),
              child: Text(t.etiqueta, style: const TextStyle(fontSize: 13)),
            ),
        },
      ),
    );
  }
}

/// El cuerpo: o vacío, o las filas del reporte que toca.
class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.estado, required this.controller});

  final ReportesState estado;
  final ReportesController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.vacio) {
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(texto: _vacioDe(estado)),
          const SizedBox(height: Espaciado.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espaciado.xl),
            child: Text(
              estado.tipo.descripcion,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Espaciado.md,
        Espaciado.sm,
        Espaciado.md,
        Espaciado.xl,
      ),
      itemCount: estado.filasVisibles.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.filasVisibles.length) {
          return _Pie(estado: estado, controller: controller);
        }

        final fila = estado.filasVisibles[indice];
        if (fila is FilaContraste) {
          return _FilaContraste(fila: fila);
        }
        if (fila is FilaCalidad) {
          return _FilaCalidad(fila: fila, nombreProveedor: estado.nombreProveedor);
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Por qué no hay nada, que **no es lo mismo para los tres reportes**.
  String _vacioDe(ReportesState estado) {
    switch (estado.tipo) {
      case TipoReporte.contraste:
        return 'Todavía no hay recolecciones que contrastar.';
      case TipoReporte.calidad:
        // Una fila con cero muestras es distinto de una lista vacía, y el texto
        // tiene que distinguirlo: cero muestras significa que nadie ha analizado
        // nada, no que la leche esté mal.
        return estado.calidad?.sinAnalisis ?? false
            ? 'No hay ningún análisis de calidad todavía.'
            : 'Sin datos para este proveedor.';
      case TipoReporte.calidadPorProveedor:
        return 'Ningún proveedor tiene análisis de calidad.';
    }
  }
}

/// El pie: cuántas filas y la recarga.
class _Pie extends StatelessWidget {
  const _Pie({required this.estado, required this.controller});

  final ReportesState estado;
  final ReportesController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${estado.total} fila${estado.total == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: Espaciado.sm),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: estado.cargando ? null : controller.cargar,
          child: estado.cargando
              ? const CupertinoActivityIndicator(radius: 9)
              : const Text('Actualizar'),
        ),
      ],
    );
  }
}

/// Una fila del contraste: lo que se recogió, lo que entró y qué faltó.
class _FilaContraste extends StatelessWidget {
  const _FilaContraste({required this.fila});

  final FilaContraste fila;

  @override
  Widget build(BuildContext context) {
    final porcentaje = fila.porcentajeLegible;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila.fechaLegible,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Proveedor #${fila.proveedorId}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              // La diferencia es la cifra del reporte, así que va sola a la
              // derecha y en grande. Con signo, porque el signo es el mensaje.
              Text(
                fila.diferenciaLegible,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fila.hayFaltante
                      ? CupertinoColors.systemRed
                      : fila.hayExceso
                          ? CupertinoColors.systemOrange
                          : AppTheme.verde,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: Espaciado.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Campo ${_litros(fila.cantidadCampo)}   →   Planta ${_litros(fila.cantidadPlanta)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              // Sin porcentaje no se pone un guion suelto: se dice por qué.
              if (porcentaje != null)
                AppPill(
                  texto: porcentaje,
                  color: fila.hayFaltante
                      ? CupertinoColors.systemRed
                      : fila.hayExceso
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemGreen,
                )
              else
                const AppPill(
                  texto: 'sin datos en campo',
                  color: CupertinoColors.systemGrey,
                ),
            ],
          ),

          if (fila.hayFaltante || fila.hayExceso) ...[
            const SizedBox(height: Espaciado.sm),
            AppNotice(
              texto: fila.hayFaltante
                  ? 'Se recogieron más litros de los que entraron en la planta.'
                  : 'Entró más leche de la que se recogió en el campo.',
              color: CupertinoColors.systemOrange,
            ),
          ],
        ],
      ),
    );
  }

  static String _litros(double valor) {
    if (valor == valor.truncateToDouble()) {
      return '${valor.truncate()} L';
    }
    return '${valor.toStringAsFixed(1).replaceAll('.', ',')} L';
  }
}

/// Una fila de calidad: los promedios de las siete medidas.
class _FilaCalidad extends StatelessWidget {
  const _FilaCalidad({required this.fila, this.nombreProveedor});

  final FilaCalidad fila;

  /// El nombre del proveedor, si esta fila es de uno concreto.
  final String? nombreProveedor;

  @override
  Widget build(BuildContext context) {
    if (fila.sinAnalisis) {
      // **Cero muestras no es "la leche está mal": es que nadie ha analizado.**
      // Enseñar los promedios a cero daría a entender lo contrario.
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreProveedor ?? fila.nombreProveedor ?? 'Toda la planta',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Espaciado.sm),
            const AppNotice(
              texto: 'Sin ningún análisis de calidad. Cero muestras no significa '
                  'que la leche esté mal: significa que no se ha analizado.',
              color: CupertinoColors.systemOrange,
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombreProveedor ?? fila.nombreProveedor ?? 'Toda la planta',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              AppPill(
                texto: '${fila.muestras} análisis',
                color: CupertinoColors.systemBlue,
              ),
            ],
          ),
          const SizedBox(height: Espaciado.sm),
          Wrap(
            spacing: Espaciado.xs,
            runSpacing: Espaciado.xs,
            children: [
              for (final medida in fila.promediosInformativos)
                AppPill(
                  texto: '${medida.key} ${formateaMedida(medida.value)}',
                  color: CupertinoColors.systemGrey,
                ),
            ],
          ),
        ],
      ),
    );
  }
}