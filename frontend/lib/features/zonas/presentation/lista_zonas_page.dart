import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/zona.dart';
import 'providers/zonas_controller.dart';
import 'zona_form_page.dart';

/// Lista de zonas de la planta.
///
/// Cada fila lleva el nombre, el horario y si tiene ruta y unidad asignadas.
class ZonasPage extends ConsumerStatefulWidget {
  const ZonasPage({super.key});

  @override
  ConsumerState<ZonasPage> createState() => _ZonasPageState();
}

class _ZonasPageState extends ConsumerState<ZonasPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(zonasControllerProvider);
    final controller = ref.read(zonasControllerProvider.notifier);
    final filtros = ref.watch(filtrosZonasProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Zonas'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('zonas', 'write')
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
              child: estado.cargando && estado.zonas.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('zonas', 'write'),
                      controller: controller,
                      onEditar: (zona) => _abrirFormulario(context, zona: zona),
                      onEliminar: (zona) => _confirmarBorrado(context, zona),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Zona? zona}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => ZonaFormPage(zona: zona),
      ),
    );
  }

  /// Borrar pide confirmación.
  ///
  /// Una zona con ruta o unidad deja esos registros apuntando a algo que ya no
  /// existe, así que el aviso dice qué se queda referencing.
  Future<void> _confirmarBorrado(BuildContext contexto, Zona zona) async {
    final avisos = <String>[
      if (zona.rutaId != null) 'su ruta se queda sin esta zona',
      if (zona.unidadId != null) 'la unidad pierde la zona que recogía',
    ];

    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar ${zona.nombre}?'),
        content: Text(
          avisos.isEmpty
              ? 'No se puede deshacer.'
              : 'Al borrarla, ${avisos.join(' y ')}. No se puede deshacer.',
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
      await ref.read(zonasControllerProvider.notifier).eliminar(zona);
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
              placeholder: 'Nombre de la zona',
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
    required this.onEditar,
    required this.onEliminar,
  });

  final ZonasState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final ZonasController controller;
  final ValueChanged<Zona> onEditar;
  final ValueChanged<Zona> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.zonas.isEmpty) {
      // Distinguir "no hay zonas" de "no hay ninguna que coincida" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ninguna zona coincide con el filtro.'
                : 'Esta planta todavía no tiene zonas.',
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
      itemCount: estado.zonas.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.zonas.length) {
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

        final zona = estado.zonas[indice];
        return _FilaZona(
          zona: zona,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(zona),
          onEliminar: () => onEliminar(zona),
        );
      },
    );
  }
}

/// Una zona con su horario y si tiene ruta y unidad.
class _FilaZona extends StatelessWidget {
  const _FilaZona({
    required this.zona,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Zona zona;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
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
                      zona.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zona.horario,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              if (!zona.activo)
                const AppPill(texto: 'inactiva', color: CupertinoColors.systemGrey),
            ],
          ),

          const SizedBox(height: Espaciado.sm),

          // Ruta y unidad son opcionales, y no tenerlas es lo normal: se ve aquí
          // para que quede claro que no es un dato que falte.
          Wrap(
            spacing: Espaciado.xs,
            runSpacing: Espaciado.xs,
            children: [
              AppPill(
                texto: zona.rutaId == null ? 'sin ruta' : 'ruta #${zona.rutaId}',
                color: zona.rutaId == null
                    ? CupertinoColors.systemGrey
                    : CupertinoColors.systemBlue,
              ),
              AppPill(
                texto: zona.unidadId == null ? 'sin unidad' : 'unidad #${zona.unidadId}',
                color: zona.unidadId == null
                    ? CupertinoColors.systemGrey
                    : CupertinoColors.systemGreen,
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
    );
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final ZonasState estado;
  final ZonasController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} zona${estado.total == 1 ? '' : 's'}',
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
