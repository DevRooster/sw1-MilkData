import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../../shared/widgets/app_selector.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../plantas/presentation/providers/plantas_controller.dart';
import '../domain/asistencia.dart';
import 'asistencia_form_page.dart';
import 'providers/asistencias_controller.dart';

/// Lista de asistencias de la planta.
///
/// Cada fila dice quién asistió, a qué evento y cómo se anotó. El **QR o
/// manual** va en etiqueta porque es lo que distingue un registro fiable de una
/// anotación de memoria.
class AsistenciasPage extends ConsumerStatefulWidget {
  const AsistenciasPage({super.key});

  @override
  ConsumerState<AsistenciasPage> createState() => _AsistenciasPageState();
}

class _AsistenciasPageState extends ConsumerState<AsistenciasPage> {
  final _evento = TextEditingController();
  final _fecha = TextEditingController();

  @override
  void dispose() {
    _evento.dispose();
    _fecha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(asistenciasControllerProvider);
    final controller = ref.read(asistenciasControllerProvider.notifier);
    final filtros = ref.watch(filtrosAsistenciasProvider);
    final permisos = ref.watch(permisosProvider);
    final planta = ref.watch(plantaActualProvider);

    return CupertinoPageScaffold(
      // AppTheme.dados.scaffoldBackgroundColor es exactamente este color
      // (0xFFF2F2F7 en claro), pero el analizador lo da por inexistente en
      // este fichero. Anotado en el ROADMAP: es un falso positivo.
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Asistencias'),
        // Solo quien puede escribir ve el botón de alta. Un `+` que al pulsarlo
        // contesta 403 es peor que no tenerlo.
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
              evento: _evento,
              fecha: _fecha,
              registradoPor: filtros.registradoPor,
              onEvento: controller.filtrarPorEvento,
              onFecha: controller.filtrarPorFecha,
              onRegistro: controller.filtrarPorRegistro,
              onLimpiar: filtros.hayAlguno ? controller.limpiarFiltros : null,
            ),
            Expanded(
              child: estado.cargando && estado.asistencias.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _Cuerpo(
                      estado: estado,
                      hayFiltro: filtros.hayAlguno,
                      planta: planta,
                      puedeEscribir: permisos.puedeCon('asistencias', 'write'),
                      controller: controller,
                      onEditar: (a) => _abrirFormulario(context, asistencia: a),
                      onEliminar: (a) => _confirmarBorrado(context, a),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext contexto, {Asistencia? asistencia}) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => AsistenciaFormPage(asistencia: asistencia),
      ),
    );
  }

  Future<void> _confirmarBorrado(
    BuildContext contexto,
    Asistencia asistencia,
  ) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: contexto,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Eliminar esta asistencia?'),
        content: Text(
          '${asistencia.nombreProveedor} en "${asistencia.evento}". '
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
      await ref
          .read(asistenciasControllerProvider.notifier)
          .eliminar(asistencia);
    }
  }
}

