import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/ruta.dart';
import 'providers/rutas_controller.dart';
import 'ruta_detalle_page.dart';
import 'ruta_form_page.dart';

/// Lista de rutas de la planta.
///
/// Cada fila lleva el nombre, el código, el horario y cuántas paradas tiene. Al
/// tocarla se abre el detalle, que es donde viven las paradas.
class RutasPage extends ConsumerStatefulWidget {
  const RutasPage({super.key});

  @override
  ConsumerState<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends ConsumerState<RutasPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(rutasControllerProvider);
    final controller = ref.read(rutasControllerProvider.notifier);
    final filtros = ref.watch(filtrosRutasProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Rutas'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('rutas', 'write')
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
              soloInactivas: filtros.soloInactivas,
              onBusqueda: controller.buscar,
              onInactivas: controller.alternarSoloInactivas,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.rutas.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('rutas', 'write'),
                      controller: controller,
                      onAbrir: (ruta) => _abrirDetalle(context, ruta),
                      onEditar: (ruta) => _abrirFormulario(context, ruta: ruta),
                      onEliminar: (ruta) => _confirmarBorrado(context, ruta),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Ruta? ruta}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RutaFormPage(ruta: ruta),
      ),
    );
  }

  void _abrirDetalle(BuildContext contexto, Ruta ruta) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RutaDetallePage(rutaId: ruta.id),
      ),
    );
  }

  /// Borrar pide confirmación y avisa de lo que se lleva por delante.
  ///
  /// Una ruta con paradas tiene proveedores asignados y recorridos que la usan,
  /// así que el aviso no dice solo "no se puede deshacer".
  Future<void> _confirmarBorrado(BuildContext contexto, Ruta ruta) async {
    final conParadas = ruta.paradasCount > 0;

    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar ${ruta.nombre}?'),
        content: Text(
          conParadas
              ? 'Esta ruta tiene ${ruta.paradasCount} paradas. Al borrarla, sus '
                  'proveedores quedan sin ruta asignada.'
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
      await ref.read(rutasControllerProvider.notifier).eliminar(ruta);
    }
  }
}

/// Fila de filtros: búsqueda y la casilla de inactivas.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.busqueda,
    required this.soloInactivas,
    required this.onBusqueda,
    required this.onInactivas,
    required this.onLimpiar,
  });

  final TextEditingController busqueda;

  /// Viene de la pantalla, que ya la tiene leída. Un `StatelessWidget` no puede
  /// leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final bool soloInactivas;

  final ValueChanged<String> onBusqueda;
  final VoidCallback onInactivas;

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
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              etiqueta: 'BUSCAR',
              controller: busqueda,
              placeholder: 'Nombre o código',
              icon: CupertinoIcons.search,
              onChanged: onBusqueda,
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
          const SizedBox(width: Espaciado.sm),
          // Es una casilla y no un selector: tiene dos estados y un selector de
          // dos opciones sería un rodeo.
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: Espaciado.sm),
            color: soloInactivas ? AppTheme.verde : CupertinoColors.white,
            onPressed: onInactivas,
            child: Text(
              'Inactivas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: soloInactivas ? FontWeight.w600 : FontWeight.normal,
                color: soloInactivas ? CupertinoColors.white : CupertinoColors.label,
              ),
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
    required this.onAbrir,
    required this.onEditar,
    required this.onEliminar,
  });

  final RutasState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final RutasController controller;
  final ValueChanged<Ruta> onAbrir;
  final ValueChanged<Ruta> onEditar;
  final ValueChanged<Ruta> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.rutas.isEmpty) {
      // Distinguir "no hay rutas" de "no hay ninguna que coincida" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ninguna ruta coincide con el filtro.'
                : 'Esta planta todavía no tiene rutas.',
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
      itemCount: estado.rutas.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.rutas.length) {
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

        final ruta = estado.rutas[indice];
        return _FilaRuta(
          ruta: ruta,
          puedeEscribir: puedeEscribir,
          onAbrir: () => onAbrir(ruta),
          onEditar: () => onEditar(ruta),
          onEliminar: () => onEliminar(ruta),
        );
      },
    );
  }
}

/// Una ruta con su horario y su número de paradas.
class _FilaRuta extends StatelessWidget {
  const _FilaRuta({
    required this.ruta,
    required this.puedeEscribir,
    required this.onAbrir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Ruta ruta;
  final bool puedeEscribir;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ruta.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ruta.codigo} · ${ruta.horario}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!ruta.activa)
                  const AppPill(texto: 'inactiva', color: CupertinoColors.systemGrey),
                const SizedBox(width: Espaciado.sm),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ],
            ),

            const SizedBox(height: Espaciado.sm),

            // Paradas y zonas de un vistazo. Las zonas vienen del detalle, así
            // que en el listado solo se ve el número de paradas.
            Wrap(
              spacing: Espaciado.xs,
              runSpacing: Espaciado.xs,
              children: [
                AppPill(
                  texto: '${ruta.paradasCount} parada${ruta.paradasCount == 1 ? '' : 's'}',
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
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
      ),
    );
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final RutasState estado;
  final RutasController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} ruta${estado.total == 1 ? '' : 's'}',
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