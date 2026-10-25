import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/recorrido.dart';
import 'lista_recorridos_page.dart';
import 'providers/recorridos_controller.dart';
import 'recorrido_form_page.dart';

/// Detalle de un recorrido y, con él, su ciclo de vida.
///
/// **Los botones dependen del estado, no de los permisos.** Un recorrido
/// `FINALIZADO` no enseña ni iniciar ni finalizar ni atender paradas, porque el
/// servidor los rechaza con un 400 y un botón que da error es peor que no
/// tenerlo. Cancelar sí aparece hasta el final, porque vale desde cualquier
/// estado menos `FINALIZADO`.
class RecorridoDetallePage extends ConsumerStatefulWidget {
  const RecorridoDetallePage({super.key, required this.recorridoId});

  final int recorridoId;

  @override
  ConsumerState<RecorridoDetallePage> createState() => _RecorridoDetallePageState();
}

class _RecorridoDetallePageState extends ConsumerState<RecorridoDetallePage> {
  Recorrido? _recorrido;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Se pide en `initState` y no en el `build`: el recorrido tiene un id fijo,
    // así que volver a pedirlo en cada reconstrucción sería viajar a la API en
    // cada `setState` —y aquí hay muchos, porque cada transición repinta.
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final recorrido = await ref.read(recorridoRepositoryProvider).ver(widget.recorridoId);
      if (!mounted) {
        return;
      }
      setState(() {
        _recorrido = recorrido;
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
    final recorrido = _recorrido;
    final permisos = ref.watch(permisosProvider);
    final enAccion = ref.watch(recorridosControllerProvider).enAccion;
    final puedeEscribir = permisos.puedeCon('recorridos', 'write');

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(recorrido?.fechaLegible ?? 'Recorrido'),
        trailing: recorrido != null && puedeEscribir && recorrido.puedeIniciar
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: enAccion ? null : () => _editar(context, recorrido),
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
                      _Cabecera(recorrido: recorrido!),

                      if (puedeEscribir) ...[
                        const SizedBox(height: Espaciado.lg),
                        _CicloDeVida(
                          recorrido: recorrido,
                          enAccion: enAccion,
                          onIniciar: () => _transicion(recorrido, 'iniciar'),
                          onFinalizar: () => _transicion(recorrido, 'finalizar'),
                          onCancelar: () => _cancelar(recorrido),
                        ),
                      ],

                      const SizedBox(height: Espaciado.lg),
                      AppSectionTitle('Paradas'),
                      const SizedBox(height: Espaciado.sm),
                      ..._paradas(recorrido, puedeEscribir, enAccion),
                    ],
                  ),
      ),
    );
  }

  List<Widget> _paradas(Recorrido recorrido, bool puedeEscribir, bool enAccion) {
    if (recorrido.paradas.isEmpty) {
      return const [
        AppNotice(
          texto: 'Este recorrido aún no tiene paradas. Se sellan al iniciarlo, '
              'con las que tenga la ruta en ese momento.',
          color: CupertinoColors.secondaryLabel,
        ),
      ];
    }

    return [
      ...recorrido.paradas.map(
        (parada) => Padding(
          padding: const EdgeInsets.only(bottom: Espaciado.sm),
          child: _FilaParada(
            parada: parada,
            puedeAtender: puedeEscribir && recorrido.puedeAtenderParadas,
            enAccion: enAccion,
            onAtender: () => _atender(recorrido, parada),
          ),
        ),
      ),
      if (recorrido.estado == EstadoRecorrido.finalizado)
        const AppNotice(
          texto: 'Al finalizar, las paradas que seguían pendientes pasaron a '
              'omitidas. Ya no se pueden atender.',
          color: CupertinoColors.secondaryLabel,
        ),
    ];
  }

  /// Abre el formulario y, al volver, vuelve a pedir el recorrido.
  ///
  /// Es `async` y no un `async` sin `await`: se encadena con `then` para recargar
  /// al cerrar. Declararlo `Future<void>` sin devolver nada es lo que hace que
  /// quien llame no sepa si esperar o no.
  Future<void> _editar(BuildContext contexto, Recorrido recorrido) async {
    await Navigator.of(contexto).push(
      CupertinoPageRoute<void>(
        builder: (_) => RecorridoFormPage(recorrido: recorrido),
      ),
    );

    if (mounted) {
      await _cargar();
    }
  }

  /// Iniciar y finalizar son un botón y un mensaje, sin más decisiones de por
  /// medio. Lo que hacen no tiene marcha atrás, así que se confirman.
  Future<void> _transicion(Recorrido recorrido, String accion) async {
    final esIniciar = accion == 'iniciar';

    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: Text(esIniciar ? '¿Iniciar el recorrido?' : '¿Finalizar el recorrido?'),
        content: Text(
          esIniciar
              // Iniciar sella las paradas de la ruta. Decirlo aquí evita que
              // alguien lo haga sin saber que a partir de ese momento las
              // paradas son fijas.
              ? 'Se copiarán a este recorrido las paradas de la ruta tal como '
                  'estén ahora, y se anotará la hora real de salida.'
              : 'Las paradas que sigan pendientes quedarán como omitidas.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Volver'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(esIniciar ? 'Iniciar' : 'Finalizar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) {
      return;
    }

    final controller = ref.read(recorridosControllerProvider.notifier);
    final ok = esIniciar
        ? await controller.iniciar(recorrido)
        : await controller.finalizar(recorrido);

    if (ok && mounted) {
      // La respuesta trae el recorrido entero ya actualizado, con las paradas
      // selladas o las omitidas. Se vuelve a pedir para que lo que se ve sea
      // exactamente lo que guardó el servidor.
      await _cargar();
    }
  }

  /// Cancelar pide un motivo, porque el recorrido queda con él anotado y es lo
  /// único que queda para saber por qué no se hizo.
  Future<void> _cancelar(Recorrido recorrido) async {
    final motivo = TextEditingController();

    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('¿Cancelar el recorrido?'),
        content: CupertinoTextField(
          controller: motivo,
          placeholder: 'Motivo de la cancelación',
          maxLines: 2,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Volver'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Cancelar recorrido'),
          ),
        ],
      ),
    );

    motivo.dispose();

    if (confirmado != true || !mounted) {
      return;
    }

    // El texto sobrevive al `dispose` del controlador porque se copió al llamar.
    final texto = motivo.text.trim();
    await ref.read(recorridosControllerProvider.notifier).cancelar(
          recorrido,
          observaciones: texto.isEmpty ? null : texto,
        );

    if (mounted) {
      await _cargar();
    }
  }

  Future<void> _atender(Recorrido recorrido, ParadaRecorrido parada) async {
    final ok = await ref
        .read(recorridosControllerProvider.notifier)
        .atenderParada(recorrido, parada);

    if (ok && mounted) {
      await _cargar();
    }
  }
}

