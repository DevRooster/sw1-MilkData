import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../usuarios/data/usuario_api.dart';
import '../../usuarios/data/usuario_repository.dart';
import '../../usuarios/domain/usuario_lista.dart';
import '../domain/unidad.dart';
import 'providers/unidades_controller.dart';

/// Alta y edición de una unidad.
///
/// El mismo formulario para las dos cosas: `unidad` a `null` es un alta. Separar
/// los dos duplicaría los campos y sus validaciones, que es justo lo que hay que
/// evitar cuando un cambio de un campo obliga a tocar los dos sitios.
class UnidadFormPage extends ConsumerStatefulWidget {
  const UnidadFormPage({super.key, this.unidad});

  /// La unidad a editar, o `null` para dar de alta una nueva.
  final Unidad? unidad;

  @override
  ConsumerState<UnidadFormPage> createState() => _UnidadFormPageState();
}

class _UnidadFormPageState extends ConsumerState<UnidadFormPage> {
  final _nombre = TextEditingController();
  final _capacidad = TextEditingController();

  late TipoUnidad _tipo;
  late bool _cerrado;
  late bool _activo;
  int? _acopiadorId;

  /// Errores por campo.
  ///
  /// `AppTextField` no valida por su cuenta: lleva `errorText` y quien lo usa
  /// decide el mensaje. Por eso no hay `Form` con `validator`, sino este mapa,
  /// que además tiene la virtud de no marcar nada hasta que se guarda.
  final _errores = <String, String>{};

  String? _errorGeneral;
  bool _guardando = false;

  /// Candidatos a chófer. `null` mientras no se sepa si este rol puede verlos.
  List<UsuarioLista>? _choferes;
  bool _cargandoChoferes = false;

  bool get esAlta => widget.unidad == null;

  @override
  void initState() {
    super.initState();

    final unidad = widget.unidad;
    _nombre.text = unidad?.nombre ?? '';
    _capacidad.text = unidad == null ? '' : _sinDecimales(unidad.capacidad);
    _tipo = TipoUnidad.desdeTexto(unidad?.tipo);
    _cerrado = unidad?.cerrado ?? false;
    _activo = unidad?.activo ?? true;
    _acopiadorId = unidad?.acopiadorId;

    // El chófer solo se elige si el rol puede leer usuarios, y se pide una vez al
    // abrir. A quien no puede verlos no se le enseña un selector que acabaría en
    // 403: sencillamente no tiene el campo.
    if (_puedeElegirChofer) {
      _cargarChoferes();
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  /// ¿Puede este rol leer `usuarios`?
  ///
  /// Solo el admin y el superadmin. Un supervisor puede escribir unidades pero no
  /// listar usuarios, así que no puede elegir chófer.
  bool get _puedeElegirChofer => ref.read(permisosProvider).puede('usuarios');

  Future<void> _cargarChoferes() async {
    setState(() => _cargandoChoferes = true);

    try {
      final repo = UsuarioRepository(api: UsuarioApi(ref.read(apiClientProvider)));
      // Solo activos: asignar el recorrido de hoy a alguien que ya no trabaja
      // sería una forma de dejar la unidad sin conductor de verdad.
      final pagina = await repo.listar(pagina: 1, limite: 100, activo: true);

      if (mounted) {
        setState(() {
          _choferes = pagina.usuarios;
          _cargandoChoferes = false;
        });
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargandoChoferes = false;
        // No se cae la pantalla: se puede guardar la unidad sin chófer, que es
        // un estado válido. Solo se avisa de que la lista no vino.
        _errorGeneral = 'No se pudieron cargar los chóferes: ${error.message}';
      });
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
      errores['nombre'] = 'Ponle un nombre a la unidad.';
    } else if (nombre.length > 100) {
      errores['nombre'] = 'Máximo 100 caracteres.';
    }

    final textoCapacidad = _capacidad.text.trim();
    if (textoCapacidad.isEmpty) {
      errores['capacidad'] = 'Indica cuántos litros transporta.';
    } else {
      final numero = double.tryParse(textoCapacidad.replaceAll(',', '.'));
      if (numero == null) {
        errores['capacidad'] = 'Eso no es un número.';
      } else if (numero < 0) {
        errores['capacidad'] = 'La capacidad no puede ser negativa.';
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

    final capacidad = double.parse(_capacidad.text.trim().replaceAll(',', '.'));

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });

    final controller = ref.read(unidadesControllerProvider.notifier);
    final ok = esAlta
        ? await controller.crear(
            nombre: _nombre.text.trim(),
            tipo: _tipo,
            capacidad: capacidad,
            cerrado: _cerrado,
            activo: _activo,
            acopiadorId: _acopiadorId,
          )
        : await controller.editar(
            widget.unidad!,
            nombre: _nombre.text.trim(),
            tipo: _tipo,
            capacidad: capacidad,
            cerrado: _cerrado,
            activo: _activo,
            acopiadorId: _acopiadorId,
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
      _errorGeneral = ref.read(unidadesControllerProvider).error?.message
          ?? 'No se pudo guardar.';
    });
  }

