import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../uploads/domain/imagen.dart';
import '../../uploads/presentation/providers/imagen_controller.dart';
import '../../uploads/presentation/selector_imagen.dart';
import '../domain/producto.dart';
import 'providers/productos_controller.dart';

/// Alta y edición de un producto.
///
/// El mismo formulario para las dos cosas: `producto` a `null` es un alta.
/// Separar los dos duplicaría los campos y sus validaciones, que es justo lo
/// que hay que evitar cuando un cambio de un campo obliga a tocar los dos sitios.
class ProductoFormPage extends ConsumerStatefulWidget {
  const ProductoFormPage({super.key, this.producto});

  /// El producto a editar, o `null` para dar de alta uno nuevo.
  final Producto? producto;

  @override
  ConsumerState<ProductoFormPage> createState() => _ProductoFormPageState();
}

class _ProductoFormPageState extends ConsumerState<ProductoFormPage> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _unidad = TextEditingController();
  final _precio = TextEditingController();

  late bool _estado;

  /// Errores por campo.
  ///
  /// `AppTextField` no valida por su cuenta: lleva `errorText` y quien lo usa
  /// decide el mensaje. Por eso no hay `Form` con `validator`, sino este mapa.
  final _errores = <String, String>{};

  String? _errorGeneral;
  bool _guardando = false;

  /// La imagen que tiene ahora el producto, tal y como la devolvió el servidor.
  ///
  /// Vive aquí y no se lee de la lista porque el `SelectorImagen` no avisa de qué
  /// ha hecho: avisa con `ImagenLista`, y quien debe ir a buscar la columna
  /// actualizada es quien entiende del producto.
  String? _imagen;

  bool get esAlta => widget.producto == null;

  @override
  void initState() {
    super.initState();

    final producto = widget.producto;
    _nombre.text = producto?.nombre ?? '';
    _descripcion.text = producto?.descripcion ?? '';
    _unidad.text = producto?.unidadMedida ?? '';
    _precio.text = producto == null
        ? ''
        : producto.precioVenta.toStringAsFixed(2).replaceAll('.', ',');
    _estado = producto?.estado ?? true;
    _imagen = producto?.imagen;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _unidad.dispose();
    _precio.dispose();
    super.dispose();
  }

  /// Cuando el controlador de imágenes termina algo, el backend ya actualizó la
  /// columna `imagen` del producto. Aquí se vuelve a pedirlo para que el
  /// formulario enseñe la nueva y no la anterior.
  void _alCambiarLaImagen(ImagenState estado, Producto? producto) {
    final actual = estado.estado;
    if (actual is! ImagenLista || producto == null) {
      return;
    }

    // Solo reacciona si lo que cambió es la imagen: el estado es global y otros
    // módulos también lo usan.
    if (actual.ruta == producto.imagen) {
      return;
    }

    _refrescarImagen(producto.id);
  }

  Future<void> _refrescarImagen(int id) async {
    try {
      final actualizado = await ref.read(productoRepositoryProvider).ver(id);
      if (mounted) {
        setState(() => _imagen = actualizado.imagen);
      }
    } on AppException {
      // La imagen se verá la próxima vez que se abra el producto. Fallar aquí
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

    if (nombre.isEmpty) {
      errores['nombre'] = 'Ponle un nombre al producto.';
    } else if (nombre.length > 150) {
      errores['nombre'] = 'Máximo 150 caracteres.';
    }

    final unidad = _unidad.text.trim();
    if (unidad.length > 30) {
      errores['unidad'] = 'Máximo 30 caracteres.';
    }

    final textoPrecio = _precio.text.trim();
    if (textoPrecio.isEmpty) {
      errores['precio'] = 'Indica el precio de venta.';
    } else {
      final numero = double.tryParse(textoPrecio.replaceAll(',', '.'));
      if (numero == null) {
        errores['precio'] = 'Eso no es un número.';
      } else if (numero < 0) {
        errores['precio'] = 'El precio no puede ser negativo.';
      } else if (numero > 99999999.99) {
        // El servidor guarda DECIMAL(10,2): dos decimales y ocho de entero.
        errores['precio'] = 'El precio es demasiado alto.';
      }
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

    final precio = double.parse(_precio.text.trim().replaceAll(',', '.'));
    final descripcion = _descripcion.text.trim();
    final unidad = _unidad.text.trim();

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(productosControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            descripcion: descripcion,
            unidadMedida: unidad,
            precioVenta: precio,
            estado: _estado,
          )
        : await controller.editar(
            widget.producto!,
            nombre: _nombre.text.trim(),
            descripcion: descripcion,
            unidadMedida: unidad,
            precioVenta: precio,
            estado: _estado,
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
      _errorGeneral = ref.read(productosControllerProvider).error?.message
          ?? 'No se pudo guardar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final producto = widget.producto;
    final imagenes = ref.watch(imagenControllerProvider);

    // Se avisa del cambio de imagen aquí, en el build, y no en un `listener`: el
    // `SelectorImagen` no expone ningún aviso, solo cambia el estado.
    if (producto != null) {
      _alCambiarLaImagen(imagenes, producto);
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nuevo producto' : 'Editar producto'),
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
              placeholder: 'Yogurt natural 1 L',
              icon: CupertinoIcons.tag,
              textInputAction: TextInputAction.next,
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'DESCRIPCIÓN',
              controller: _descripcion,
              placeholder: 'Yogurt entero de leche fresca',
              icon: CupertinoIcons.text_alignleft,
              maxLines: 4,
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'UNIDAD DE MEDIDA',
              controller: _unidad,
              placeholder: 'unidad, litro, kilo…',
              icon: CupertinoIcons.cube_box,
              textInputAction: TextInputAction.next,
              errorText: _errores['unidad'],
            ),
            const SizedBox(height: Espaciado.sm),

            // Atajos para lo habitual. El campo sigue siendo de escritura
            // libre: el servidor acepta cualquier texto de hasta 30
            // caracteres, y una lista cerrada obligaría a adivinar.
            Wrap(
              spacing: Espaciado.xs,
              children: unidadesSugeridas
                  .map(
                    (u) => CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espaciado.sm,
                        vertical: Espaciado.xs,
                      ),
                      minimumSize: const Size(0, 30),
                      color: CupertinoColors.white,
                      onPressed: _guardando ? null : () => setState(() => _unidad.text = u),
                      child: Text(
                        u,
                        style: const TextStyle(fontSize: 13, color: CupertinoColors.label),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'PRECIO DE VENTA',
              controller: _precio,
              placeholder: '3,75',
              icon: CupertinoIcons.money_dollar,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              errorText: _errores['precio'],
            ),
            const SizedBox(height: Espaciado.md),

            _Interruptor(
              titulo: 'Activo',
              subtitulo: 'Si no, deja de aparecer en la lista de precios.',
              valor: _estado,
              onChanged: (v) => setState(() => _estado = v),
            ),

            const SizedBox(height: Espaciado.lg),

            // La galería va al final, y solo al editar: una imagen necesita un
            // producto al que colgarse, y en el alta todavía no existe.
            if (producto != null) ...[
              AppSectionTitle('Imagen'),
              const SizedBox(height: Espaciado.sm),
              SelectorImagen(
                recurso: RecursoImagen.producto,
                id: producto.id,
                rutaActual: _imagen,
              ),
              const SizedBox(height: Espaciado.lg),
            ] else ...[
              const AppNotice(
                texto: 'Podrás añadir una imagen cuando el producto esté '
                    'guardado: necesita un registro al que colgarse.',
                color: CupertinoColors.secondaryLabel,
              ),
              const SizedBox(height: Espaciado.lg),
            ],

            AppButton(
              texto: esAlta ? 'Crear producto' : 'Guardar cambios',
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