/// Estado, ruta, unidad, acopiador, ayudante y horario previsto y real.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.recorrido});

  final Recorrido recorrido;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EstadoPill(estado: recorrido.estado),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: Text(
                  recorrido.ruta?.nombre ?? 'Ruta #${recorrido.rutaId}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaciado.sm),
          _Dato(etiqueta: 'Unidad', valor: recorrido.unidad?.nombre ?? 'Unidad #${recorrido.unidadId}'),
          _Dato(etiqueta: 'Acopiador', valor: recorrido.acopiador?.nombreCompleto ?? 'Acopiador #${recorrido.acopiadorId}'),
          _Dato(etiqueta: 'Fecha', valor: recorrido.fechaLegible),
          _Dato(etiqueta: 'Previsto', valor: recorrido.horarioPrevisto),
          // El horario real solo existe si el recorrido arrancó. Se enseña
          // aparte del previsto porque son dos cosas distintas: lo que se
          //ượplaneó y lo que pasó.
          if (recorrido.horaInicioReal != null)
            _Dato(
              etiqueta: 'Real',
              valor: '${horaCorta(recorrido.horaInicioReal)}'
                  '${recorrido.horaFinReal == null ? '' : ' – ${horaCorta(recorrido.horaFinReal)}'}',
            ),
          if (recorrido.kilometrajeInicio != null)
            _Dato(etiqueta: 'Km', valor: _kilometros(recorrido)),
          if (recorrido.ayudante != null)
            _Dato(etiqueta: 'Ayudante', valor: recorrido.ayudante!),
          if (recorrido.observaciones != null && recorrido.observaciones!.isNotEmpty)
            _Dato(etiqueta: 'Observaciones', valor: recorrido.observaciones!),
        ],
      ),
    );
  }

  /// Kilómetros: los dos si se rellenaron, uno si solo se knows el de salida.
  static String _kilometros(Recorrido r) {
    final inicio = r.kilometrajeInicio!.toStringAsFixed(0);
    if (r.kilometrajeFin == null) {
      return '$inicio km';
    }
    return '$inicio → ${r.kilometrajeFin!.toStringAsFixed(0)} km';
  }
}

