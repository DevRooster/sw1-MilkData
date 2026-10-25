import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../proveedores/presentation/providers/proveedores_controller.dart';
import '../domain/notificacion.dart';
import 'providers/notificaciones_controller.dart';

/// Alta, edición y envío de un aviso.
///
/// **Hay dos formas de guardar y no son la misma con un interruptor**:
///
/// - *Guardar borrador* llama a `POST /notificaciones`. El aviso queda en la base
///   y el proveedor no lo ve.
/// - *Enviar ahora* llama a `POST /notificaciones/enviar`. Es otro endpoint: el
///   servidor lo manda y le pone la fecha. **Manda antes de guardar**, así que si
///   el envío falla no queda nada guardado.
///
/// Editar uno ya enviado **avisa** de que quien lo recibió ya lo tiene, pero no
/// lo impide: el servidor lo acepta sin preguntar, y bloquearlo aquí sería
/// inventarse una regla que el backend no tiene.
class NotificacionFormPage extends ConsumerStatefulWidget {
  const NotificacionFormPage({super.key, this.notificacion});

  /// El aviso a editar, o `null` para redactar uno nuevo.
  final Notificacion? notificacion;

  @override
  ConsumerState<NotificacionFormPage> createState() => _NotificacionFormPageState();
}

class _NotificacionFormPageState extends ConsumerState<NotificacionFormPage> {
  final _titulo = TextEditingController();
  final _mensaje = TextEditingController();

  String _tipo = Notificacion.adulteracion;

  /// El destinatario, como texto de id para el desplegable.
  ///
  /// Vacío significa "toda la planta", que es una opción de verdad del modelo:
  /// `proveedorId` es opcional en la base.
  String _proveedorId = '';

  final _errores = <String, String>{};
  String? _errorGeneral;
  bool _guardando = false;

  bool get esAlta => widget.notificacion == null;

  /// Si el aviso ya salió, no tiene sentido ofrecer volver a mandarlo.
  bool get yaEnviada => widget.notificacion?.enviada ?? false;

  @override
  void initState() {
    super.initState();

    final notificacion = widget.notificacion;
    if (notificacion == null) {
      return;
    }

    _titulo.text = notificacion.titulo;
    _mensaje.text = notificacion.mensaje;
    _tipo = notificacion.tipo;
    _proveedorId = notificacion.proveedorId?.toString() ?? '';
  }

