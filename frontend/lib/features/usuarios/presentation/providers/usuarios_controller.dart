import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/usuario_api.dart';
import '../../data/usuario_repository.dart';
import '../../domain/usuario_lista.dart';

final usuarioApiProvider = Provider<UsuarioApi>((ref) {
  return UsuarioApi(ref.watch(apiClientProvider));
});

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  return UsuarioRepository(api: ref.watch(usuarioApiProvider));
});

/// Estado de la lista de usuarios.
class UsuariosState {
  const UsuariosState({
    this.usuarios = const <UsuarioLista>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<UsuarioLista> usuarios;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  UsuariosState copyWith({
    List<UsuarioLista>? usuarios,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return UsuariosState(
      usuarios: usuarios ?? this.usuarios,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
///
/// Van aparte del estado y **no** dentro de él a propósito: el estado se compara
/// para saber si hay que recargar, así que un filtro guardado en el estado
/// obligaría a distinguir "cambió el filtro" de "cambió la lista" con
/// comparaciones frágiles.
///
/// Además, con los filtros en el estado el `build` del controller tendría que
/// leerlos para cargarse, y eso es un ciclo: un provider no puede depender de
/// su propio estado mientras se construye.
class FiltrosUsuarios {
  const FiltrosUsuarios({this.rolId, this.soloInactivos = false, this.busqueda = ''});

  final int? rolId;
  final bool soloInactivos;
  final String busqueda;

  /// `limpiarRol` hace falta aparte: con `rolId ?? this.rolId` no se puede
  /// volver a "todos", porque `null` es justamente el valor que significa eso.
  FiltrosUsuarios copyWith({
    int? rolId,
    bool limpiarRol = false,
    bool? soloInactivos,
    String? busqueda,
  }) {
    return FiltrosUsuarios(
      rolId: limpiarRol ? null : (rolId ?? this.rolId),
      soloInactivos: soloInactivos ?? this.soloInactivos,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de usuarios y ejecuta las acciones sobre cada uno.
class UsuariosController extends Notifier<UsuariosState> {
  /// Páginas por petición. Diez es el tamaño con el que la API responde por
  /// defecto y cabe en pantalla sin paginar.
  static const int limite = 10;

  @override
  UsuariosState build() {
    // La carga inicial se pide después del primer frame.
    //
    // Hacerla aquí dentro no funciona: `cargar()` escribe en `state`, y durante
    // el `build` el estado todavía no está inicializado. Riverpod avisa con
    // "read the state of an uninitialized provider" y el provider parece
    // depender de sí mismo.
    Future<void>.microtask(() => unawaited(cargar()));
    return const UsuariosState();
  }

  UsuarioRepository get _repo => ref.read(usuarioRepositoryProvider);

  FiltrosUsuarios get _filtros => ref.read(filtrosUsuariosProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        rolId: filtros.rolId,
        activo: filtros.soloInactivos ? false : null,
        busqueda: filtros.busqueda,
      );

      state = state.copyWith(
        usuarios: resultado.usuarios,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        cargando: false,
      );
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  /// Cambia de página.
  Future<void> irAPagina(int numero) => cargar(pagina: numero);

  /// Vuelve a la primera página.
  ///
  /// Se hace al cambiar un filtro porque quedarse en la página 5 de un filtro
  /// que ahora tiene 2 páginas mostraría una lista vacía sin explicación.
  void _volverAPrimero() {
    state = state.copyWith(pagina: 1);
  }

  Future<void> filtrarPorRol(int? rolId) async {
    ref.read(filtrosUsuariosProvider.notifier).filtrarPorRol(rolId);
    _volverAPrimero();
    await cargar();
  }

  Future<void> alternarSoloInactivos() async {
    ref.read(filtrosUsuariosProvider.notifier).alternarSoloInactivos();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosUsuariosProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Cambia el rol de un usuario y lo refleja en la fila sin recargar todo.
  Future<void> cambiarRol(UsuarioLista usuario, int rolId) async {
    try {
      final actualizado = await _repo.cambiarRol(usuario.id, rolId);
      _reemplazar(actualizado);
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// Activa o desactiva un usuario.
  ///
  /// Desactivar deja la cuenta en la base pero le cierra la sesión: sus
  /// datos antiguos siguen siendo válidos y no se rompen las referencias.
  Future<void> cambiarActivo(UsuarioLista usuario, bool activo) async {
    try {
      final actualizado = await _repo.cambiarActivo(usuario.id, activo);
      _reemplazar(actualizado);
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// Edita nombre y apellido.
  Future<void> editar(
    UsuarioLista usuario, {
    String? nombre,
    String? apellido,
  }) async {
    try {
      final actualizado = await _repo.editar(
        usuario.id,
        nombre: nombre,
        apellido: apellido,
      );
      _reemplazar(actualizado);
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// Elimina un usuario.
  Future<void> eliminar(UsuarioLista usuario) async {
    try {
      await _repo.eliminar(usuario.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró
      // y recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        usuarios: state.usuarios.where((u) => u.id != usuario.id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  void limpiarError() {
    if (state.error != null) {
      state = state.copyWith(limpiarError: true);
    }
  }

  /// Cambia una fila por su versión actualizada, conservando el orden.
  void _reemplazar(UsuarioLista actualizado) {
    final lista = state.usuarios
        .map((u) => u.id == actualizado.id ? actualizado : u)
        .toList();

    state = state.copyWith(usuarios: lista, limpiarError: true);
  }
}

final usuariosControllerProvider = NotifierProvider<UsuariosController, UsuariosState>(
  UsuariosController.new,
);

/// Filtros de la lista de usuarios.
///
/// Un provider aparte del que carga: así el `build` de `UsuariosController` puede
/// leerlos sin depender de su propio estado.
class FiltrosUsuariosController extends Notifier<FiltrosUsuarios> {
  @override
  FiltrosUsuarios build() => const FiltrosUsuarios();

  void filtrarPorRol(int? rolId) {
    state = state.copyWith(rolId: rolId, limpiarRol: rolId == null);
  }

  void alternarSoloInactivos() {
    state = state.copyWith(soloInactivos: !state.soloInactivos);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }
}

final filtrosUsuariosProvider = NotifierProvider<FiltrosUsuariosController, FiltrosUsuarios>(
  FiltrosUsuariosController.new,
);