/// Una línea etiqueta-valor.
class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Espaciado.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los botones del ciclo de vida.
///
/// Solo se enseñan los que el estado permite. La lista completa está en el
/// dominio (`puedeIniciar`, `puedeFinalizar`, `puedeCancelar`), no en la
/// pantalla, para que un test pueda comprobarla sin montar un widget.
class _CicloDeVida extends StatelessWidget {
  const _CicloDeVida({
    required this.recorrido,
    required this.enAccion,
    required this.onIniciar,
    required this.onFinalizar,
    required this.onCancelar,
  });

  final Recorrido recorrido;
  final bool enAccion;
  final VoidCallback onIniciar;
  final VoidCallback onFinalizar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final botones = <Widget>[];

    if (recorrido.puedeIniciar) {
      botones.add(
        AppButton(
          texto: 'Iniciar recorrido',
          icon: CupertinoIcons.play_fill,
          onPressed: enAccion ? null : onIniciar,
        ),
      );
    }

    if (recorrido.puedeFinalizar) {
      botones.add(
        AppButton(
          texto: 'Finalizar recorrido',
          icon: CupertinoIcons.flag_fill,
          onPressed: enAccion ? null : onFinalizar,
        ),
      );
    }

    if (recorrido.puedeCancelar) {
      botones.add(
        AppButton(
          texto: 'Cancelar recorrido',
          tono: AppButton.tonoSecundario,
          icon: CupertinoIcons.xmark,
          onPressed: enAccion ? null : onCancelar,
        ),
      );
    }

    if (botones.isEmpty) {
      // Finalizado no admite nada más. Decirlo es mejor que dejar la pantalla
      // con un hueco donde debía haber botones.
      return const AppNotice(
        texto: 'Este recorrido ya está finalizado. No admite más cambios.',
        color: CupertinoColors.secondaryLabel,
      );
    }

    return Column(
      children: [
        for (final boton in botones) ...[
          boton,
          const SizedBox(height: Espaciado.sm),
        ],
      ],
    );
  }
}

/// Una parada del recorrido con su estado y su botón de atender.
class _FilaParada extends StatelessWidget {
  const _FilaParada({
    required this.parada,
    required this.puedeAtender,
    required this.enAccion,
    required this.onAtender,
  });

  final ParadaRecorrido parada;
  final bool puedeAtender;
  final bool enAccion;
  final VoidCallback onAtender;

  @override
  Widget build(BuildContext context) {
    final atendida = parada.atendida;
    final omitida = parada.omitida;

    return AppCard(
      child: Row(
        children: [
          // El número va en un círculo: fija el orden del recorrido y tiene que
          // verse de un vistazo.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: atendida
                  ? AppTheme.verde
                  : omitida
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.systemGrey4,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${parada.orden}',
              style: TextStyle(
                color: omitida
                    ? CupertinoColors.systemGrey
                    : atendida
                        ? CupertinoColors.white
                        : CupertinoColors.secondaryLabel,
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
                if (parada.horaLlegada != null)
                  Text(
                    horaCorta(parada.horaLlegada)!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          if (atendida)
            const AppPill(texto: 'atendida', color: AppTheme.verde)
          else if (omitida)
            const AppPill(texto: 'omitida', color: CupertinoColors.systemGrey)
          else if (puedeAtender)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: Espaciado.md),
              color: AppTheme.verde,
              onPressed: enAccion ? null : onAtender,
              child: const Text(
                'Atender',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          else
            const AppPill(texto: 'pendiente', color: CupertinoColors.systemGrey2),
        ],
      ),
    );
  }
}

/// Fallo al pedir el recorrido, con un botón para reintentar.
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
