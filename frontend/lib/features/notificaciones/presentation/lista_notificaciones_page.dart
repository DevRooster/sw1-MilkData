import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/notificacion.dart';
import 'notificacion_form_page.dart';
import 'providers/notificaciones_controller.dart';

/// Lista de avisos de la planta.
///
/// Cada fila dice a quién va, qué dice y si ya salió. Lo que más se mira de un
/// vistazo es **si está sin leer**, así que eso va en el sitio de la izquierda y
/// el resto se aparta.
class NotificacionesPage extends ConsumerStatefulWidget {
  const NotificacionesPage({super.key});

  @override
  ConsumerState<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends ConsumerState<NotificacionesPage> {
  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(notificacionesControllerProvider);
    final controller = ref.read(notificacionesControllerProvider.notifier);
    final filtros = ref.watch(filtrosNotificacionesProvider);
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notificaciones'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
        trailing: permisos.puedeCon('notificaciones', 'write')
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
              tipo: filtros.tipo,
              soloSinLeer: filtros.soloSinLeer,
              soloBorradores: filtros.soloBorradores,
              onTipo: controller.filtrarPorTipo,
              onSinLeer: controller.alternarSoloSinLeer,
              onBorradores: controller.alternarSoloBorradores,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),
            Expanded(
              child: estado.cargando && estado.notificaciones.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      puedeEscribir: permisos.puedeCon('notificaciones', 'write'),
                      controller: controller,
                      onEditar: (n) => _abrirFormulario(context, notificacion: n),
                      onEliminar: (n) => _confirmarBorrado(context, n),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Notificacion? notificacion}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => NotificacionFormPage(notificacion: notificacion),
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext contexto, Notificacion notificacion) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar este aviso?'),
        content: Text(
          '"${notificacion.titulo}". Si ya se envió, no se puede retirar: '
          'quien lo recibió ya lo tiene.',
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
      await ref.read(notificacionesControllerProvider.notifier).eliminar(notificacion);
    }
  }
}

/// Fila de filtros: tipo, sin leer y borradores.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.tipo,
    required this.soloSinLeer,
    required this.soloBorradores,
    required this.onTipo,
    required this.onSinLeer,
    required this.onBorradores,
    required this.onLimpiar,
  });

  /// Vienen de la pantalla, que ya los tiene leídos. Un `StatelessWidget` no
  /// puede leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final String? tipo;
  final bool soloSinLeer;
  final bool soloBorradores;

  final ValueChanged<String?> onTipo;
  final VoidCallback onSinLeer;
  final VoidCallback onBorradores;

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
                child: AppSelector(
                  etiqueta: 'TIPO',
                  valor: tipo ?? '',
                  items: [
                    const SelectorItem(id: '', etiqueta: 'Todos'),
                    for (final valor in Notificacion.tipos)
                      SelectorItem(
                        id: valor,
                        etiqueta: Notificacion.etiquetaDeTipo(valor),
                      ),
                  ],
                  vacio: 'Todos',
                  limpiar: tipo == null ? null : () => onTipo(null),
                  onChanged: (valor) => onTipo(valor == null || valor.isEmpty ? null : valor),
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
              // Dos casillas y no un selector de cuatro: cada una es un estado
              // que se enciende y se apaga, y se pueden combinar.
              Expanded(
                child: _Pastilla(
                  texto: 'Sin leer',
                  activa: soloSinLeer,
                  onPressed: onSinLeer,
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: _Pastilla(
                  texto: 'Borradores',
                  activa: soloBorradores,
                  onPressed: onBorradores,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Casilla de filtro: encendida en verde, apagada en blanco.
class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.texto, required this.activa, required this.onPressed});

  final String texto;
  final bool activa;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.sm),
      color: activa ? AppTheme.verde : CupertinoColors.white,
      onPressed: onPressed,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: activa ? FontWeight.w600 : FontWeight.normal,
          color: activa ? CupertinoColors.white : CupertinoColors.label,
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

  final NotificacionesState estado;
  final bool hayFiltro;
  final bool puedeEscribir;
  final NotificacionesController controller;
  final ValueChanged<Notificacion> onEditar;
  final ValueChanged<Notificacion> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.notificaciones.isEmpty) {
      // Distinguir "no hay avisos" de "no hay ninguno con ese filtro" son dos
      // problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún aviso coincide con el filtro.'
                : 'Esta planta todavía no tiene avisos.',
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
      itemCount: estado.notificaciones.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.notificaciones.length) {
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

        final notificacion = estado.notificaciones[indice];
        return _FilaNotificacion(
          notificacion: notificacion,
          puedeEscribir: puedeEscribir,
          onMarcarLeida: () => controller.marcarLeida(notificacion, !notificacion.leida),
          onEditar: () => onEditar(notificacion),
          onEliminar: () => onEliminar(notificacion),
        );
      },
    );
  }
}

/// "3 sin leer · 1 solo en borrador · 20 en total".
class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final NotificacionesState estado;

  @override
  Widget build(BuildContext context) {
    final partes = <String>[];
    if (estado.sinLeer > 0) {
      partes.add('${estado.sinLeer} sin leer');
    }
    if (estado.borradores > 0) {
      partes.add('${estado.borradores} sin enviar');
    }
    partes.add('${estado.total} en total');

    return Text(
      partes.join(' · '),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
    );
  }
}

/// Un aviso: sin leer a la izquierda, tipo, destinatario y mensaje debajo.
class _FilaNotificacion extends StatelessWidget {
  const _FilaNotificacion({
    required this.notificacion,
    required this.puedeEscribir,
    required this.onMarcarLeida,
    required this.onEditar,
    required this.onEliminar,
  });

  final Notificacion notificacion;
  final bool puedeEscribir;
  final VoidCallback onMarcarLeida;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final fecha = notificacion.fechaEnvioLegible;
    final sinLeer = !notificacion.leida;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El botón de leída va **antes** del texto y no dentro: es la
              // acción principal y tiene su propio sitio, en vez de repartirse
              // una fila con el título.
              CupertinoButton(
                padding: const EdgeInsets.only(right: Espaciado.sm),
                minimumSize: const Size(34, 34),
                onPressed: onMarcarLeida,
                child: Icon(
                  sinLeer
                      ? CupertinoIcons.circle
                      : CupertinoIcons.checkmark_alt_circle_fill,
                  size: 22,
                  color: sinLeer ? CupertinoColors.systemGrey : AppTheme.verde,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacion.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        // Lo sin leer va en negrita: es lo que se escanea al
                        // pasar por encima de la lista.
                        fontWeight: sinLeer ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Notificacion.etiquetaDeTipo(notificacion.tipo)} · ${notificacion.destinatario}',
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

          const SizedBox(height: Espaciado.xs),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              notificacion.mensajeCorto,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ),

          const SizedBox(height: Espaciado.sm),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Wrap(
              spacing: Espaciado.xs,
              runSpacing: Espaciado.xs,
              children: [
                if (notificacion.esBorrador)
                  const AppPill(
                    texto: 'sin enviar',
                    color: CupertinoColors.systemOrange,
                  )
                else
                  AppPill(
                    texto: 'enviado $fecha',
                    color: CupertinoColors.systemGreen,
                  ),
                if (sinLeer)
                  const AppPill(
                    texto: 'sin leer',
                    color: CupertinoColors.systemBlue,
                  ),
              ],
            ),
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

  final NotificacionesState estado;
  final NotificacionesController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} aviso${estado.total == 1 ? '' : 's'}',
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