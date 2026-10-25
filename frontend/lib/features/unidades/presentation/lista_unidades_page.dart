import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/unidad.dart';
import 'providers/unidades_controller.dart';
import 'unidad_form_page.dart';

/// Lista de unidades de la planta.
///
/// Cada fila lleva las acciones de esa unidad: editar y eliminar. El botón de la
/// barra de navegación abre el alta.
class UnidadesPage extends ConsumerStatefulWidget {
  const UnidadesPage({super.key});

  @override
  ConsumerState<UnidadesPage> createState() => _UnidadesPageState();
}

class _UnidadesPageState extends ConsumerState<UnidadesPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(unidadesControllerProvider);
    final controller = ref.read(unidadesControllerProvider.notifier);
    final filtros = ref.watch(filtrosUnidadesProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Unidades'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('unidades', 'write')
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
              busqueda: _ctrlBusqueda,
              onBusqueda: controller.buscar,
              onTipo: controller.filtrarPorTipo,
              onInactivas: controller.alternarSoloInactivos,
              onCerradas: controller.alternarSoloCerradas,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.unidades.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('unidades', 'write'),
                      controller: controller,
                      onEditar: (unidad) => _abrirFormulario(context, unidad: unidad),
                      onEliminar: (unidad) => _confirmarBorrado(context, unidad),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el formulario, para alta o para edición.
  void _abrirFormulario(BuildContext contexto, {Unidad? unidad}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => UnidadFormPage(unidad: unidad),
      ),
    );
  }

  /// Borrar pide confirmación y avisa de que no se puede deshacer.
  ///
  /// El aviso dice además que las recolecciones guardan la unidad: quien lo borre
  /// no borra el historial, pero sí se queda sin ese dato en las pantallas
  /// viejas.
  Future<void> _confirmarBorrado(BuildContext contexto, Unidad unidad) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar ${unidad.nombre}?'),
        content: const Text(
          'No se puede deshacer. Las recolecciones que guardaron esta unidad '
          'seguirán allí, pero sin ella.',
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
      await ref.read(unidadesControllerProvider.notifier).eliminar(unidad);
    }
  }
}

/// Fila de filtros: búsqueda, tipo, y las dos casillas.
class _Filtros extends ConsumerWidget {
  const _Filtros({
    required this.busqueda,
    required this.onBusqueda,
    required this.onTipo,
    required this.onInactivas,
    required this.onCerradas,
    required this.onLimpiar,
  });

  final TextEditingController busqueda;
  final ValueChanged<String> onBusqueda;
  final ValueChanged<TipoUnidad?> onTipo;
  final VoidCallback onInactivas;
  final VoidCallback onCerradas;

  /// Quita todos los filtros. `null` cuando no hay ninguno puesto.
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosUnidadesProvider);

    return Container(
      color: AppTheme.datos.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        Espaciado.md,
        Espaciado.sm,
        Espaciado.md,
        Espaciado.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  etiqueta: 'BUSCAR',
                  controller: busqueda,
                  placeholder: 'Nombre de la unidad',
                  icon: CupertinoIcons.search,
                  onChanged: onBusqueda,
                ),
              ),
              if (onLimpiar != null)
                CupertinoButton(
                  padding: const EdgeInsets.only(left: Espaciado.sm),
                  // El botón por defecto mide 44x44 y en esta fila descuadraría
                  // la caja.
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
          const SizedBox(height: Espaciado.sm),
          Row(
            children: [
              Expanded(
                child: AppSelector(
                  etiqueta: 'TIPO',
                  // Sin filtro es `null`, y "Todos" es la primera opción de la
                  // hoja: si no fuera una opción de verdad, elegir un tipo sería
                  // una puerta de sentido único.
                  valor: filtros.tipo?.valor ?? '',
                  items: [
                    const SelectorItem(id: '', etiqueta: 'Todos'),
                    ...TipoUnidad.values.map(
                      (t) => SelectorItem(id: t.valor, etiqueta: t.etiqueta),
                    ),
                  ],
                  vacio: 'Todos',
                  limpiar: filtros.tipo == null ? null : () => onTipo(null),
                  onChanged: (valor) {
                    if (valor == null || valor.isEmpty) {
                      onTipo(null);
                    } else {
                      onTipo(TipoUnidad.desdeTexto(valor));
                    }
                  },
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              // Las dos de al lado son casillas, no selectores: tienen dos
              // estados y un selector de dos opciones sería un rodeo.
              _Casilla(
                texto: 'Inactivas',
                activo: filtros.soloInactivos,
                onPressed: onInactivas,
              ),
              const SizedBox(width: Espaciado.xs),
              _Casilla(
                texto: 'Cerradas',
                activo: filtros.soloCerradas,
                onPressed: onCerradas,
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: Espaciado.sm),
      color: activo ? AppTheme.verde : CupertinoColors.white,
      onPressed: onPressed,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
          color: activo ? CupertinoColors.white : CupertinoColors.label,
        ),
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

  final UnidadesState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final UnidadesController controller;
  final ValueChanged<Unidad> onEditar;
  final ValueChanged<Unidad> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.unidades.isEmpty) {
      // Distinguir "no hay unidades" de "no hay ninguna que coincida" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ninguna unidad coincide con el filtro.'
                : 'Esta planta todavía no tiene unidades.',
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
      itemCount: estado.unidades.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.unidades.length) {
          // El pie lleva paginación y recarga. `RefreshIndicator` es de Material
          // y aquí la app es Cupertino.
          return Column(
            children: [
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

        final unidad = estado.unidades[indice];
        return _FilaUnidad(
          unidad: unidad,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(unidad),
          onEliminar: () => onEliminar(unidad),
        );
      },
    );
  }
}

/// Una unidad con sus datos y sus acciones.
class _FilaUnidad extends StatelessWidget {
  const _FilaUnidad({
    required this.unidad,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Unidad unidad;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final tipo = TipoUnidad.desdeTexto(unidad.tipo);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.verde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Espaciado.radio),
                ),
                child: Icon(
                  tipo == TipoUnidad.motocarga
                      ? CupertinoIcons.bus
                      : CupertinoIcons.cube_box_fill,
                  size: 22,
                  color: AppTheme.verde,
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unidad.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${tipo.etiqueta} · ${_litros(unidad.capacidad)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Espaciado.sm),

          // Las dos etiquetas van juntas y solo si están puestas: una fila de
          // badges vacíos en cada unidad es ruido.
          if (!unidad.activo || unidad.cerrado)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaciado.sm),
              child: Wrap(
                spacing: Espaciado.xs,
                children: [
                  if (!unidad.activo)
                    const AppPill(texto: 'inactiva', color: CupertinoColors.systemGrey),
                  if (unidad.cerrado)
                    const AppPill(texto: 'cerrada', color: CupertinoColors.systemOrange),
                ],
              ),
            ),

          if (unidad.acopiadorId == null)
            const AppNotice(
              texto: 'Sin chófer asignado',
              color: CupertinoColors.systemOrange,
            ),

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

  /// `1500` sale como "1500 L" y `1500.5` como "1500,5 L": los litros no se
  /// leen con punto decimal en un móvil.
  String _litros(double capacidad) {
    final texto = capacidad == capacidad.roundToDouble()
        ? capacidad.round().toString()
        : capacidad.toStringAsFixed(1).replaceAll('.', ',');

    return '$texto L';
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final UnidadesState estado;
  final UnidadesController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} unidad${estado.total == 1 ? '' : 'es'}',
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