import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../auth/domain/planta.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'providers/plantas_controller.dart';
import 'planta_form_page.dart';

/// Lista de plantas.
///
/// **Aparece también al admin, que solo puede leer**: el botón de alta se esconde
/// si no tiene `plantas: write`, y el servidor rechaza el alta igual. Ocultarlo en
/// la app y no solo en el servidor es lo que evita un `403` al pulsar un `+` que
/// no podía funcionar.
class PlantasPage extends ConsumerStatefulWidget {
  const PlantasPage({super.key});

  @override
  ConsumerState<PlantasPage> createState() => _PlantasPageState();
}

class _PlantasPageState extends ConsumerState<PlantasPage> {
  @override
  void initState() {
    super.initState();
    // La carga va en `initState` y no en el `build` del controlador: el módulo solo
    // se pide si alguien abre la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(plantasControllerProvider.notifier).cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(plantasControllerProvider);
    final controller = ref.read(plantasControllerProvider.notifier);
    final permisos = ref.watch(permisosProvider);
    final puedeEscribir = permisos.puedeCon('plantas', 'write');

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Plantas'),
        trailing: puedeEscribir
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
        // **El aviso de error va antes que la lista.** Sin él, una petición que
        // falla enseña "No hay ninguna planta" con un 200 —o un 403— delante, que
        // es peor que un fallo: hace creer que no hay nada cuando lo que hay es
        // que no se ha podido mirar. Todas las demás listas de la app lo tienen.
        child: Column(
          children: [
            if (estado.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaciado.md,
                  Espaciado.sm,
                  Espaciado.md,
                  0,
                ),
                child: AppErrorBanner(mensaje: estado.error!.message),
              ),
            Expanded(
              child: estado.cargando && estado.plantas.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      puedeEscribir: puedeEscribir,
                      controller: controller,
                      onEditar: (p) => _abrirFormulario(context, planta: p),
                      onEliminar: (p) => _confirmarBorrado(context, p),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Planta? planta}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => PlantaFormPage(planta: planta),
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext contexto, Planta planta) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar esta planta?'),
        content: Text(
          '${planta.nombre} (${planta.codigo}). Se llevan por delante sus '
          'proveedores, sus rutas y todo lo demás. No se puede deshacer.',
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
      await ref.read(plantasControllerProvider.notifier).eliminar(planta);
    }
  }
}

/// El cuerpo: o vacío, o las plantas.
class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.estado,
    required this.puedeEscribir,
    required this.controller,
    required this.onEditar,
    required this.onEliminar,
  });

  final PlantasState estado;
  final bool puedeEscribir;
  final PlantasController controller;
  final ValueChanged<Planta> onEditar;
  final ValueChanged<Planta> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.plantas.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: puedeEscribir
                ? 'No hay ninguna planta. Crea la primera.'
                : 'No hay plantas a las que tengas acceso.',
          ),
        ],
      );
    }

    final lista = estado.ordenadas;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espaciado.md, Espaciado.md, Espaciado.md, Espaciado.xl),
      itemCount: lista.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == lista.length) {
          return Column(
            children: [
              Text(
                '${estado.total} planta${estado.total == 1 ? '' : 's'}',
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

        final planta = lista[indice];
        return _FilaPlanta(
          planta: planta,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(planta),
          onEliminar: () => onEliminar(planta),
        );
      },
    );
  }
}

/// Una planta: el código en grande, porque es lo que se ve en las etiquetas.
class _FilaPlanta extends StatelessWidget {
  const _FilaPlanta({
    required this.planta,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Planta planta;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final direccion = planta.direccion?.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planta.nombre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (direccion != null && direccion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        direccion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // **El código va como etiqueta y no en el texto** porque es lo que
              // aparece suelto en todas las pantallas de la planta: es el
              // identificador corto que se reconoce de un vistazo.
              AppPill(
                texto: planta.codigo,
                color: planta.activo
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey,
              ),
            ],
          ),

          if (!planta.activo) ...[
            const SizedBox(height: Espaciado.xs),
            const AppNotice(
              texto: 'Está inactiva. No se puede entrar con ella ni registrar en ella.',
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