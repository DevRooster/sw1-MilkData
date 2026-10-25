import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../uploads/domain/imagen.dart';
import '../../uploads/presentation/providers/imagen_controller.dart';
import '../../uploads/presentation/selector_imagen.dart';
import '../../zonas/presentation/providers/zonas_controller.dart';
import '../domain/proveedor.dart';
import 'providers/proveedores_controller.dart';

/// Alta y edición de un proveedor.
///
/// El mismo formulario para las dos cosas: `proveedor` a `null` es un alta.
///
/// **No hay campo de ruta, y no es que se haya olvidado.** En qué ruta está un
/// proveedor se dice en las paradas de esa ruta (`POST /rutas/{id}/paradas`),
/// y el backend rechaza la clave `rutaId` en el alta y en la edición —también
/// cuando vale `null`—. Mandarla "por no poner nada" haría fallar el alta con un
/// 400 que habla de rutas.
class ProveedorFormPage extends ConsumerStatefulWidget {
  const ProveedorFormPage({super.key, this.proveedor});

  /// El proveedor a editar, o `null` para dar de alta uno nuevo.
  final Proveedor? proveedor;

  @override
  ConsumerState<ProveedorFormPage> createState() => _ProveedorFormPageState();
}

class _ProveedorFormPageState extends ConsumerState<ProveedorFormPage> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _dni = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();

  late bool _activo;

  /// Zona elegida, o `null` para ninguna. Va como texto porque el `AppSelector`
  /// trabaja con identificadores de texto.
  String? _zonaId;

  /// Errores por campo.
  ///
  /// `AppTextField` no valida por su cuenta: lleva `errorText` y quien lo usa
  /// decide el mensaje. Por eso no hay `Form` con `validator`, sino este mapa.
  final _errores = <String, String>{};

  String? _errorGeneral;
  bool _guardando = false;

  /// La imagen que tiene ahora el proveedor, tal y como la devolvió el servidor.
  String? _imagen;

  bool get esAlta => widget.proveedor == null;

  @override
  void initState() {
    super.initState();

    final proveedor = widget.proveedor;
    _nombre.text = proveedor?.nombre ?? '';
    _apellido.text = proveedor?.apellido ?? '';
    _dni.text = proveedor?.dni ?? '';
    _telefono.text = proveedor?.telefono ?? '';
    _direccion.text = proveedor?.direccion ?? '';
    _activo = proveedor?.activo ?? true;
    _zonaId = proveedor?.zonaId?.toString();
    _imagen = proveedor?.imagen;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _dni.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  /// Cuando el controlador de imágenes termina algo, el backend ya actualizó la
  /// columna `imagen`. Aquí se vuelve a pedir el proveedor para que el formulario
  /// enseñe la nueva y no la anterior.
  void _alCambiarLaImagen(ImagenState estado, Proveedor? proveedor) {
    final actual = estado.estado;
    if (actual is! ImagenLista || proveedor == null) {
      return;
    }

    // Solo reacciona si lo que cambió es la imagen: el estado es global y otros
    // módulos también lo usan.
    if (actual.ruta == proveedor.imagen) {
      return;
    }

    _refrescarImagen(proveedor.id);
  }

  Future<void> _refrescarImagen(int id) async {
    try {
      final actualizado = await ref.read(proveedorRepositoryProvider).ver(id);
      if (mounted) {
        setState(() => _imagen = actualizado.imagen);
      }
    } catch (_) {
      // La imagen se verá la próxima vez que se abra el proveedor. Fallar aquí
      // sería tapar el formulario por un detalle de una foto.
    }
  }

  /// Valida en cliente y devuelve si se puede seguir.
  ///
  /// El servidor vuelve a validar todo; esto solo evita un viaje y hace que el
  /// error salga junto al campo en vez de en un aviso arriba.
  bool _validar() {
    final errores = <String, String>{};
    final nombre = _nombre.text.trim();
    final apellido = _apellido.text.trim();

    if (nombre.isEmpty) {
      errores['nombre'] = 'Ponle el nombre.';
    } else if (nombre.length > 100) {
      errores['nombre'] = 'Máximo 100 caracteres.';
    }

    if (apellido.isEmpty) {
      errores['apellido'] = 'Ponle al menos un apellido.';
    } else if (apellido.length > 100) {
      errores['apellido'] = 'Máximo 100 caracteres.';
    }

    final dni = _dni.text.trim();
    if (dni.isEmpty) {
      errores['dni'] = 'El DNI es obligatorio.';
    } else if (dni.length > 20) {
      errores['dni'] = 'Máximo 20 caracteres.';
    } else if (!RegExp(r'^\d{6,12}$').hasMatch(dni)) {
      // Solo dígitos. El backend no lo comprueba, así que un "70000001-A"
      // se guardaría y luego no encajaría con el que traiga el documento.
      errores['dni'] = 'El DNI va solo con números.';
    }


    final telefono = _telefono.text.trim();
    if (telefono.isNotEmpty &&
        !RegExp(r'^\+?[\d\s-]{7,30}$').hasMatch(telefono)) {
      errores['telefono'] = 'Un teléfono son dígitos, espacios y un + delante.';
    }

    final direccion = _direccion.text.trim();
    if (direccion.length > 255) {
      errores['direccion'] = 'Máximo 255 caracteres.';
    }

    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });

    return errores.isEmpty;
  }

  Future<void> _guardar() async {
    if (!_validar()) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    // `int.tryParse` y no `int.parse`: un id mal formado tiene que acabar siendo
    // "sin zona" y no un FormatError en plena pantalla.
    final zonaId = _zonaId == null ? null : int.tryParse(_zonaId!);

    final controller = ref.read(proveedoresControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            apellido: _apellido.text.trim(),
            dni: _dni.text.trim(),
            telefono: _telefono.text.trim(),
            direccion: _direccion.text.trim(),
            zonaId: zonaId,
            activo: _activo,
          )
        : await controller.editar(
            widget.proveedor!,
            nombre: _nombre.text.trim(),
            apellido: _apellido.text.trim(),
            dni: _dni.text.trim(),
            telefono: _telefono.text.trim(),
            direccion: _direccion.text.trim(),
            zonaId: zonaId,
            activo: _activo,
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
          ref.read(proveedoresControllerProvider).error?.message ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final proveedor = widget.proveedor;
    final imagenes = ref.watch(imagenControllerProvider);
            final zonas = ref.watch(opcionesDeZonaProvider);

    // Se avisa del cambio de imagen aquí, en el build, y no en un listener: el
    // `SelectorImagen` no expone ningún aviso, solo cambia el estado.
    if (proveedor != null) {
      _alCambiarLaImagen(imagenes, proveedor);
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nuevo proveedor' : 'Editar proveedor'),
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

            AppTextField(
              etiqueta: 'NOMBRE',
              controller: _nombre,
              placeholder: 'Juan',
              icon: CupertinoIcons.person,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'APELLIDO',
              controller: _apellido,
              placeholder: 'Pérez',
              icon: CupertinoIcons.person,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              errorText: _errores['apellido'],
            ),
            const SizedBox(height: Espaciado.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    etiqueta: 'DNI',
                    controller: _dni,
                    placeholder: '70000001',
                    icon: CupertinoIcons.creditcard,
                    keyboardType: TextInputType.number,
                    errorText: _errores['dni'],
                  ),
                ),
                const SizedBox(width: Espaciado.sm),
                Expanded(
                  child: _CampoSoloLectura(
                    etiqueta: 'CÓDIGO',
                    valor: widget.proveedor?.codigo,
                    vacio: esAlta ? 'Se genera al guardar' : 'Sin código',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'TELÉFONO',
              controller: _telefono,
              placeholder: '+51 900 000 000',
              icon: CupertinoIcons.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              errorText: _errores['telefono'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DIRECCIÓN',
              controller: _direccion,
              placeholder: 'Av. Los Álamos 123',
              icon: CupertinoIcons.location,
              maxLines: 2,
              errorText: _errores['direccion'],
            ),
            const SizedBox(height: Espaciado.md),

            zonas.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Espaciado.md),
                  child: CupertinoActivityIndicator(),
                ),
              ),
              error: (error, _) => const AppNotice(
                texto: 'No se pudieron cargar las zonas. Puedes guardar el '
                    'proveedor sin asignarle una.',
                color: CupertinoColors.systemOrange,
              ),
              data: (opciones) => AppSelector(
                etiqueta: 'ZONA',
                valor: _zonaId ?? '',
                vacio: opciones.isEmpty ? 'No hay zonas' : 'Sin zona',
                items: [
                  const SelectorItem(id: '', etiqueta: 'Sin zona'),
                  ...opciones.map(
                    (z) => SelectorItem(id: z.id.toString(), etiqueta: z.nombre),
                  ),
                ],
                limpiar: _zonaId == null ? null : () => setState(() => _zonaId = null),
                onChanged: (valor) => setState(
                  () => _zonaId = (valor == null || valor.isEmpty) ? null : valor,
                ),
              ),
            ),

            const SizedBox(height: Espaciado.md),

            _Interruptor(
              titulo: 'Activo',
              subtitulo: 'Si no, deja de ofrecerse en las nuevas recogidas.',
              valor: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),

            const SizedBox(height: Espaciado.lg),

            // La galería va al final, y solo al editar: una imagen necesita un
            // registro al que colgarse, y en el alta todavía no existe.
            if (proveedor != null) ...[
              AppSectionTitle('Foto'),
              const SizedBox(height: Espaciado.sm),
              SelectorImagen(
                recurso: RecursoImagen.proveedor,
                id: proveedor.id,
                rutaActual: _imagen,
                esAvatar: true,
              ),
              const SizedBox(height: Espaciado.lg),
            ] else ...[
              const AppNotice(
                texto: 'Podrás añadir una foto cuando el proveedor esté '
                    'guardado: necesita un registro al que colgarse.',
                color: CupertinoColors.secondaryLabel,
              ),
              const SizedBox(height: Espaciado.lg),
            ],

            AppButton(
              texto: esAlta ? 'Crear proveedor' : 'Guardar cambios',
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

/// Campo que se enseña pero no se puede escribir.
///
/// El código del proveedor lo pone el servidor —`PROV-006`, `PROV-007`— porque
/// `proveedor.codigo` es único y la app solo ve una página de la lista: no puede
/// saber qué códigos existen. **Por eso aquí no se enseña un número previsto.**
/// Si la app pusiera "PROV-006" y otra persona guardara un proveedor a la vez,
/// uno de los dos fallaría al guardar, y el que falló sería el que confió en lo
/// que le enseñaron.
///
/// La alternativa es un `TextField` deshabilitado, pero en un móvil un campo
/// gris parece un error y no una decisión.
class _CampoSoloLectura extends StatelessWidget {
  const _CampoSoloLectura({
    required this.etiqueta,
    required this.valor,
    required this.vacio,
  });

  final String etiqueta;
  final String? valor;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final puesto = valor != null && valor!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: Espaciado.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaciado.md,
            vertical: Espaciado.sm + 2,
          ),
          decoration: BoxDecoration(
            // El gris de fondo es el de "aquí no se escribe", no el de un campo
            // deshabilitado: se distingue de los campos de verdad.
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(Espaciado.radio),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.number,
                size: 18,
                color: CupertinoColors.tertiaryLabel,
              ),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: Text(
                  puesto ? valor! : vacio,
                  style: TextStyle(
                    fontSize: 16,
                    color: puesto
                        ? CupertinoColors.label
                        : CupertinoColors.placeholderText,
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.lock,
                size: 13,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Interruptor con título y explicación debajo.
class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
