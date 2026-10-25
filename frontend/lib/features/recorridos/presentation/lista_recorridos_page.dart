import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/recorrido.dart';
import 'providers/recorridos_controller.dart';
import 'recorrido_detalle_page.dart';
import 'recorrido_form_page.dart';

/// Lista de recorridos de la planta.
///
/// Cada fila enseña el estado, la ruta, la unidad y la fecha. El estado va
/// primero y con color porque es lo que decide qué se puede hacer con esa fila,
/// y quien recorre la lista de arriba abajo tiene que verlo sin leer.
class RecorridosPage extends ConsumerStatefulWidget {
  const RecorridosPage({super.key});

  @override
  ConsumerState<RecorridosPage> createState() => _RecorridosPageState();
}

class _RecorridosPageState extends ConsumerState<RecorridosPage> {
  final _ctrlFecha = TextEditingController();

  @override
  void dispose() {
    _ctrlFecha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recorridosControllerProvider);
    final controller = ref.read(recorridosControllerProvider.notifier);
    final filtros = ref.watch(filtrosRecorridosProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Recorridos'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('recorridos', 'write')
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
              fecha: _ctrlFecha,
              estado: filtros.estado,
              onEstado: controller.filtrarPorEstado,
              onFecha: controller.filtrarPorFecha,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.recorridos.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('recorridos', 'write'),
                      controller: controller,
                      onAbrir: (r) => _abrirDetalle(context, r),
                      onEditar: (r) => _abrirFormulario(context, recorrido: r),
                      onEliminar: (r) => _confirmarBorrado(context, r),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Recorrido? recorrido}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RecorridoFormPage(recorrido: recorrido),
      ),
    );
  }

  void _abrirDetalle(BuildContext contexto, Recorrido recorrido) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RecorridoDetallePage(recorridoId: recorrido.id),
      ),
    );
  }

  /// Borrar pide confirmación y avisa de lo que se lleva por delante.
  ///
  /// Un recorrido con paradas atendidas tiene recolecciones colgando, y
  /// borrarlo se lleva también eso. Por eso el aviso no dice solo "no se puede
  /// deshacer".
  Future<void> _confirmarBorrado(BuildContext contexto, Recorrido recorrido) async {
    final conTrabajo = recorrido.paradas.any((p) => p.atendida);

    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar el recorrido del ${recorrido.fechaLegible}?'),
        content: Text(
          conTrabajo
              ? 'Tiene paradas atendidas y sus recolecciones. Al borrarlo, se '
                  'quedan esas recolecciones sin recorrido. No se puede deshacer.'
              : 'No se puede deshacer.',
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
      await ref.read(recorridosControllerProvider.notifier).eliminar(recorrido);
    }
  }
}

