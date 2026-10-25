import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/producto.dart';
import 'providers/productos_controller.dart';
import 'producto_form_page.dart';

/// Lista de productos de la planta.
///
/// Cada fila lleva la imagen principal, el precio y las acciones de editar y
/// eliminar. El botón de la barra de navegación abre el alta.
class ProductosPage extends ConsumerStatefulWidget {
  const ProductosPage({super.key});

  @override
  ConsumerState<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends ConsumerState<ProductosPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(productosControllerProvider);
    final controller = ref.read(productosControllerProvider.notifier);
    final filtros = ref.watch(filtrosProductosProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Productos'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('productos', 'write')
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
              onUnidad: controller.filtrarPorUnidad,
              onInactivos: controller.alternarSoloInactivos,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),

            Expanded(
              child: estado.cargando && estado.productos.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('productos', 'write'),
                      controller: controller,
                      onEditar: (producto) => _abrirFormulario(context, producto: producto),
                      onEliminar: (producto) => _confirmarBorrado(context, producto),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Producto? producto}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProductoFormPage(producto: producto),
      ),
    );
  }

  /// Borrar pide confirmación y avisa de que no se puede deshacer.
  Future<void> _confirmarBorrado(BuildContext contexto, Producto producto) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: Text('¿Eliminar ${producto.nombre}?'),
        content: const Text('No se puede deshacer.'),
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
      await ref.read(productosControllerProvider.notifier).eliminar(producto);
    }
  }
}

/// Fila de filtros: búsqueda, unidad de medida y la casilla de inactivos.
class _Filtros extends ConsumerWidget {
  const _Filtros({
    required this.busqueda,
    required this.onBusqueda,
    required this.onUnidad,
    required this.onInactivos,
    required this.onLimpiar,
  });

  final TextEditingController busqueda;
  final ValueChanged<String> onBusqueda;
  final ValueChanged<String?> onUnidad;
  final VoidCallback onInactivos;

  /// Quita todos los filtros. `null` cuando no hay ninguno puesto.
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosProductosProvider);

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
                  placeholder: 'Nombre o descripción',
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
                  etiqueta: 'UNIDAD',
                  // Sin filtro es `null`, y "Todas" es la primera opción de la
                  // hoja: si no fuera una opción de verdad, elegir una unidad
                  // sería una puerta de sentido único.
                  valor: filtros.unidadMedida ?? '',
                  items: [
                    const SelectorItem(id: '', etiqueta: 'Todas'),
                    ...unidadesSugeridas.map(
                      (u) => SelectorItem(id: u, etiqueta: u),
                    ),
                  ],
                  vacio: 'Todas',
                  limpiar: filtros.unidadMedida == null ? null : () => onUnidad(null),
                  onChanged: (valor) {
                    if (valor == null || valor.isEmpty) {
                      onUnidad(null);
                    } else {
                      onUnidad(valor);
                    }
                  },
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              // Es una casilla y no un selector: tiene dos estados y un selector
              // de dos opciones sería un rodeo.
              _Casilla(
                texto: 'Inactivos',
                activo: filtros.soloInactivos,
                onPressed: onInactivos,
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

  final ProductosState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final ProductosController controller;
  final ValueChanged<Producto> onEditar;
  final ValueChanged<Producto> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.productos.isEmpty) {
      // Distinguir "no hay productos" de "no hay ninguno que coincida" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún producto coincide con el filtro.'
                : 'Esta planta todavía no tiene productos.',
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
      itemCount: estado.productos.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.productos.length) {
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

        final producto = estado.productos[indice];
        return _FilaProducto(
          producto: producto,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(producto),
          onEliminar: () => onEliminar(producto),
        );
      },
    );
  }
}

/// Un producto con su imagen, su precio y sus acciones.
class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.producto,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Producto producto;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Miniatura(ruta: producto.imagen),
              const SizedBox(width: Espaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      producto.resumen,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    // La descripción se corta a una línea: es texto libre y
                    // puede ser largo, y no debe empujar el precio fuera de
                    // pantalla.
                    if (producto.descripcion != null && producto.descripcion!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          producto.descripcion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.tertiaryLabel,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!producto.estado)
                const Padding(
                  padding: EdgeInsets.only(left: Espaciado.sm),
                  child: AppPill(texto: 'inactivo', color: CupertinoColors.systemGrey),
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

/// La imagen principal del producto, o un marcador si no tiene.
///
/// Usa la columna `imagen`, que el backend mantiene desnormalizada a propósito:
/// es lo que ven las listas sin tener que consultar la galería.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.ruta});

  final String? ruta;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(Espaciado.radio),
      ),
      child: url.isEmpty
          ? const Icon(CupertinoIcons.cube_box, size: 22, color: CupertinoColors.systemGrey)
          : Image.network(
              url,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              // Una imagen rota no debe romper la fila: se ve el marcador.
              errorBuilder: (context, error, stack) => const Icon(
                CupertinoIcons.cube_box,
                size: 22,
                color: CupertinoColors.systemGrey,
              ),
            ),
    );
  }
}

/// Paginación: "Anterior · pág. 1 de 3 · Siguiente".
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final ProductosState estado;
  final ProductosController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} producto${estado.total == 1 ? '' : 's'}',
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