import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/proveedor.dart';
import 'providers/proveedores_controller.dart';
import 'proveedor_form_page.dart';

/// Lista de proveedores de la planta.
///
/// Cada fila lleva la foto, el nombre, el código y la zona.
class ProveedoresPage extends ConsumerStatefulWidget {
  const ProveedoresPage({super.key});

  @override
  ConsumerState<ProveedoresPage> createState() => _ProveedoresPageState();
}

class _ProveedoresPageState extends ConsumerState<ProveedoresPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(proveedoresControllerProvider);
    final controller = ref.read(proveedoresControllerProvider.notifier);
    final filtros = ref.watch(filtrosProveedoresProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Proveedores'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('proveedores', 'write')
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
              soloInactivos: filtros.soloInactivos,
              onBusqueda: controller.buscar,
              onInactivos: controller.alternarSoloInactivos,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.proveedores.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('proveedores', 'write'),
                      controller: controller,
                      onEditar: (p) => _abrirFormulario(context, proveedor: p),
                      onEliminar: (p) => _confirmarBorrado(context, p),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Proveedor? proveedor}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProveedorFormPage(proveedor: proveedor),
      ),
    );
  }

  /// Borrar pide confirmación.
  ///
  /// Un proveedor pertenece a una zona y suele tener paradas en rutas. El aviso
  /// lo dice, porque borrarlo no es solo borrar su ficha.
  Future<void> _confirmarBorrado(BuildContext contexto, Proveedor proveedor) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar a ${proveedor.nombreCompleto}?'),
        content: Text(
          proveedor.zonaId == null
              ? 'Sus recogidas dejarán de aparecer en los recorridos.'
              : 'Se le quitará de la zona #${proveedor.zonaId} y de cualquier '
                  'parada de ruta que tenga. No se puede deshacer.',
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
      await ref.read(proveedoresControllerProvider.notifier).eliminar(proveedor);
    }
  }
}

/// Fila de filtros: búsqueda y la casilla de inactivos.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.busqueda,
    required this.soloInactivos,
    required this.onBusqueda,
    required this.onInactivos,
    required this.onLimpiar,
  });

  final TextEditingController busqueda;

  /// Viene de la pantalla, que ya la tiene leída. Un `StatelessWidget` no puede
  /// leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final bool soloInactivos;

  final ValueChanged<String> onBusqueda;
  final VoidCallback onInactivos;

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
              // El backend busca en nombre, apellido, DNI y código. Se dice
              // aquí para que se sepa que un DNI también sirve.
              placeholder: 'Nombre, apellido, DNI o código',
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
            color: soloInactivos ? AppTheme.verde : CupertinoColors.white,
            onPressed: onInactivos,
            child: Text(
              'Inactivos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: soloInactivos ? FontWeight.w600 : FontWeight.normal,
                color: soloInactivos ? CupertinoColors.white : CupertinoColors.label,
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

  final ProveedoresState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final ProveedoresController controller;
  final ValueChanged<Proveedor> onEditar;
  final ValueChanged<Proveedor> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.proveedores.isEmpty) {
      // Distinguir "no hay proveedores" de "no hay ninguno que coincida" son
      // dos problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún proveedor coincide con el filtro.'
                : 'Esta planta todavía no tiene proveedores.',
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
      itemCount: estado.proveedores.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.proveedores.length) {
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

        final proveedor = estado.proveedores[indice];
        return _FilaProveedor(
          proveedor: proveedor,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(proveedor),
          onEliminar: () => onEliminar(proveedor),
        );
      },
    );
  }
}

/// Un proveedor con su foto, su código y su zona.
class _FilaProveedor extends StatelessWidget {
  const _FilaProveedor({
    required this.proveedor,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Proveedor proveedor;
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
              _Foto(ruta: proveedor.imagen),
              const SizedBox(width: Espaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proveedor.nombreCompleto,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      proveedor.resumen,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              if (!proveedor.activo)
                const AppPill(texto: 'inactivo', color: CupertinoColors.systemGrey),
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

/// La foto del proveedor, o un marcador si no tiene.
///
/// Es redonda porque quien la ve es una persona, y una foto de persona en un
/// círculo se distingue de una foto de producto en un cuadrado.
class _Foto extends StatelessWidget {
  const _Foto({required this.ruta});

  final String? ruta;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);

    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey5,
        shape: BoxShape.circle,
      ),
      child: url.isEmpty
          ? const Icon(
              CupertinoIcons.person_crop_circle,
              size: 26,
              color: CupertinoColors.systemGrey,
            )
          : Image.network(
              url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              // Una imagen rota no debe romper la fila: se ve el marcador.
              errorBuilder: (context, error, stack) => const Icon(
                CupertinoIcons.person_crop_circle,
                size: 26,
                color: CupertinoColors.systemGrey,
              ),
            ),
    );
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final ProveedoresState estado;
  final ProveedoresController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} proveedor${estado.total == 1 ? '' : 'es'}',
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