  @override
  void dispose() {
    _titulo.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  /// `int.tryParse` y no `int.parse`: un id mal formado tiene que acabar siendo
  /// "nadie" y no un FormatError en plena pantalla.
  int? get _proveedor => int.tryParse(_proveedorId.isEmpty ? '' : _proveedorId);

  bool _validar() {
    final errores = <String, String>{};

    if (_titulo.text.trim().isEmpty) {
      errores['titulo'] = 'Ponle un título.';
    } else if (_titulo.text.trim().length > 150) {
      // `STRING(150)` en la base. MySQL lo recortaría en silencio, y un título
      // cortado a media palabra es peor que un aviso de error.
      errores['titulo'] = 'El título es demasiado largo.';
    }

    if (_mensaje.text.trim().isEmpty) {
      errores['mensaje'] = 'Escribe el aviso.';
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  Future<void> _guardar({required bool enviar}) async {
    if (!_validar()) {
      return;
    }

    // El `usuarioId` es quién escribe. Va aquí, no en el desplegable: no es una
    // decisión de quien rellena, es quien está delante del móvil.
    // `usuario` vive en `Autenticado`, no en `AuthState`, así que hay que estrechar
    // el tipo antes de leerlo.
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

    final controller = ref.read(notificacionesControllerProvider.notifier);
    final proveedor = _proveedor;

    final ok = esAlta
        ? enviar
            ? await controller.enviar(
                tipo: _tipo,
                titulo: _titulo.text.trim(),
                mensaje: _mensaje.text.trim(),
                proveedorId: proveedor,
                usuarioId: estado.usuario.id,
              )
            : await controller.crear(
                tipo: _tipo,
                titulo: _titulo.text.trim(),
                mensaje: _mensaje.text.trim(),
                proveedorId: proveedor,
                usuarioId: estado.usuario.id,
              )
        : await controller.editar(
            widget.notificacion!,
            tipo: _tipo,
            titulo: _titulo.text.trim(),
            mensaje: _mensaje.text.trim(),
            proveedorId: proveedor,
            usuarioId: estado.usuario.id,
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
          ref.read(notificacionesControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final proveedores = ref.watch(opcionesDeProveedorProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          esAlta
              ? 'Nuevo aviso'
              : yaEnviada
                  ? 'Editar aviso enviado'
                  : 'Editar borrador',
        ),
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

            if (!esAlta && yaEnviada) ...[
              // Se avisa, no se bloquea: el servidor acepta cambiar un aviso que
              // el proveedor ya leyó, y fingir aquí que no se puede sería
              // mentir sobre lo que hace el backend.
              const AppNotice(
                texto: 'Este aviso ya se envió. Quien lo recibió tiene la versión '
                    'antigua, y desde aquí no hay forma de retirarlo.',
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(height: Espaciado.md),
            ],

            AppSectionTitle('¿De qué tipo?'),
            const SizedBox(height: Espaciado.xs),
            // Tres opciones fijas y pocas: un desplegable con tres entradas
            // cuesta dos toques, y aquí da igual elegir con un toque.
            Column(
              children: [
                for (final valor in Notificacion.tipos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espaciado.xs),
                    child: _FilaTipo(
                      valor: valor,
                      activo: _tipo == valor,
                      onPressed: () => setState(() => _tipo = valor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'TÍTULO',
              controller: _titulo,
              placeholder: 'Lote 12 sospechoso',
              icon: CupertinoIcons.textformat,
              onChanged: (_) => setState(() => _errores.remove('titulo')),
              errorText: _errores['titulo'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'AVISO',
              controller: _mensaje,
              placeholder: 'El análisis dio agua añadida. Ven a la planta.',
              icon: CupertinoIcons.text_alignleft,
              maxLines: 5,
              onChanged: (_) => setState(() => _errores.remove('mensaje')),
              errorText: _errores['mensaje'],
            ),
            const SizedBox(height: Espaciado.md),

            proveedores.when(
              loading: () => const _Esperando(),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar los proveedores.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => AppSelector(
                etiqueta: 'PARA QUIÉN',
                valor: _proveedorId,
                // "Toda la planta" es la primera opción y no un hueco vacío:
                // `proveedorId` es opcional en la base, y un aviso sin
                // destinatario concreto es un caso normal, no un forgot.
                items: [
                  const SelectorItem(id: '', etiqueta: 'Toda la planta'),
                  for (final proveedor in opciones)
                    SelectorItem(
                      id: proveedor.id.toString(),
                      etiqueta: proveedor.nombreCompleto,
                    ),
                ],
                vacio: 'Toda la planta',
                onChanged: (valor) => setState(() => _proveedorId = valor ?? ''),
              ),
            ),
            const SizedBox(height: Espaciado.md),

            if (esAlta) ...[
              const AppNotice(
                texto: 'Guardar lo deja como borrador, sin que lo vea nadie. '
                    'Enviar lo hace llegar y le pone la fecha.',
                color: CupertinoColors.secondaryLabel,
              ),
              const SizedBox(height: Espaciado.md),
              AppButton(
                texto: 'Enviar ahora',
                cargando: _guardando,
                onPressed: () => _guardar(enviar: true),
              ),
              const SizedBox(height: Espaciado.sm),
              AppButton(
                texto: 'Guardar borrador',
                tono: AppButton.tonoSecundario,
                onPressed: _guardando ? null : () => _guardar(enviar: false),
              ),
            ] else ...[
              AppButton(
                texto: 'Guardar cambios',
                cargando: _guardando,
                onPressed: () => _guardar(enviar: false),
              ),
            ],

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

/// Una fila del selector de tipo, con su icono.
class _FilaTipo extends StatelessWidget {
  const _FilaTipo({required this.valor, required this.activo, required this.onPressed});

  final String valor;
  final bool activo;
  final VoidCallback onPressed;

  IconData get _icono {
    switch (valor) {
      case Notificacion.adulteracion:
        return CupertinoIcons.exclamationmark_triangle;
      case Notificacion.reunion:
        return CupertinoIcons.person_3;
      default:
        return CupertinoIcons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.md,
        vertical: Espaciado.sm,
      ),
      color: activo ? AppTheme.verde : CupertinoColors.white,
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(
            _icono,
            size: 18,
            color: activo ? CupertinoColors.white : CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: Espaciado.sm),
          Text(
            Notificacion.etiquetaDeTipo(valor),
            style: TextStyle(
              fontSize: 14,
              fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
              color: activo ? CupertinoColors.white : CupertinoColors.label,
            ),
          ),
        ],
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