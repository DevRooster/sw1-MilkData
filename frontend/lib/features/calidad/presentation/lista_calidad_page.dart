import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/control_calidad.dart';
import 'providers/calidad_controller.dart';
import 'calidad_form_page.dart';

/// Lista de controles de calidad.
///
/// Cada fila dice de qué recolección es el análisis, cuántos litros tenía esa
/// recogida y qué veredicto dio. El veredicto va en grande y con color porque es
/// lo único de esta pantalla que se mira de un vistazo.
class CalidadPage extends ConsumerStatefulWidget {
  const CalidadPage({super.key});

  @override
  ConsumerState<CalidadPage> createState() => _CalidadPageState();
}

class _CalidadPageState extends ConsumerState<CalidadPage> {
  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(calidadControllerProvider);
    final controller = ref.read(calidadControllerProvider.notifier);
    final filtros = ref.watch(filtrosCalidadProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Calidad'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('calidad', 'write')
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: () => _abrirFormulario(context),
                child: const Icon(CupertinoIcons.add),
              )
            : null,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Filtros(
              resultado: filtros.resultado,
              onResultado: controller.filtrarPorResultado,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),
            Expanded(
              child: estado.cargando && estado.controles.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('calidad', 'write'),
                      controller: controller,
                      onEditar: (c) => _abrirFormulario(context, control: c),
                      onEliminar: (c) => _confirmarBorrado(context, c),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {ControlCalidad? control}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => CalidadFormPage(control: control),
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext contexto, ControlCalidad control) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar este análisis?'),
        content: Text(
          'La recolección del ${control.recoleccion?.fecha ?? '?'} se quedará '
          'sin análisis. No se puede deshacer.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await ref.read(calidadControllerProvider.notifier).eliminar(control);
    }
  }
}

/// Fila de filtros: el veredicto, y nada más.
class _Filtros extends StatelessWidget {
  const _Filtros({required this.resultado, required this.onResultado, required this.onLimpiar});

  /// Viene de la pantalla, que ya lo tiene leído. Un `StatelessWidget` no puede
  /// leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final String? resultado;

  final ValueChanged<String?> onResultado;

  /// Quita el filtro. `null` cuando no hay ninguno puesto.
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.datos.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        Espaciado.md,
        Espaciado.sm,
        Espaciado.md,
        Espaciado.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppSelector(
              etiqueta: 'VEREDICTO',
              valor: resultado ?? '',
              items: const [
                SelectorItem(id: '', etiqueta: 'Todos'),
                SelectorItem(id: ControlCalidad.pura, etiqueta: 'Pura'),
                SelectorItem(id: ControlCalidad.adulterada, etiqueta: 'Adulterada'),
              ],
              vacio: 'Todos',
              limpiar: resultado == null ? null : () => onResultado(null),
              onChanged: (valor) => onResultado(valor == null || valor.isEmpty ? null : valor),
            ),
          ),
          if (onLimpiar != null)
            CupertinoButton(
              padding: const EdgeInsets.only(left: Espaciado.sm),
              // El botón por defecto mide 44x44 y en esta fila descuadraría la
              // caja.
              minimumSize: const Size(32, 32),
              onPressed: onLimpiar,
              child: const Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 19,
                color: CupertinoColors.systemGrey,
              ),
            ),
        ],
      ),
    );
  }
}

/// El cuerpo de la lista: o vacío, o las filas con su paginación.
class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.estado,
    required this.hayFiltro,
    required this.puedeEscribir,
    required this.controller,
    required this.onEditar,
    required this.onEliminar,
  });

  final CalidadState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final CalidadController controller;
  final ValueChanged<ControlCalidad> onEditar;
  final ValueChanged<ControlCalidad> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.controles.isEmpty) {
      // Distinguir "no hay análisis" de "no hay ninguno con ese veredicto" son
      // dos problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún análisis con ese veredicto.'
                : 'Todavía no se ha analizado ninguna recolección.',
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
      itemCount: estado.controles.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.controles.length) {
          // El pie lleva el resumen, la paginación y la recarga.
          // `RefreshIndicator` es de Material y esta app es Cupertino.
          return Column(
            children: [
              _Resumen(estado: estado),
              const SizedBox(height: Espaciado.sm),
              _Paginacion(estado: estado, controller: controller),
              const SizedBox(height: Espaciado.sm),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: estado.cargando ? null : controller.refrescar,
                child: estado.cargando
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Text('Actualizar'),
              ),
            ],
          );
        }

        final control = estado.controles[indice];
        return _FilaControl(
          control: control,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(control),
          onEliminar: () => onEliminar(control),
        );
      },
    );
  }
}

/// "2 de 10 salen adulterados en esta página".
class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final CalidadState estado;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${estado.adulterados} de ${estado.controles.length} adulterados en esta página'
      ' · ${estado.total} en total',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
    );
  }
}

/// Un análisis: su veredicto, de qué recolección es y qué se midió.
class _FilaControl extends StatelessWidget {
  const _FilaControl({
    required this.control,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final ControlCalidad control;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final recoleccion = control.recoleccion;
    final litros = recoleccion?.litrosLegibles;

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
                      recoleccion == null
                          ? 'Recolección #${control.recoleccionId}'
                          : '${litros == null ? '' : '$litros · '}recolección del ${recoleccion.fecha}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      control.usuario?.nombreCompleto ?? 'Laboratorio #${control.usuarioId}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              AppPill(
                texto: control.esAdulterada ? 'adulterada' : 'pura',
                color: control.esAdulterada
                    ? CupertinoColors.systemRed
                    : CupertinoColors.systemGreen,
              ),
            ],
          ),

          if (control.tieneMedidas) ...[
            const SizedBox(height: Espaciado.sm),
            Wrap(
              spacing: Espaciado.xs,
              runSpacing: Espaciado.xs,
              children: [
                for (final medida in control.medidasInformativas)
                  AppPill(
                    texto: '${medida.key} ${ControlCalidad.formatea(medida.value!)}',
                    color: CupertinoColors.systemGrey,
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: Espaciado.sm),
            // Un veredicto sin ninguna medida no dice nada: la fila lo dice en
            // lugar de dejar siete campos en blanco que parecen un fallo.
            const AppNotice(
              texto: 'Sin mediciones: solo consta el veredicto.',
              color: CupertinoColors.systemOrange,
            ),
          ],

          if (puedeEscribir) ...[
            const SizedBox(height: Espaciado.sm),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: Espaciado.sm),
                    color: AppTheme.verde.withValues(alpha: 0.12),
                    onPressed: onEditar,
                    child: const Text(
                      'Editar',
                      style: TextStyle(color: AppTheme.verde, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaciado.md,
                    vertical: Espaciado.sm,
                  ),
                  color: CupertinoColors.white,
                  onPressed: onEliminar,
                  child: const Icon(
                    CupertinoIcons.trash,
                    size: 18,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final CalidadState estado;
  final CalidadController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} análisis${estado.total == 1 ? '' : 'es'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: estado.hayAnterior ? () => controller.irAPagina(estado.pagina - 1) : null,
          child: const Icon(CupertinoIcons.chevron_left, size: 20),
        ),
        Text(
          'Página ${estado.pagina} de ${estado.totalPaginas}',
          style: const TextStyle(fontSize: 14),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: estado.haySiguiente ? () => controller.irAPagina(estado.pagina + 1) : null,
          child: const Icon(CupertinoIcons.chevron_right, size: 20),
        ),
      ],
    );
  }
}
