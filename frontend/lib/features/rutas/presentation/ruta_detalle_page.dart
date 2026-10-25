import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/ruta.dart';
import 'providers/rutas_controller.dart';
import 'ruta_form_page.dart';

/// Detalle de una ruta: sus datos, sus zonas y sus paradas en orden.
///
/// **Las paradas se muestran pero no se editan todavía.** Añadir, quitar o
/// reordenar una parada es `POST/DELETE /rutas/{id}/paradas`, y cada una es un
/// proveedor en un punto del recorrido: no hay nada que elegir hasta que exista
/// el módulo de Proveedores. Cuando llegue, estas acciones se añaden aquí sobre
/// las que ya están.
class RutaDetallePage extends ConsumerStatefulWidget {
  const RutaDetallePage({super.key, required this.rutaId});

  final int rutaId;

  @override
  ConsumerState<RutaDetallePage> createState() => _RutaDetallePageState();
}

class _RutaDetallePageState extends ConsumerState<RutaDetallePage> {
  RutaDetalle? _ruta;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Se pide en `initState` y no en el `build`: la pantalla tiene un `rutaId`
    // fijo, así que volver a pedirlo en cada reconstrucción sería viajar a la
    // API en cada `setState` del propio formulario de una parada.
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final ruta = await ref.read(rutaRepositoryProvider).ver(widget.rutaId);
      if (!mounted) {
        return;
      }
      setState(() {
        _ruta = ruta;
        _cargando = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;
    final permisos = ref.watch(permisosProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(ruta?.nombre ?? 'Ruta'),
        trailing: ruta != null && permisos.puedeCon('rutas', 'write')
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: () => _editar(context, ruta),
                child: const Icon(CupertinoIcons.pencil),
              )
            : null,
        border: null,
      ),
      child: SafeArea(
        child: _cargando
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? _Error(error: _error!, alReintentar: _cargar)
                : ListView(
                    padding: const EdgeInsets.all(Espaciado.md),
                    children: [
                      _Cabecera(ruta: ruta!),
                      const SizedBox(height: Espaciado.lg),

                      AppSectionTitle('Zonas'),
                      const SizedBox(height: Espaciado.sm),
                      if (ruta.zonas.isEmpty)
                        const AppNotice(
                          texto: 'Esta ruta no tiene zonas asignadas.',
                          color: CupertinoColors.secondaryLabel,
                        )
                      else
                        Wrap(
                          spacing: Espaciado.xs,
                          runSpacing: Espaciado.xs,
                          children: ruta.zonas
                              .map(
                                (z) => AppPill(
                                  texto: z.nombre,
                                  color: CupertinoColors.systemBlue,
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: Espaciado.lg),

                      AppSectionTitle('Paradas'),
                      const SizedBox(height: Espaciado.sm),
                      if (ruta.paradas.isEmpty)
                        const AppNotice(
                          texto: 'Esta ruta todavía no tiene paradas.',
                          color: CupertinoColors.secondaryLabel,
                        )
                      else
                        ...ruta.paradas.indexed.map(
                          (parada) => Padding(
                            padding: const EdgeInsets.only(bottom: Espaciado.sm),
                            child: _FilaParada(parada: parada.$2),
                          ),
                        ),
                      const SizedBox(height: Espaciado.sm),
                      // El aviso va **siempre**, tenga paradas o no: ahora
                      // mismo no hay forma de tocar la lista en ninguno de los
                      // dos casos, y esconderlo solo cuando ya hay algo que
                      // tocar daría la impresión de que con paradas sí se puede.
                      const AppNotice(
                        texto: 'Añadir, quitar y reordenar paradas llega con el '
                            'módulo de Proveedores: una parada es un proveedor, '
                            'y todavía no hay cuáles elegir.',
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ],
                  ),
      ),
    );
  }

  void _editar(BuildContext contexto, Ruta ruta) {
    Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RutaFormPage(ruta: ruta),
      ),
    ).then((_) => _cargar());
  }
}

/// Nombre, código, horario y estado.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.ruta});

  final RutaDetalle ruta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ruta.codigo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppPill(
                texto: ruta.activa ? 'activa' : 'inactiva',
                color: ruta.activa ? AppTheme.verde : CupertinoColors.systemGrey,
              ),
            ],
          ),
          const SizedBox(height: Espaciado.xs),
          Text(
            ruta.horario,
            style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
          ),
          if (ruta.descripcion != null && ruta.descripcion!.isNotEmpty) ...[
            const SizedBox(height: Espaciado.sm),
            Text(ruta.descripcion!),
          ],
        ],
      ),
    );
  }
}

/// Una parada: el orden, el proveedor y la hora estimada.
class _FilaParada extends StatelessWidget {
  const _FilaParada({required this.parada});

  final ParadaRuta parada;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          // El número va en un círculo y no como texto suelto: es lo que fija el
          // orden del recorrido, y tiene que verse de un vistazo.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.verde,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${parada.orden}',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: Espaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parada.proveedor?.nombreCompleto ?? 'Proveedor ${parada.proveedorId}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (parada.horaEstimada != null)
                  Text(
                    _horaCorta(parada.horaEstimada!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          if (!parada.activa)
            const AppPill(texto: 'inactiva', color: CupertinoColors.systemGrey),
        ],
      ),
    );
  }

  static String _horaCorta(String valor) =>
      valor.length >= 5 ? valor.substring(0, 5) : valor;
}

/// Fallo al pedir la ruta, con un botón para reintentar.
class _Error extends StatelessWidget {
  const _Error({required this.error, required this.alReintentar});

  final String error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Espaciado.md),
      children: [
        const SizedBox(height: Espaciado.xl),
        AppErrorBanner(mensaje: error),
        const SizedBox(height: Espaciado.md),
        AppButton(
          texto: 'Reintentar',
          tono: AppButton.tonoSecundario,
          onPressed: alReintentar,
        ),
      ],
    );
  }
}
