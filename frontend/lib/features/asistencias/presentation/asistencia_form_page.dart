import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../eventos/presentation/providers/eventos_controller.dart';
import '../../proveedores/presentation/providers/proveedores_controller.dart';
import '../domain/asistencia.dart';
import 'providers/asistencias_controller.dart';

/// Alta y edición de una asistencia.
///
/// **Los cinco campos son obligatorios.** `registradoPor` es el que sorprende:
/// no tiene valor por defecto en la base, así que sin él el alta falla con un 400
/// hablando de un campo que el usuario no vio nunca. Aquí va siempre puesto.
///
/// El `usuarioId` sale de la sesión. Es obligatorio, pero no es una decisión de
/// quien rellena.
class AsistenciaFormPage extends ConsumerStatefulWidget {
  const AsistenciaFormPage({super.key, this.asistencia});

  /// La asistencia a editar, o `null` para registrar una nueva.
  final Asistencia? asistencia;

  @override
  ConsumerState<AsistenciaFormPage> createState() => _AsistenciaFormPageState();
}

class _AsistenciaFormPageState extends ConsumerState<AsistenciaFormPage> {
  final _evento = TextEditingController();
  final _fecha = TextEditingController();

  String? _proveedorId;

  /// El evento **del catálogo** elegido, o `null` si se escribió el texto suelto.
  ///
  /// Los dos caminos siguen vivos a propósito: hay asistencias ya escritas con
  /// texto libre, y quitar el campo obligaría a elegir un catálogo que en el
  /// momento de esas asistencias no existía.
  String? _eventoId;

  /// El nombre del evento elegido, guardado al elegirlo.
  ///
  /// Va aparte del id para poder mandarlo sin volver a mirar la lista, que puede
  /// haberse recargado entre elegir y guardar.
  String? _eventoNombreElegido;

  /// Por defecto `manual`, que es lo que es esta pantalla: quien la abre está
  /// apuntando, no escaneando un QR. Poner `QR` por defecto daría por hecho algo
  /// que aquí no ocurre.
  String _registradoPor = Asistencia.registroPorDefecto;

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.asistencia == null;

  @override
  void initState() {
    super.initState();

    final asistencia = widget.asistencia;
    if (asistencia == null) {
      // Sin registro se propone hoy: una asistencia se anota el mismo día que
      // ocurre, y tener que escribir la fecha a mano cada vez es un paso de más.
      _fecha.text = _hoy();
      return;
    }

    _evento.text = asistencia.evento;
    _fecha.text = asistencia.fecha;
    _proveedorId = asistencia.proveedorId.toString();
    _registradoPor = asistencia.registradoPor;
    _eventoId = asistencia.eventoId?.toString();
    _eventoNombreElegido = asistencia.eventoCatalogo?.nombre;
  }

  @override
  void dispose() {
    _evento.dispose();
    _fecha.dispose();
    super.dispose();
  }

  /// El día de hoy en `YYYY-MM-DD`, que es lo que espera un `DATEONLY`.
  static String _hoy() {
    final ahora = DateTime.now();
    return '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
  }

