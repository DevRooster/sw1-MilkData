import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../usuarios/presentation/lista_usuarios_page.dart';
import '../../usuarios/presentation/providers/usuarios_controller.dart';
import '../domain/planta.dart';
import 'providers/auth_controller.dart';
import 'providers/register_controller.dart';

/// Administración: cambiar de planta y registrar usuarios.
///
/// Las dos cosas que dependen de la planta en la que se está operando. Viven
/// juntas y separadas del perfil porque ninguna de las dos es "mi cuenta".
class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  final _ctrlNombre = TextEditingController();
  final _ctrlApellido = TextEditingController();
  final _ctrlEmail = TextEditingController();
  final _ctrlClave = TextEditingController();

  String? _rolElegido;
  String? _plantaElegida;

  /// Roles que el backend define. El id es el que valida la API: comprueba
  /// contra la tabla `rol`, no contra el nombre.
  static const List<({String nombre, int id})> _roles = [
    (nombre: 'admin', id: 2),
    (nombre: 'supervisor', id: 3),
    (nombre: 'acopiador', id: 4),
    (nombre: 'operador', id: 5),
    (nombre: 'laboratorio', id: 6),
    (nombre: 'proveedor', id: 7),
  ];

  /// `false` muestra la lista de usuarios; `true`, el formulario de alta.
  ///
  /// Son dos pantallas y no dos secciones apiladas: una lista larga y un
  /// formulario debajo obligarían a hacer scroll infinito para registrar a
  /// alguien.
  bool _mostrarFormulario = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlApellido.dispose();
    _ctrlEmail.dispose();
    _ctrlClave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(authControllerProvider);

    if (sesion is! Autenticado) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFF2F2F7),
        navigationBar: CupertinoNavigationBar(middle: Text('Usuarios'), border: null),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final usuario = sesion.usuario;
    final plantas = sesion.plantas;
    final errorUsuarios = ref.watch(usuariosControllerProvider).error;

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.datos.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_mostrarFormulario ? 'Registrar usuario' : 'Usuarios'),
        leading: _mostrarFormulario
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _mostrarFormulario = false),
                child: const Icon(CupertinoIcons.back, size: 20),
              )
            : null,
        trailing: _mostrarFormulario
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _mostrarFormulario = true),
                child: const Icon(CupertinoIcons.person_badge_plus, size: 20),
              ),
      ),
      child: SafeArea(
        child: _mostrarFormulario
            ? ListView(
                padding: const EdgeInsets.fromLTRB(
                  Espaciado.md,
                  Espaciado.md,
                  Espaciado.md,
                  Espaciado.xl,
                ),
                children: [
                  _Alcance(plantas: plantas, nombreRol: usuario.rol.nombre),

                  // Con una sola planta no hay nada que elegir, así que el
                  // selector no se pinta: sería un control inútil.
                  if (plantas != null && plantas.plantas.length > 1) ...[
                    const SizedBox(height: Espaciado.md),
                    _SelectorPlanta(
                      plantas: plantas,
                      actualId: usuario.plantaId,
                      onChanged: (id) => ref
                          .read(authControllerProvider.notifier)
                          .cambiarPlanta(plantaId: id),
                    ),
                  ],

                  const SizedBox(height: Espaciado.md),
                  AppCard(
                    child: _Formulario(
                      nombre: _ctrlNombre,
                      apellido: _ctrlApellido,
                      email: _ctrlEmail,
                      clave: _ctrlClave,
                      plantas: plantas,
                      plantaIdActual: usuario.plantaId,
                      rolElegido: _rolElegido,
                      plantaElegida: _plantaElegida,
                      roles: _roles,
                      onRol: (valor) => setState(() => _rolElegido = valor),
                      onPlanta: (valor) => setState(() => _plantaElegida = valor),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  if (errorUsuarios != null)
                    Padding(
                      padding: const EdgeInsets.all(Espaciado.md),
                      child: AppNotice(
                        texto: errorUsuarios.message,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  const Expanded(child: ListaUsuariosPage()),
                ],
              ),
      ),
    );
  }
}

/// Cuántas plantas administra esta sesión.
class _Alcance extends StatelessWidget {
  const _Alcance({required this.plantas, required this.nombreRol});

  final PlantasDisponibles? plantas;
  final String nombreRol;

  @override
  Widget build(BuildContext context) {
    // Mientras se piden las plantas se dice lo que ya se sabe del rol, en vez de
    // dejar un hueco que parece un error.
    final alcance = plantas?.alcance.etiqueta ??
        (nombreRol == 'superadmin' ? 'Todas las plantas' : 'Solo tu planta');

    return AppCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.building_2_fill,
            size: 20,
            color: CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: Espaciado.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alcance, style: const TextStyle(fontSize: 15)),
                Text(
                  plantas == null
                      ? 'Cargando…'
                      : plantas!.plantas.map((p) => p.codigo).join(' · '),
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
    );
  }
}

/// Cambio de planta. Solo aparece si hay más de una.
class _SelectorPlanta extends StatelessWidget {
  const _SelectorPlanta({
    required this.plantas,
    required this.actualId,
    required this.onChanged,
  });

