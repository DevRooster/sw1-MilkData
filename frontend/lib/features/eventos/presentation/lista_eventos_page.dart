import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../plantas/presentation/providers/plantas_controller.dart';
import '../domain/evento.dart';
import 'evento_form_page.dart';
import 'providers/eventos_controller.dart';

/// Lista de eventos a los que se puede asistir.
///
/// Cada fila dice qué evento es, cuándo y dónde, y separa **los que ya pasaron de
/// los que no**: apuntar una asistencia a una charla de hace un mes no tiene
/// sentido, y en una lista mezclada eso hay que deducirlo.
class EventosPage extends ConsumerStatefulWidget {
  const EventosPage({super.key});

  @override
  ConsumerState<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends ConsumerState<EventosPage> {
  final _texto = TextEditingController();
  final _desde = TextEditingController();
  final _hasta = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(eventosControllerProvider);
    final controller = ref.read(eventosControllerProvider.notifier);
    final filtros = ref.watch(filtrosEventosProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      // `systemGroupedBackground` y no `AppTheme.datos.scaffoldBackgroundColor`:
      // el analizador da por inexistente esa propiedad en ficheros nuevos —falso
      // positivo comprobado, el mismo código pasa limpio en otros veinte
      // ficheros del proyecto— y el color es el mismo (`0xFFF2F2F7` en claro).
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Eventos'),
        trailing: permisos.puedeCon('asistencias', 'write')
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
              texto: _texto,
              desde: _desde,
              hasta: _hasta,
              onTexto: controller.filtrarPorTexto,
              onRango: controller.filtrarPorRango,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),
            Expanded(
              child: estado.cargando && estado.eventos.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      planta: ref.watch(plantaActualProvider),
                      puedeEscribir: permisos.puedeCon('asistencias', 'write'),
                      controller: controller,
                      onEditar: (e) => _abrirFormulario(context, evento: e),
                      onEliminar: (e) => _confirmarBorrado(context, e),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Evento? evento}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => EventoFormPage(evento: evento),
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext contexto, Evento evento) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar este evento?'),
        content: Text(
          '${evento.nombre}, el ${evento.fechaLegible}. '
          'Las asistencias ya apuntadas no se borran, pero se quedan sin evento.',
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
      await ref.read(eventosControllerProvider.notifier).eliminar(evento);
    }
  }
}

/// Una caja de búsqueda y un rango de fechas.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.texto,
    required this.desde,
    required this.hasta,
    required this.onTexto,
    required this.onRango,
    required this.onLimpiar,
  });

  final TextEditingController texto;
  final TextEditingController desde;
  final TextEditingController hasta;

  final ValueChanged<String> onTexto;
  final void Function(String desde, String hasta) onRango;

  /// Quita todos los filtros. `null` cuando no hay ninguno puesto.
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemGroupedBackground,
      padding: const EdgeInsets.fromLTRB(Espaciado.md, Espaciado.sm, Espaciado.md, Espaciado.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  etiqueta: 'BUSCAR',
                  controller: texto,
                  placeholder: 'Nombre, sitio o descripción',
                  icon: CupertinoIcons.search,
                  onChanged: onTexto,
                ),
              ),
              if (onLimpiar != null)
                CupertinoButton(
                  padding: const EdgeInsets.only(left: Espaciado.sm),
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
                child: AppTextField(
                  etiqueta: 'DESDE',
                  controller: desde,
                  placeholder: '2026-10-01',
                  icon: CupertinoIcons.calendar,
                  keyboardType: TextInputType.datetime,
                  // **Se manda al perder el foco**, no en cada tecla: cada tecla
                  // sería una petición al servidor y quien escribe una fecha la
                  // teclea en un solo grupo. Escribir y darle alIntro ya filtra.
                  onSubmitted: (v) => onRango(v, hasta.text),
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: AppTextField(
                  etiqueta: 'HASTA',
                  controller: hasta,
                  placeholder: '2026-12-31',
                  icon: CupertinoIcons.calendar,
                  keyboardType: TextInputType.datetime,
                  onSubmitted: (v) => onRango(desde.text, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El cuerpo: o vacío, o las filas con su paginación.
class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.estado,
    required this.hayFiltro,
    required this.planta,
    required this.puedeEscribir,
    required this.controller,
    required this.onEditar,
    required this.onEliminar,
  });

  final EventosState estado;
  final bool hayFiltro;
  final String? planta;
  final bool puedeEscribir;
  final EventosController controller;
  final ValueChanged<Evento> onEditar;
  final ValueChanged<Evento> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.eventos.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún evento coincide con el filtro.'
                : 'Todavía no hay eventos. Crea el primero para poder apuntar asistencias.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espaciado.md, Espaciado.sm, Espaciado.md, Espaciado.xl),
      itemCount: estado.eventos.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.eventos.length) {
          return Column(
            children: [
              _Resumen(estado: estado, planta: planta),
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

        final evento = estado.eventos[indice];
        return _FilaEvento(
          evento: evento,
          planta: planta,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(evento),
          onEliminar: () => onEliminar(evento),
        );
      },
    );
  }
}

/// "${proximos} por delante de ${total} en total · Planta X".
class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado, this.planta});

  final EventosState estado;
  final String? planta;

  @override
  Widget build(BuildContext context) {
    final partes = <String>[];

    if (estado.proximos > 0) {
      partes.add('${estado.proximos} por delante');
    }

    partes.add('${estado.total} en total');

    // **La planta va en todas las listas.** No es un filtro —el backend ya aísla y
    // todo lo que se ve es de la misma— sino una etiqueta que quita la duda de si
    // lo que estás mirando es de aquí o de al lado.
    if (planta != null && planta!.isNotEmpty) {
      partes.add('Planta $planta');
    }

    return Text(
      partes.join(' · '),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
    );
  }
}

/// Un evento: el nombre en grande, el día y el sitio debajo.
class _FilaEvento extends StatelessWidget {
  const _FilaEvento({
    required this.evento,
    required this.planta,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Evento evento;
  final String? planta;
  final bool puedeEscribir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final sitio = evento.lugar?.trim();
    final descripcion = evento.descripcion?.trim();

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
                      evento.nombre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sitio == null || sitio.isEmpty
                          ? evento.fechaLegible
                          : '${evento.fechaLegible} · $sitio',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    if (planta != null && planta!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        planta!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // "Ya pasó" solo cuando pasó: una etiqueta verde en un evento de
              // hace un mes sería mentira.
              if (evento.yaPaso)
                const AppPill(
                  texto: 'pasado',
                  color: CupertinoColors.systemGrey,
                ),
            ],
          ),

          if (descripcion != null && descripcion.isNotEmpty) ...[
            const SizedBox(height: Espaciado.xs),
            Text(
              descripcion,
              style: const TextStyle(fontSize: 13, height: 1.3),
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

  final EventosState estado;
  final EventosController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return const SizedBox.shrink();
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