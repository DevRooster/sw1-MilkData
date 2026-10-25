import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/recoleccion.dart';
import 'providers/recolecciones_controller.dart';
import 'recoleccion_form_page.dart';

/// Lista de recolecciones de la planta.
///
/// Cada fila lleva el proveedor, los litros, el día y de dónde se anotó. Los
/// litros van en grande porque es lo que se viene a mirar.
class RecoleccionesPage extends ConsumerStatefulWidget {
  const RecoleccionesPage({super.key});

  @override
  ConsumerState<RecoleccionesPage> createState() => _RecoleccionesPageState();
}

class _RecoleccionesPageState extends ConsumerState<RecoleccionesPage> {
  final _ctrlFecha = TextEditingController();

  @override
  void dispose() {
    _ctrlFecha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recoleccionesControllerProvider);
    final controller = ref.read(recoleccionesControllerProvider.notifier);
    final filtros = ref.watch(filtrosRecoleccionesProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Recolecciones'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('recolecciones', 'write')
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
              registradoEn: filtros.registradoEn,
              soloPendientes: filtros.soloPendientes,
              onRegistro: controller.filtrarPorRegistro,
              onPendientes: controller.alternarSoloPendientes,
              onFecha: controller.filtrarPorFecha,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.recolecciones.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('recolecciones', 'write'),
                      controller: controller,
                      onEditar: (r) => _abrirFormulario(context, recoleccion: r),
                      onEliminar: (r) => _confirmarBorrado(context, r),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Recoleccion? recoleccion}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RecoleccionFormPage(recoleccion: recoleccion),
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext contexto, Recoleccion recoleccion) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar esta recolección?'),
        content: Text(
          '${recoleccion.cantidadFormateada} de '
          '${recoleccion.proveedor?.nombreCompleto ?? 'un proveedor'}. '
          'No se puede deshacer.',
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
      await ref.read(recoleccionesControllerProvider.notifier).eliminar(recoleccion);
    }
  }
}

/// Fila de filtros: día, dónde se anotó y las pendientes.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.fecha,
    required this.registradoEn,
    required this.soloPendientes,
    required this.onRegistro,
    required this.onPendientes,
    required this.onFecha,
    required this.onLimpiar,
  });

  final TextEditingController fecha;

  /// Vienen de la pantalla, que ya los tiene leídos. Un `StatelessWidget` no
  /// puede leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final String? registradoEn;
  final bool soloPendientes;

  final ValueChanged<String?> onRegistro;
  final VoidCallback onPendientes;
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
                  etiqueta: 'ANOTADA EN',
                  valor: registradoEn ?? '',
                  items: const [
                    SelectorItem(id: '', etiqueta: 'Todas'),
                    SelectorItem(id: Recoleccion.campo, etiqueta: 'El campo'),
                    SelectorItem(id: Recoleccion.planta, etiqueta: 'La planta'),
                  ],
                  vacio: 'Todas',
                  limpiar: registradoEn == null ? null : () => onRegistro(null),
                  onChanged: (valor) => onRegistro(
                    valor == null || valor.isEmpty ? null : valor,
                  ),
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              // Es una casilla y no un selector: tiene dos estados y un selector
              // de dos opciones sería un rodeo.
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: Espaciado.sm),
                color: soloPendientes ? AppTheme.verde : CupertinoColors.white,
                onPressed: onPendientes,
                child: Text(
                  'Pendientes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: soloPendientes ? FontWeight.w600 : FontWeight.normal,
                    color: soloPendientes ? CupertinoColors.white : CupertinoColors.label,
                  ),
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
    required this.onEditar,
    required this.onEliminar,
  });

  final RecoleccionesState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final RecoleccionesController controller;
  final ValueChanged<Recoleccion> onEditar;
  final ValueChanged<Recoleccion> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.recolecciones.isEmpty) {
      // Distinguir "no hay recolecciones" de "no hay ninguna que coincida" son
      // dos problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ninguna recolección coincide con el filtro.'
                : 'Esta planta todavía no tiene recolecciones.',
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
      itemCount: estado.recolecciones.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.recolecciones.length) {
          // El pie lleva el total de litros, la paginación y la recarga.
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

        final recoleccion = estado.recolecciones[indice];
        return _FilaRecoleccion(
          recoleccion: recoleccion,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(recoleccion),
          onEliminar: () => onEliminar(recoleccion),
        );
      },
    );
  }
}

/// "42,5 L de 10 recolecciones".
///
/// Los litros son de **esta página**, no de todas, y el texto lo dice: dar el
/// total paginado haría pensar que son todos cuando no lo son.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final RecoleccionesState estado;

  @override
  Widget build(BuildContext context) {
    final litros = estado.litros;
    final entero = litros == litros.truncateToDouble();
    final texto = entero
        ? '${litros.truncate()} L'
        : '${litros.toStringAsFixed(1).replaceAll('.', ',')} L';

    return Text(
      '$texto en esta página · ${estado.total} en total',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
    );
  }
}

/// Una recolección con sus litros, su proveedor y de dónde se anotó.
class _FilaRecoleccion extends StatelessWidget {
  const _FilaRecoleccion({
    required this.recoleccion,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Recoleccion recoleccion;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final hora = recoleccion.horaLegible;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Los litros van en grande y a la izquierda: es lo que se viene a
              // mirar de un vistazo.
              SizedBox(
                width: 88,
                child: Text(
                  recoleccion.cantidadFormateada,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recoleccion.proveedor?.nombreCompleto ??
                          'Proveedor #${recoleccion.proveedorId}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recoleccion.fecha + (hora == null ? '' : ' · $hora'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              AppPill(
                texto: recoleccion.enCampo ? 'campo' : 'planta',
                color: recoleccion.enCampo
                    ? CupertinoColors.systemOrange
                    : CupertinoColors.systemBlue,
              ),
            ],
          ),

          if (recoleccion.temperatura != null ||
              !recoleccion.sincronizado ||
              recoleccion.recorridoParadaId != null) ...[
            const SizedBox(height: Espaciado.sm),
            Wrap(
              spacing: Espaciado.xs,
              runSpacing: Espaciado.xs,
              children: [
                if (recoleccion.temperatura != null)
                  AppPill(
                    texto: '${recoleccion.temperatura!.toStringAsFixed(1).replaceAll('.', ',')} °C',
                    color: CupertinoColors.systemGrey,
                  ),
                if (!recoleccion.sincronizado)
                  const AppPill(
                    texto: 'sin sincronizar',
                    color: CupertinoColors.systemOrange,
                  ),
                if (recoleccion.recorridoParadaId != null)
                  AppPill(
                    texto: 'parada #${recoleccion.recorridoParadaId}',
                    color: CupertinoColors.systemGreen,
                  ),
              ],
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

  final RecoleccionesState estado;
  final RecoleccionesController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} recolección${estado.total == 1 ? '' : 'es'}',
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