/// Fila de filtros: evento, día y cómo se anotó.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.evento,
    required this.fecha,
    required this.registradoPor,
    required this.onEvento,
    required this.onFecha,
    required this.onRegistro,
    required this.onLimpiar,
  });

  final TextEditingController evento;
  final TextEditingController fecha;

  /// Viene de la pantalla, que ya lo tiene leído. Un `StatelessWidget` no puede
  /// leer providers, y darle un `ref` obligaría a convertirlo en
  /// `ConsumerWidget` solo para repetir una lectura.
  final String? registradoPor;

  final ValueChanged<String> onEvento;
  final ValueChanged<String> onFecha;
  final ValueChanged<String?> onRegistro;

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
                  etiqueta: 'EVENTO',
                  controller: evento,
                  placeholder: 'Buscar en el evento',
                  icon: CupertinoIcons.search,
                  onChanged: onEvento,
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
                  etiqueta: 'CÓMO SE ANOTÓ',
                  valor: registradoPor ?? '',
                  items: const [
                    SelectorItem(id: '', etiqueta: 'Las dos'),
                    SelectorItem(id: Asistencia.qr, etiqueta: 'QR'),
                    SelectorItem(id: Asistencia.manual, etiqueta: 'Manual'),
                  ],
                  vacio: 'Las dos',
                  limpiar: registradoPor == null
                      ? null
                      : () => onRegistro(null),
                  onChanged: (valor) =>
                      onRegistro(valor == null || valor.isEmpty ? null : valor),
                ),
              ),
              const SizedBox(width: Espaciado.sm),
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
    required this.planta,
    required this.puedeEscribir,
    required this.controller,
    required this.onEditar,
    required this.onEliminar,
  });

  final AsistenciasState estado;
  final bool hayFiltro;
  final String? planta;
  final bool puedeEscribir;
  final AsistenciasController controller;
  final ValueChanged<Asistencia> onEditar;
  final ValueChanged<Asistencia> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (estado.asistencias.isEmpty) {
      // Distinguir "no hay asistencias" de "no hay ninguna con ese filtro" son
      // dos problemas distintos, y la pista para cada uno es otra.
      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ninguna asistencia coincide con el filtro.'
                : 'Todavía no se ha registrado ninguna asistencia.',
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
      itemCount: estado.asistencias.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.asistencias.length) {
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

        final asistencia = estado.asistencias[indice];
        return _FilaAsistencia(
          asistencia: asistencia,
          planta: planta,
          puedeEscribir: puedeEscribir,
          onEditar: () => onEditar(asistencia),
          onEliminar: () => onEliminar(asistencia),
        );
      },
    );
  }
}

/// "3 por QR de 10 en esta página".
///
/// Enseñar solo el total no dice nada: lo interesante es cuántas se escanearon y
/// cuántas se apuntaron de memoria.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final AsistenciasState estado;

  @override
  Widget build(BuildContext context) {
    final total = estado.asistencias.length;

    return Text(
      '${estado.porQr} por QR de $total en esta página · ${estado.total} en total',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }
}

/// Una asistencia: el evento en grande y el proveedor debajo.
class _FilaAsistencia extends StatelessWidget {
  const _FilaAsistencia({
    required this.asistencia,
    required this.planta,
    required this.puedeEscribir,
    required this.onEditar,
    required this.onEliminar,
  });

  final Asistencia asistencia;
  final String? planta;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // El nombre del catálogo si lo hay, y el texto que se
                      // escribió si no: las asistencias viejas no tienen
                      // evento del catálogo y siguen enseñando lo suyo.
                      asistencia.eventoLegible,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asistencia.nombreProveedor} · ${asistencia.fechaLegible}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    // La planta va en cada fila, no solo en el resumen. No es un
                    // filtro —el backend ya aísla y todo lo que se ve es de la
                    // misma— sino una etiqueta que quita la duda de si lo que
                    // estás mirando es de aquí o de al lado.
                    if (planta != null) ...[
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
              AppPill(
                texto: asistencia.etiquetaRegistro,
                color: asistencia.esQr
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemGrey,
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
                      style: TextStyle(
                        color: AppTheme.verde,
                        fontWeight: FontWeight.w600,
                      ),
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

  final AsistenciasState estado;
  final AsistenciasController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Text(
        '${estado.total} asistencia${estado.total == 1 ? '' : 's'}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: estado.hayAnterior
              ? () => controller.irAPagina(estado.pagina - 1)
              : null,
          child: const Icon(CupertinoIcons.chevron_left, size: 20),
        ),
        Text(
          'Página ${estado.pagina} de ${estado.totalPaginas}',
          style: const TextStyle(fontSize: 14),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: estado.haySiguiente
              ? () => controller.irAPagina(estado.pagina + 1)
              : null,
          child: const Icon(CupertinoIcons.chevron_right, size: 20),
        ),
      ],
    );
  }
}