  /// `1500` sale como "1500" y `1500,5` como "1500,5": los litros no se leen con
  /// punto decimal.
  String _sinDecimales(double valor) {
    return valor == valor.roundToDouble()
        ? valor.round().toString()
        : valor.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(esAlta ? 'Nueva unidad' : 'Editar unidad'),
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
              placeholder: 'Unidad Furgón 03',
              icon: CupertinoIcons.tag,
              textInputAction: TextInputAction.next,
              errorText: _errores['nombre'],
            ),
            const SizedBox(height: Espaciado.md),

            AppSelector(
              etiqueta: 'TIPO',
              valor: _tipo.valor,
              items: TipoUnidad.values
                  .map((t) => SelectorItem(id: t.valor, etiqueta: t.etiqueta))
                  .toList(),
              vacio: 'Elige un tipo',
              onChanged: (valor) {
                if (valor != null) {
                  setState(() => _tipo = TipoUnidad.desdeTexto(valor));
                }
              },
            ),
            const SizedBox(height: Espaciado.md),

            AppTextField(
              etiqueta: 'CAPACIDAD (LITROS)',
              controller: _capacidad,
              placeholder: '1500',
              icon: CupertinoIcons.cube_box,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              errorText: _errores['capacidad'],
            ),
            const SizedBox(height: Espaciado.md),

            if (_puedeElegirChofer)
              _SelectorChofer(
                cargando: _cargandoChoferes,
                elegidos: _choferes ?? const <UsuarioLista>[],
                seleccionadoId: _acopiadorId,
                onChanged: (id) => setState(() => _acopiadorId = id),
              ),

            const SizedBox(height: Espaciado.md),

            _Interruptor(
              titulo: 'Cerrada',
              subtitulo: 'No admite más carga hoy. No es lo mismo que estar inactiva.',
              valor: _cerrado,
              onChanged: (v) => setState(() => _cerrado = v),
            ),

            _Interruptor(
              titulo: 'Activa',
              subtitulo: 'Si no, deja de aparecer en los recorridos.',
              valor: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),

            const SizedBox(height: Espaciado.lg),

            AppButton(
              texto: esAlta ? 'Crear unidad' : 'Guardar cambios',
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

/// Selector de chófer, con opción de dejarlo sin asignar.
///
/// "Sin chófer" es la primera opción y sale marcada cuando no hay ninguno: es un
/// estado legítimo —una unidad recién creada antes de repartir el turno— y no
/// debería obligar a elegir a alguien para poder guardar.
class _SelectorChofer extends StatelessWidget {
  const _SelectorChofer({
    required this.cargando,
    required this.elegidos,
    required this.seleccionadoId,
    required this.onChanged,
  });

  final bool cargando;
  final List<UsuarioLista> elegidos;
  final int? seleccionadoId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Espaciado.md),
        child: Center(child: CupertinoActivityIndicator(radius: 9)),
      );
    }

    if (elegidos.isEmpty) {
      // No es un error: puede que la planta aún no tenga usuarios activos. Un
      // selector con una sola opción sería ruido.
      return const AppNotice(
        texto: 'No hay usuarios activos a los que asignar. La unidad se puede '
            'guardar igualmente y asignarle chófer más adelante.',
        color: CupertinoColors.secondaryLabel,
      );
    }

    return AppSelector(
      etiqueta: 'CHÓFER',
      // Id vacío significa "sin chófer": `AppSelector` marca la opción cuyo id
      // coincide con este valor, así que basta con que los dos coincidan.
      valor: seleccionadoId?.toString() ?? '',
      items: [
        const SelectorItem(id: '', etiqueta: 'Sin chófer'),
        ...elegidos.map(
          (u) => SelectorItem(id: '${u.id}', etiqueta: u.nombreCompleto),
        ),
      ],
      vacio: 'Sin chófer',
      onChanged: (valor) {
        if (valor == null || valor.isEmpty) {
          onChanged(null);
        } else {
          onChanged(int.tryParse(valor));
        }
      },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.sm),
      child: AppCard(
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(value: valor, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}