  bool _validar() {
    final errores = <String, String>{};

    if (_proveedorId == null) {
      errores['proveedor'] = 'De quién es la asistencia.';
    }

    // **El texto solo es obligatorio si no se eligió un evento del catálogo.**
    // Al elegir uno, el nombre del evento pone el texto y no hay nada que teclear;
    // exigirlo además haría escribir lo mismo dos veces.
    if (_eventoId == null) {
      final evento = _evento.text.trim();
      if (evento.isEmpty) {
        errores['evento'] = 'Elige un evento o escribe de qué se trata.';
      } else if (evento.length > Asistencia.maximoEvento) {
        // El backend responde 400 con el mismo tope, pero verlo en la caja es más
        // útil que descubrirlo después de escribir doscientas letras.
        errores['evento'] =
            'El evento no puede pasar de ${Asistencia.maximoEvento} caracteres.';
      }
    }

    final fecha = _fecha.text.trim();
    if (fecha.isEmpty) {
      errores['fecha'] = 'Ponle el día.';
    } else if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)) {
      errores['fecha'] = 'La fecha se escribe como 2026-10-13.';
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  /// El texto que se manda, con el nombre del evento del catálogo si se eligió uno.
  ///
  /// **Es aquí donde se rellena el campo obligatorio.** La base lo exige siempre,
  /// así que apuntar a un evento del catálogo pone su nombre en el texto. Si no se
  /// hiciera, la fila guardada quedaría con el texto en blanco —o con lo que
  /// quedara de una edición anterior— y la lista no tendría nada que enseñar.
  ///
  /// El nombre sale de `_eventoNombreElegido` y **no de buscarlo en la lista de
  /// eventos**: si el provider se recargara entre elegir y guardar, el nombre se
  /// habría ido y la asistencia se guardaría sin texto, que es obligatorio.
  String _textoDelEvento() {
    final nombre = _eventoNombreElegido;
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }

    return _evento.text.trim();
  }

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    // El `usuarioId` es obligatorio pero no es una decisión de quien rellena:
    // sale de la sesión. `usuario` vive en `Autenticado`, no en `AuthState`, así
    // que hay que estrechar el tipo antes de leerlo.
    final estado = ref.read(authControllerProvider);
    if (estado is! Autenticado) {
      setState(() {
        _guardando = false;
        _errorGeneral = 'Tu sesión se ha cerrado. Vuelve a entrar.';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final textoEvento = _textoDelEvento();
    final eventoId = _eventoId == null ? null : int.tryParse(_eventoId!);

    final controller = ref.read(asistenciasControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            proveedorId: int.parse(_proveedorId!),
            usuarioId: estado.usuario.id,
            evento: textoEvento,
            fecha: _fecha.text.trim(),
            registradoPor: _registradoPor,
            eventoId: eventoId,
          )
        : await controller.editar(
            widget.asistencia!,
            proveedorId: int.parse(_proveedorId!),
            usuarioId: estado.usuario.id,
            evento: textoEvento,
            fecha: _fecha.text.trim(),
            registradoPor: _registradoPor,
            eventoId: eventoId,
          );

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _guardando = false;
      _errorGeneral =
          ref.read(asistenciasControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final proveedores = ref.watch(opcionesDeProveedorProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva asistencia' : 'Editar asistencia'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaciado.md),
          children: [
            if (_errorGeneral != null) ...[
              AppErrorBanner(mensaje: _errorGeneral!),
              const SizedBox(height: Espaciado.md),
            ],

            proveedores.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar los proveedores.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => _DesplegableObligatorio(
                etiqueta: 'PROVEEDOR',
                valor: _proveedorId,
                vacio: opciones.isEmpty ? 'No hay proveedores' : 'Elige el proveedor',
                error: _errores['proveedor'],
                items: opciones
                    .map((p) => SelectorItem(id: p.id.toString(), etiqueta: p.nombreCompleto))
                    .toList(),
                alCambiar: (v) => setState(() {
                  _proveedorId = v;
                  _errores.remove('proveedor');
                }),
              ),
            ),
            const SizedBox(height: Espaciado.md),

            _SelectorEvento(
              eventoId: _eventoId,
              onChanged: (id, nombre) => setState(() {
                _eventoId = id;
                _eventoNombreElegido = nombre;
                // Al elegir del catálogo el campo de texto deja de mandar, así que
                // su error sobraría: se quita para que no se quede una línea roja
                // debajo de un campo que ya no tiene nada que decir.
                if (id != null) {
                  _errores.remove('evento');
                }
              }),
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'EVENTO',
              controller: _evento,
              // Sin pista cerrada a propósito cuando no hay catálogo: `evento` es
              // texto libre y una lista desplegable obligaría a inventarse un
              // catálogo que la base no tiene.
              placeholder: _eventoId == null ? 'Reunión de ruta del Norte' : 'Nombre del evento elegido',
              icon: CupertinoIcons.textformat,
              maxLines: 3,
              // **Se oculta al elegir del catálogo**: el nombre ya lo pone el
              // evento y tener que reescribirlo sería lo mismo dos veces.
              readOnly: _eventoId != null,
              onChanged: (_) => setState(() => _errores.remove('evento')),
              errorText: _errores['evento'],
            ),
            const SizedBox(height: Espaciado.sm),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    etiqueta: 'DÍA',
                    controller: _fecha,
                    placeholder: '2026-10-13',
                    icon: CupertinoIcons.calendar,
                    keyboardType: TextInputType.datetime,
                    onChanged: (_) => setState(() => _errores.remove('fecha')),
                    errorText: _errores['fecha'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.lg),

            AppSectionTitle('¿Cómo se anotó?'),
            const SizedBox(height: Espaciado.xs),
            // Una casilla y no un desplegable: son dos opciones y una casilla
            // deja claro que es una decisión sobre cómo se registró, no un dato
            // que se busca.
            Row(
              children: [
                Expanded(
                  child: _Casilla(
                    texto: 'A mano',
                    activo: _registradoPor == Asistencia.manual,
                    onPressed: () => setState(() => _registradoPor = Asistencia.manual),
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: _Casilla(
                    texto: 'Con QR',
                    activo: _registradoPor == Asistencia.qr,
                    onPressed: () => setState(() => _registradoPor = Asistencia.qr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.sm),
            const AppNotice(
              texto: 'El servidor no tiene valor por defecto para este campo: si no '
                  'se dice cómo se anotó, el alta falla.',
              color: CupertinoColors.secondaryLabel,
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Registrar asistencia' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: _guardar,
            ),

            const SizedBox(height: Espaciado.sm),

            AppButton(
              texto: 'Cancelar',
              tono: AppButton.tonoSecundario,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elige el evento del catálogo al que se apunta la asistencia.
///
/// **Es opcional y hay una alternativa al lado**: el campo de texto de debajo.
/// No se fuerza uno de los dos porque ya hay asistencias escritas con texto
/// libre y no existe un evento del catálogo al que apuntarlas.
class _SelectorEvento extends ConsumerWidget {
  const _SelectorEvento({required this.eventoId, required this.onChanged});

  final String? eventoId;

  /// Devuelve el id y el nombre. Los dos, porque quien elige sabe el nombre en la
  /// mano y no hay que ir a buscarlo después.
  final void Function(String? id, String? nombre) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventos = ref.watch(eventosParaElegirProvider);

    return eventos.maybeWhen(
      loading: () => const AppNotice(
        texto: 'Cargando eventos...',
        color: CupertinoColors.secondaryLabel,
      ),
      error: (error, _) => const AppNotice(
        texto: 'No se pudieron cargar los eventos. Puedes escribir el evento abajo.',
        color: CupertinoColors.systemOrange,
      ),
      data: (lista) {
        if (lista.isEmpty) {
          // Sin eventos **no es un error**: quien va a una charla que no está en
          // el catálogo la puede apuntar igual escribiendo el texto. Avisar en
          // naranja sería meter miedo por algo que tiene salida.
          return const AppNotice(
            texto: 'No hay eventos dados de alta. Puedes escribir el evento abajo, '
                'o crearlo desde el módulo Eventos.',
            color: CupertinoColors.secondaryLabel,
          );
        }

        return AppSelector(
          etiqueta: 'EVENTO DEL CATÁLOGO',
          valor: eventoId ?? '',
          vacio: 'Sin evento elegido',
          items: [
            const SelectorItem(id: '', etiqueta: 'Sin evento'),
            for (final evento in lista)
              SelectorItem(
                id: evento.id.toString(),
                etiqueta: evento.etiquetaCorta,
              ),
          ],
          limpiar: eventoId == null ? null : () => onChanged(null, null),
          onChanged: (valor) {
            final id = valor == null || valor.isEmpty ? null : valor;
            if (id == null) {
              onChanged(null, null);
              return;
            }

            // El nombre se busca aquí y ahora, con la lista delante, que es donde
            // está. No se vuelve a buscar al guardar.
            final nombre = lista
                .where((e) => e.id.toString() == id)
                .firstOrNull
                ?.nombre;

            onChanged(id, nombre);
          },
        );
      },
      orElse: () => const AppNotice(
        texto: 'Cargando eventos...',
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }
}

/// Desplegable con obligatorio y error debajo.
///
/// Envuelto en su propia clase porque el error tiene que salir **debajo** del
/// desplegable, no dentro del `AppSelector`, que no lo admite.
class _DesplegableObligatorio extends StatelessWidget {
  const _DesplegableObligatorio({
    required this.etiqueta,
    required this.valor,
    required this.vacio,
    required this.error,
    required this.items,
    required this.alCambiar,
  });

  final String etiqueta;
  final String? valor;
  final String vacio;
  final String? error;
  final List<SelectorItem> items;
  final ValueChanged<String?> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelector(
          etiqueta: etiqueta,
          valor: valor ?? '',
          vacio: vacio,
          items: items,
          limpiar: valor == null ? null : () => alCambiar(null),
          onChanged: (v) => alCambiar(v == null || v.isEmpty ? null : v),
        ),
        if (error != null) ...[
          const SizedBox(height: Espaciado.xs),
          Text(
            error!,
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemRed),
          ),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: Espaciado.sm),
      color: activo ? AppTheme.verde : CupertinoColors.white,
      onPressed: onPressed,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 14,
          fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
          color: activo ? CupertinoColors.white : CupertinoColors.label,
        ),
      ),
    );
  }
}

/// Un hueco girando mientras llegan los proveedores.
class _Esperando extends StatelessWidget {
  const _Esperando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Espaciado.lg),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}