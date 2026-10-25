import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/usuario_lista.dart';
import 'providers/usuarios_controller.dart';

/// Lista de usuarios de la planta, con sus acciones.
///
/// Cada fila lleva las acciones que aplican a ese usuario: editar, cambiar rol,
/// activar o desactivar y eliminar. Borrar pide confirmación y avisa de que no
/// se puede deshacer.
class ListaUsuariosPage extends ConsumerStatefulWidget {
  const ListaUsuariosPage({super.key});

  @override
  ConsumerState<ListaUsuariosPage> createState() => _ListaUsuariosPageState();
}

class _ListaUsuariosPageState extends ConsumerState<ListaUsuariosPage> {
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(usuariosControllerProvider);
    final controller = ref.read(usuariosControllerProvider.notifier);
    final sesion = ref.watch(authControllerProvider);
    final yoMismo = sesion is Autenticado ? sesion.usuario.id : null;

    return Column(
      children: [
        _Filtros(
          busqueda: _ctrlBusqueda,
          onBusqueda: controller.buscar,
          onRol: controller.filtrarPorRol,
          onInactivos: controller.alternarSoloInactivos,
        ),

        Expanded(
          child: estado.cargando && estado.usuarios.isEmpty
              ? const Center(child: CupertinoActivityIndicator())
              : _Cuerpo(
                  estado: estado,
                  yoMismo: yoMismo,
                  controller: controller,
                  onEditar: _editar,
                  onRol: _cambiarRol,
                  onEliminar: _confirmarBorrado,
                ),
        ),
      ],
    );
  }

  /// Hoja de edición: solo nombre y apellido. El rol tiene su propia acción
  /// porque tiene reglas distintas.
  void _editar(UsuarioLista usuario) {
    final nombre = TextEditingController(text: usuario.nombre);
    final apellido = TextEditingController(text: usuario.apellido);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (contexto) => _Hoja(
        titulo: 'Editar usuario',
        children: [
          AppTextField(etiqueta: 'NOMBRE', controller: nombre, icon: CupertinoIcons.person),
          const SizedBox(height: Espaciado.sm),
          AppTextField(
            etiqueta: 'APELLIDO',
            controller: apellido,
            icon: CupertinoIcons.person,
          ),
          const SizedBox(height: Espaciado.md),
          AppButton(
            texto: 'Guardar',
            onPressed: () {
              ref.read(usuariosControllerProvider.notifier).editar(
                    usuario,
                    nombre: nombre.text,
                    apellido: apellido.text,
                  );
              Navigator.of(contexto).pop();
            },
          ),
        ],
      ),
    );
  }

  /// Hoja para cambiar el rol.
  ///
  /// El superadmin queda fuera a propósito: solo un superadmin puede crear o
  /// degradar a otro superadmin, y el selector lo pone en una situación que el
  /// servidor va a rechazar con 403.
  void _cambiarRol(UsuarioLista usuario) {
    const roles = [
      (nombre: 'admin', id: 2),
      (nombre: 'supervisor', id: 3),
      (nombre: 'acopiador', id: 4),
      (nombre: 'operador', id: 5),
      (nombre: 'laboratorio', id: 6),
      (nombre: 'proveedor', id: 7),
    ];

    String? elegido = '${usuario.rol.id}';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (contexto) => _Hoja(
        titulo: 'Rol de ${usuario.nombre}',
        children: [
          StatefulBuilder(
            builder: (contexto, setState) => AppSelector(
              etiqueta: 'ROL',
              valor: elegido,
              items: roles
                  .map((r) => SelectorItem(id: '${r.id}', etiqueta: r.nombre))
                  .toList(),
              onChanged: (valor) => setState(() => elegido = valor),
            ),
          ),
          const SizedBox(height: Espaciado.md),
          AppButton(
            texto: 'Cambiar rol',
            deshabilitado: elegido == '${usuario.rol.id}',
            onPressed: () {
              ref
                  .read(usuariosControllerProvider.notifier)
                  .cambiarRol(usuario, int.parse(elegido!));
              Navigator.of(contexto).pop();
            },
          ),
        ],
      ),
    );
  }

  /// Borrar pide confirmación. Es la única acción destructiva de la fila.
  void _confirmarBorrado(UsuarioLista usuario) {
    showCupertinoDialog<void>(
      context: context,
      builder: (contexto) => CupertinoAlertDialog(
        title: Text('Eliminar a ${usuario.nombreCompleto}?'),
        content: const Text(
          'Se borra la cuenta y no se puede deshacer. Si solo dejó de trabajar, '
          'es mejor desactivarlo: sus datos antiguos siguen siendo válidos.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(usuariosControllerProvider.notifier).eliminar(usuario);
              Navigator.of(contexto).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Filtros: búsqueda, rol y solo inactivos.
class _Filtros extends ConsumerWidget {
  const _Filtros({
    required this.busqueda,
    required this.onBusqueda,
    required this.onRol,
    required this.onInactivos,
  });

  final TextEditingController busqueda;
  final Future<void> Function(String) onBusqueda;
  final Future<void> Function(int?) onRol;
  final Future<void> Function() onInactivos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosUsuariosProvider);
    final roles = [
      const (nombre: 'admin', id: 2),
      const (nombre: 'supervisor', id: 3),
      const (nombre: 'acopiador', id: 4),
      const (nombre: 'operador', id: 5),
      const (nombre: 'laboratorio', id: 6),
      const (nombre: 'proveedor', id: 7),
    ];

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
          AppTextField(
            etiqueta: 'BUSCAR',
            controller: busqueda,
            placeholder: 'Nombre o correo',
            icon: CupertinoIcons.search,
            onSubmitted: onBusqueda,
          ),
          const SizedBox(height: Espaciado.sm),
          Row(
            children: [
              Expanded(
                child: AppSelector(
                  etiqueta: 'ROL',
                  // Sin filtro, `rolId` es null y "Todos" queda como opción
                  // elegida. Con filtro, queda el rol.
                  valor: filtros.rolId?.toString() ?? '',
                  items: [
                    // "Todos" es una opción de verdad, no solo el texto que se
                    // ve sin selección. Sin ella, en cuanto eliges un rol no hay
                    // forma de quitarlo: el selector solo ofrecía los roles.
                    const SelectorItem(id: '', etiqueta: 'Todos'),
                    ...roles.map(
                      (r) => SelectorItem(id: '${r.id}', etiqueta: r.nombre),
                    ),
                  ],
                  vacio: 'Todos',
                  onChanged: (valor) => onRol(
                    // Id vacío significa "sin filtro". `int.tryParse('')` da
                    // null, que es justo lo que espera el filtro.
                    valor == null || valor.isEmpty ? null : int.tryParse(valor),
                  ),
                  // Con un filtro puesto aparece una X dentro del campo: quitarlo
                  // con un toque, sin abrir la hoja y buscar la opción.
                  limpiar: filtros.rolId == null ? null : () => onRol(null),
                ),
              ),
              const SizedBox(width: Espaciado.sm),
              // El botón de inactivos es una casilla, no un selector: solo hay
              // dos estados y un selector de dos opciones sería un rodeo.
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: Espaciado.md),
                color: filtros.soloInactivos
                    ? AppTheme.verde
                    : CupertinoColors.white,
                onPressed: onInactivos,
                child: Text(
                  'Inactivos',
                  style: TextStyle(
                    fontSize: 14,
                    color: filtros.soloInactivos
                        ? CupertinoColors.white
                        : CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista o mensaje de vacío.
class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.estado,
    required this.yoMismo,
    required this.controller,
    required this.onEditar,
    required this.onRol,
    required this.onEliminar,
  });

  final UsuariosState estado;
  final int? yoMismo;
  final UsuariosController controller;
  final void Function(UsuarioLista) onEditar;
  final void Function(UsuarioLista) onRol;
  final void Function(UsuarioLista) onEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosUsuariosProvider);
    if (estado.usuarios.isEmpty) {
      // El mensaje distingue "no hay usuarios" de "no hay ninguno que coincida":
      // son problemas distintos y la pista para cada uno es otra.
      final hayFiltro = filtros.busqueda.isNotEmpty ||
          filtros.rolId != null ||
          filtros.soloInactivos;

      return ListView(
        children: [
          const SizedBox(height: Espaciado.xl),
          AppEmpty(
            texto: hayFiltro
                ? 'Ningún usuario coincide con el filtro.'
                : 'Esta planta todavía no tiene usuarios.',
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
      itemCount: estado.usuarios.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: Espaciado.sm),
      itemBuilder: (context, indice) {
        if (indice == estado.usuarios.length) {
          // El pie lleva la paginación y un botón de recarga: `ListView` con
          // sliver es lo que usaría `RefreshIndicator`, y eso es de Material.
          return Column(
            children: [
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

        final usuario = estado.usuarios[indice];

        return _FilaUsuario(
          usuario: usuario,
          esYoMismo: usuario.id == yoMismo,
          onEditar: () => onEditar(usuario),
          onRol: () => onRol(usuario),
          onActivo: () => controller.cambiarActivo(usuario, !usuario.activo),
          onEliminar: () => onEliminar(usuario),
        );
      },
    );
  }
}

/// Una fila con los datos y las acciones.
class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({
    required this.usuario,
    required this.esYoMismo,
    required this.onEditar,
    required this.onRol,
    required this.onActivo,
    required this.onEliminar,
  });

  final UsuarioLista usuario;
  final bool esYoMismo;
  final VoidCallback onEditar;
  final VoidCallback onRol;
  final VoidCallback onActivo;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(ruta: usuario.imagen, iniciales: usuario.iniciales),
              const SizedBox(width: Espaciado.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      usuario.email,
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

          const SizedBox(height: Espaciado.sm),

          // Un usuario desactivado se ve apagado de punta a punta: que un
          // cadastro gris no quiere decir nada es peor que un badge que sí.
          if (!usuario.activo)
            const Padding(
              padding: EdgeInsets.only(bottom: Espaciado.sm),
              child: AppPill(
                texto: 'inactivo',
                color: CupertinoColors.systemGrey,
              ),
            ),

          const SizedBox(height: Espaciado.sm),

          _Acciones(
            onEditar: onEditar,
            onRol: onRol,
            onActivo: onActivo,
            // Sin dos acciones destructivas seguidas: desactivar y borrar son
            // decisiones distintas.
            onEliminar: esYoMismo ? null : onEliminar,
            activar: !usuario.activo,
            soyYo: esYoMismo,
          ),
        ],
      ),
    );
  }
}

/// Botones de acción de una fila.
class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.onEditar,
    required this.onRol,
    required this.onActivo,
    required this.onEliminar,
    required this.activar,
    required this.soyYo,
  });

  final VoidCallback onEditar;
  final VoidCallback onRol;
  final VoidCallback onActivo;
  final VoidCallback? onEliminar;

  /// `true` si la acción es activar; `false` si es desactivar.
  final bool activar;

  /// Si la fila es la cuenta propia.
  final bool soyYo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Boton(
            texto: 'Editar',
            icono: CupertinoIcons.pencil,
            onPressed: onEditar,
          ),
        ),
        const SizedBox(width: Espaciado.xs),
        Expanded(
          child: _Boton(
            texto: 'Rol',
            icono: CupertinoIcons.person_badge_plus,
            onPressed: onRol,
          ),
        ),
        const SizedBox(width: Espaciado.xs),
        Expanded(
          child: _Boton(
            texto: activar ? 'Activar' : 'Desactivar',
            icono: activar ? CupertinoIcons.checkmark : CupertinoIcons.pause,
            onPressed: onActivo,
          ),
        ),
        const SizedBox(width: Espaciado.xs),
        Expanded(
          child: _Boton(
            texto: 'Borrar',
            icono: CupertinoIcons.trash,
            tono: CupertinoColors.systemRed,
            // Sin acción no hay botón apagado: se oculta. Borrarse a uno mismo
            // está prohibido, y un botón que nunca hace nada confunde más que
            // no verlo.
            onPressed: onEliminar,
          ),
        ),
      ],
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.texto,
    required this.icono,
    this.onPressed,
    this.tono = CupertinoColors.systemGrey,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;
  final Color tono;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.xs),
      color: tono.withValues(alpha: activo ? 0.14 : 0),
      onPressed: onPressed,
      child: Column(
        children: [
          Icon(icono, size: 17, color: activo ? tono : CupertinoColors.systemGrey4),
          const SizedBox(height: 2),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: activo ? tono : CupertinoColors.systemGrey4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Controles de página.
class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.estado, required this.controller});

  final UsuariosState estado;
  final UsuariosController controller;

  @override
  Widget build(BuildContext context) {
    if (estado.totalPaginas <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: Espaciado.md),
        child: Text(
          '${estado.total} ${estado.total == 1 ? 'usuario' : 'usuarios'}',
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: Espaciado.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: estado.hayAnterior
                ? () => controller.irAPagina(estado.pagina - 1)
                : null,
            child: const Text('Anterior'),
          ),
          Text(
            '${estado.pagina} de ${estado.totalPaginas}',
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: estado.haySiguiente
                ? () => controller.irAPagina(estado.pagina + 1)
                : null,
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }
}

/// Foto o iniciales del usuario.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.ruta, required this.iniciales});

  final String? ruta;
  final String iniciales;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.urlDeImagen(ruta);

    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey5,
        shape: BoxShape.circle,
      ),
      child: url.isEmpty
          ? Center(
              child: Text(
                iniciales,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            )
          : Image.network(
              url,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  iniciales,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Hoja modal con un título y contenido.
class _Hoja extends StatelessWidget {
  const _Hoja({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espaciado.md),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 60),
              ],
            ),
            const SizedBox(height: Espaciado.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}