  final PlantasDisponibles plantas;
  final int? actualId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle('Operar en'),
          const SizedBox(height: Espaciado.sm),
          for (final planta in plantas.plantas)
            _FilaPlanta(
              planta: planta,
              activa: planta.id == actualId,
              onTap: () => onChanged(planta.id),
            ),
        ],
      ),
    );
  }
}

class _FilaPlanta extends StatelessWidget {
  const _FilaPlanta({required this.planta, required this.activa, required this.onTap});

  final Planta planta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activa ? null : onTap,
      // Sin `opaque` el toque solo llega si un hijo lo atrapa, y una fila de iconos
      // y textos no lo hace: se vería la lista sin poder elegir nada.
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaciado.sm),
        child: Row(
          children: [
            Icon(
              activa ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 20,
              color: activa ? AppTheme.verde : CupertinoColors.systemGrey3,
            ),
            const SizedBox(width: Espaciado.sm),
            Expanded(
              child: Text(
                planta.nombre,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  color: activa ? CupertinoColors.label : CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            Text(
              planta.codigo,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(width: Espaciado.xs),
            // El chevron deja claro que la fila es pulsable.
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: CupertinoColors.systemGrey2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de alta de usuario.
class _Formulario extends ConsumerWidget {
  const _Formulario({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.clave,
    required this.plantas,
    required this.plantaIdActual,
    required this.rolElegido,
    required this.plantaElegida,
    required this.roles,
    required this.onRol,
    required this.onPlanta,
  });

  final TextEditingController nombre;
  final TextEditingController apellido;
  final TextEditingController email;
  final TextEditingController clave;
  final PlantasDisponibles? plantas;
  final int? plantaIdActual;
  final String? rolElegido;
  final String? plantaElegida;
  final List<({String nombre, int id})> roles;
  final ValueChanged<String?> onRol;
  final ValueChanged<String?> onPlanta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(registerControllerProvider);

    // El superadmin sí puede registrar en otra planta. Un admin de planta solo en
    // la suya, así que no se le ofrece elegir.
    final puedeElegirPlanta = plantas != null && plantas!.plantas.length > 1;
    final plantaId = int.tryParse(plantaElegida ?? '') ?? plantaIdActual;
    final rolId = int.tryParse(rolElegido ?? '');
    final listo = rolId != null && plantaId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registrar usuario',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Espaciado.xs),
        const Text(
          'Queda dentro de la planta que elijas. El servidor no la deduce: si se '
          'omite, responde 400.',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
            height: 1.3,
          ),
        ),
        const SizedBox(height: Espaciado.md),
        AppTextField(
          etiqueta: 'NOMBRE',
          controller: nombre,
          placeholder: 'Enrique',
          icon: CupertinoIcons.person,
        ),
        const SizedBox(height: Espaciado.sm),
        AppTextField(
          etiqueta: 'APELLIDO',
          controller: apellido,
          placeholder: 'Mamamni',
          icon: CupertinoIcons.person,
        ),
        const SizedBox(height: Espaciado.sm),
        AppTextField(
          etiqueta: 'CORREO',
          controller: email,
          placeholder: 'enrique@milkdata.com',
          icon: CupertinoIcons.envelope,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: Espaciado.sm),
        AppTextField(
          etiqueta: 'CONTRASEÑA',
          controller: clave,
          placeholder: 'Al menos 8 caracteres',
          icon: CupertinoIcons.lock,
          obscureText: true,
        ),
        const SizedBox(height: Espaciado.sm),
        AppSelector(
          etiqueta: 'ROL',
          valor: rolElegido,
          items: roles.map((r) => SelectorItem(id: '${r.id}', etiqueta: r.nombre)).toList(),
          vacio: 'Elige un rol',
          onChanged: onRol,
        ),
        if (puedeElegirPlanta) ...[
          const SizedBox(height: Espaciado.sm),
          AppSelector(
            etiqueta: 'PLANTA',
            valor: plantaElegida,
            items: plantas!.plantas
                .map((p) => SelectorItem(id: '${p.id}', etiqueta: '${p.nombre} (${p.codigo})'))
                .toList(),
            vacio: 'Elige una planta',
            onChanged: onPlanta,
          ),
        ],
        const SizedBox(height: Espaciado.md),
        switch (estado.estado) {
          RegistroEnCurso() => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: Espaciado.sm),
                child: CupertinoActivityIndicator(),
              ),
            ),
          RegistroOk(:final mensaje) =>
            AppNotice(texto: mensaje, color: AppTheme.verde),
          RegistroError(:final mensaje) =>
            AppNotice(texto: mensaje, color: CupertinoColors.systemRed),
          RegistroInactivo() => const SizedBox.shrink(),
        },
        if (estado.estado is! RegistroEnCurso)
          AppButton(
            texto: 'Registrar usuario',
            deshabilitado: !listo,
            onPressed: listo
                ? () => ref.read(registerControllerProvider.notifier).registrar(
                      nombre: nombre.text,
                      apellido: apellido.text,
                      email: email.text,
                      password: clave.text,
                      rolId: rolId,
                      plantaId: plantaId,
                    )
                : null,
          ),
      ],
    );
  }
}