/// Fila de filtros: estado y fecha.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.fecha,
    required this.estado,
    required this.onEstado,
    required this.onFecha,
    required this.onLimpiar,
  });

  final TextEditingController fecha;

  /// Viene de la pantalla, que ya lo tiene leído. Un `StatelessWidget` no puede
  /// leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final EstadoRecorrido? estado;

  final ValueChanged<EstadoRecorrido?> onEstado;
  final ValueChanged<String> onFecha;

  /// Quita todos los filtros. `null` cuando no hay ninguno puesto.
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  etiqueta: 'DÍA',
                  controller: fecha,
                  placeholder: '2026-10-13',
                  icon: CupertinoIcons.calendar,
                  // El servidor toma `fecha` como `DATEONLY`. Se escribe con
                  // guiones y a cuatro cifras porque es lo que espera; un
                  // selector de calendario sería más bonito, pero exigiría otro
                  // formato y el filtro no merece esa conversión.
                  keyboardType: TextInputType.datetime,
                  onChanged: onFecha,
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
                  etiqueta: 'ESTADO',
                  valor: estado?.valor ?? '',
                  items: [
                    const SelectorItem(id: '', etiqueta: 'Todos'),
                    ...EstadoRecorrido.values.map(
                      (e) => SelectorItem(id: e.valor, etiqueta: e.etiqueta),
                    ),
                  ],
                  vacio: 'Todos',
                  limpiar: estado == null ? null : () => onEstado(null),
                  onChanged: (valor) {
                    if (valor == null || valor.isEmpty) {
                      onEstado(null);
                      return;
                    }
                    for (final e in EstadoRecorrido.values) {
                      if (e.valor == valor) {
                        onEstado(e);
                        return;
                      }
                    }
                  },
                ),
              ),
            ],
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
    required this.onAbrir,
    required this.onEditar,
    required this.onEliminar,
  });

  final RecorridosState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final RecorridosController controller;
  final ValueChanged<Recorrido> onAbrir;
  final ValueChanged<Recorrido> onEditar;
  final ValueChanged<Recorrido> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.recorridos.isEmpty) {
      // Distinguir "no hay recorridos" de "no hay ninguno que coincida" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún recorrido coincide con el filtro.'
                : 'Esta planta todavía no tiene recorridos.',
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
      itemCount: estado.recorridos.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.recorridos.length) {
          // El pie lleva paginación y recarga. `RefreshIndicator` es de Material
          // y esta app es Cupertino.
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

        final recorrido = estado.recorridos[indice];
        return _FilaRecorrido(
          recorrido: recorrido,
          puedeEscribir: puedeEscribir,
          onAbrir: () => onAbrir(recorrido),
          onEditar: () => onEditar(recorrido),
          onEliminar: () => onEliminar(recorrido),
        );
      },
    );
  }
}

/// Un recorrido con su estado, su ruta y su unidad.
class _FilaRecorrido extends StatelessWidget {
  const _FilaRecorrido({
    required this.recorrido,
    required this.puedeEscribir,
    required this.onAbrir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Recorrido recorrido;
  final bool puedeEscribir;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    // Editar y borrar solo tienen sentido mientras el recorrido no ha empezado:
    // una vez en marcha, cambiarle la ruta o la unidad dejaría las paradas
    // selladas apuntando a una ruta que ya no es la suya.
    final planificable = recorrido.puedeIniciar || recorrido.estado == EstadoRecorrido.cancelado;

    return AppCard(
      // `HitTestBehavior.opaque` no es un detalle: sin él el `GestureDetector` solo
      // recibe el toque justo encima del contenido, y las zonas en blanco de la
      // tarjeta se quedan sin pulsar.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAbrir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EstadoPill(estado: recorrido.estado),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: Text(
                    recorrido.ruta?.nombre ?? 'Ruta #${recorrido.rutaId}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ],
            ),
            const SizedBox(height: Espaciado.sm),
            Text(
              '${recorrido.unidad?.nombre ?? 'Unidad #${recorrido.unidadId}'} · '
              '${recorrido.fechaLegible}',
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            if (recorrido.ayudante != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Ayuda: ${recorrido.ayudante}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
              ),

            if (puedeEscribir) ...[
              const SizedBox(height: Espaciado.sm),
              Row(
                children: [
                  if (planificable)
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
                    )
                  else
                    Expanded(
                      child: AppNotice(
                        texto: 'En marcha no se edita: sus paradas ya están selladas.',
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  if (planificable) ...[
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La etiqueta del estado, con su color.
///
/// El color no es decoración: es lo que permite recorrer la lista y ver de un
/// vistazo cuántos hay en marcha sin leer los cuatro estados. Un recorrido
/// `EN_RUTA` es el único que está pasando algo ahora mismo.
class EstadoPill extends StatelessWidget {
  const EstadoPill({super.key, required this.estado});

  final EstadoRecorrido estado;

  static Color colorDe(EstadoRecorrido e) {
    switch (e) {
      case EstadoRecorrido.enRuta:
        return AppTheme.verde;
      case EstadoRecorrido.planificado:
        return CupertinoColors.systemBlue;
      case EstadoRecorrido.finalizado:
        return CupertinoColors.systemGrey;
      case EstadoRecorrido.cancelado:
        return CupertinoColors.systemRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPill(texto: estado.etiqueta.toLowerCase(), color: colorDe(estado));
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final RecorridosState estado;
  final RecorridosController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} recorrido${estado.total == 1 ? '' : 's'}',
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
