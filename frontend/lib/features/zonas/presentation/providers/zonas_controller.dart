import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../rutas/domain/ruta.dart';
import '../../../rutas/presentation/providers/rutas_controller.dart';
import '../../../unidades/domain/unidad.dart';
import '../../../unidades/presentation/providers/unidades_controller.dart';
import '../../data/zona_api.dart';
import '../../data/zona_repository.dart';
import '../../domain/zona.dart';

final zonaApiProvider = Provider<ZonaApi>((ref) {
  return ZonaApi(ref.watch(apiClientProvider));
});

final zonaRepositoryProvider = Provider<ZonaRepository>((ref) {
  return ZonaRepository(api: ref.watch(zonaApiProvider));
});

/// Estado de la lista de zonas.
class ZonasState {
  const ZonasState({
    this.zonas = const <Zona>[],
    this.pagina = 1,
    this.totalPaginas = 0,
    this.total = 0,
    this.cargando = false,
    this.error,
  });

  final List<Zona> zonas;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;

  /// Error de la última carga, o de la última acción.
  final AppException? error;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;

  ZonasState copyWith({
    List<Zona>? zonas,
    int? pagina,
    int? totalPaginas,
    int? total,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return ZonasState(
      zonas: zonas ?? this.zonas,
      pagina: pagina ?? this.pagina,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      total: total ?? this.total,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Filtros de la lista.
class FiltrosZonas {
  const FiltrosZonas({this.soloInactivas = false, this.busqueda = ''});

  /// Muestra las **inactivas**, que son las pocas. El nombre va al revés de la
  /// pantalla a propósito: si se llamara `soloActivas`, "sin marcar" tendría que
  /// significar "todas" y haría falta un estado más.
  final bool soloInactivas;
  final String busqueda;

  bool get hayAlguno => soloInactivas || busqueda.isNotEmpty;

  FiltrosZonas copyWith({bool? soloInactivas, String? busqueda}) {
    return FiltrosZonas(
      soloInactivas: soloInactivas ?? this.soloInactivas,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Carga la lista de zonas y ejecuta las acciones sobre cada una.
class ZonasController extends Notifier<ZonasState> {
  /// Peticiones por página.
  static const int limite = 10;

  @override
  ZonasState build() {
    // Fuera del `build`: aquí el estado todavía no está inicializado y escribir
    // en él daría el aviso de provider sin inicializar.
    Future<void>.microtask(() => unawaited(cargar()));
    return const ZonasState();
  }

  ZonaRepository get _repo => ref.read(zonaRepositoryProvider);

  FiltrosZonas get _filtros => ref.read(filtrosZonasProvider);

  Future<void> cargar({int? pagina}) async {
    state = state.copyWith(cargando: true, limpiarError: true);

    final filtros = _filtros;

    try {
      final resultado = await _repo.listar(
        pagina: pagina ?? state.pagina,
        limite: limite,
        busqueda: filtros.busqueda,
        activo: filtros.soloInactivas ? false : null,
      );

      state = state.copyWith(
        zonas: resultado.zonas,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        total: resultado.total,
        cargando: false,
      );
    } on AppException catch (error) {
      state = state.copyWith(cargando: false, error: error);
    }
  }

  Future<void> irAPagina(int numero) => cargar(pagina: numero);

  /// Vuelve a la primera página.
  ///
  /// Al cambiar un filtro, no al navegar: quedarse en la página 5 de un filtro
  /// que ahora tiene dos páginas mostraría una lista vacía sin explicación.
  void _volverAPrimero() {
    state = state.copyWith(pagina: 1);
  }

  Future<void> alternarSoloInactivas() async {
    ref.read(filtrosZonasProvider.notifier).alternarSoloInactivas();
    _volverAPrimero();
    await cargar();
  }

  Future<void> buscar(String texto) async {
    ref.read(filtrosZonasProvider.notifier).buscar(texto);
    _volverAPrimero();
    await cargar();
  }

  Future<void> limpiarFiltros() async {
    ref.read(filtrosZonasProvider.notifier).limpiar();
    _volverAPrimero();
    await cargar();
  }

  Future<void> refrescar() => cargar();

  /// Crea una zona y recarga la lista.
  Future<bool> crear({
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    try {
      await _repo.crear(
        nombre: nombre,
        horaInicio: horaInicio,
        horaFin: horaFin,
        rutaId: rutaId,
        unidadId: unidadId,
        activo: activo,
      );

      // Se recarga entero en vez de añadir la fila a mano: la respuesta llega
      // sin el orden de la base, y un insertado en cabecera podría no ser el
      // primero que devolvería el servidor.
      await cargar(pagina: 1);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Guarda los cambios de una zona.
  Future<bool> editar(
    Zona zona, {
    required String nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    required bool activo,
  }) async {
    try {
      final actualizada = await _repo.editar(
        zona.id,
        nombre: nombre,
        horaInicio: horaInicio,
        horaFin: horaFin,
        rutaId: rutaId,
        unidadId: unidadId,
        activo: activo,
      );

      _reemplazar(actualizada);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> eliminar(Zona zona) async {
    try {
      await _repo.eliminar(zona.id);

      // La fila sale de la lista sin volver a pedirla: el servidor ya la borró, y
      // recargar sería un viaje que no aporta nada.
      state = state.copyWith(
        zonas: state.zonas.where((z) => z.id != zona.id).toList(),
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
  void _reemplazar(Zona actualizada) {
    final lista = state.zonas
        .map((z) => z.id == actualizada.id ? actualizada : z)
        .toList();

    state = state.copyWith(zonas: lista, limpiarError: true);
  }
}

final zonasControllerProvider = NotifierProvider<ZonasController, ZonasState>(
  ZonasController.new,
);

/// Filtros de la lista de zonas.
///
/// Un provider aparte del que carga: así el `build` de `ZonasController` puede
/// leerlos sin depender de su propio estado.
class FiltrosZonasController extends Notifier<FiltrosZonas> {
  @override
  FiltrosZonas build() => const FiltrosZonas();

  void alternarSoloInactivas() {
    state = state.copyWith(soloInactivas: !state.soloInactivas);
  }

  void buscar(String texto) {
    state = state.copyWith(busqueda: texto);
  }

  void limpiar() {
    state = const FiltrosZonas();
  }
}

final filtrosZonasProvider = NotifierProvider<FiltrosZonasController, FiltrosZonas>(
  FiltrosZonasController.new,
);

/// Las opciones del formulario: las rutas y las unidades entre las que elegir.
///
/// **Es una lectura cruzada entre módulos y a propósito.** Una zona pertenece a
/// una ruta y la recorre una unidad, así que su formulario necesita los nombres
/// de las dos. Se leen de los repositorios de sus módulos en vez de copiar sus
/// datos aquí, para que un cambio en rutas o unidades llegue a las zonas sin
/// tocar este archivo.
///
/// `FutureProvider` y no estado de la lista: son datos de apoyo del formulario,
/// no de la tabla, y meterlos en `ZonasState` los recargaría en cada cambio de
/// filtro.
final opcionesZonaProvider = FutureProvider<OpcionesZona>((ref) async {
  // En paralelo: son dos peticiones independientes y el formulario no aparece
  // hasta que llegan las dos.
  final rutas = ref.watch(rutaRepositoryProvider).listar(limite: 100);
  final unidades = ref.watch(unidadRepositoryProvider).listar(limite: 100);

  return OpcionesZona(
    rutas: (await rutas).rutas.map(ReferenciaOpcion.nuevaRuta).toList(),
    unidades: (await unidades).unidades.map(ReferenciaOpcion.nuevaUnidad).toList(),
  );
});

/// Las zonas, para el desplegable de otros módulos.
///
/// Vive aquí y no en cada módulo que lo necesite: Proveedores también asigna una
/// zona a cada persona, y pedirlo desde los dos sitios son dos listas que pueden
/// quedar sin sincronizar.
///
/// Se piden solo las activas: una zona inactiva no es una opción a la que
/// quedarse asignada, y ofrecerla sería abrir la puerta a dejar a alguien en una
/// zona que ya no recoge.
final opcionesDeZonaProvider = FutureProvider<List<ReferenciaOpcion>>((ref) async {
  final zonas = await ref.watch(zonaRepositoryProvider).listar(limite: 100, activo: true);

  return zonas.zonas
      .map((z) => ReferenciaOpcion(id: z.id, nombre: z.nombre))
      .toList();
});

/// Una opción de un desplegable: lo que se enseña y lo que se devuelve.
///
/// El id y el nombre no son separables. Guardar solo el nombre obligaría a
/// buscarlo otra vez al guardar, y buscar por nombre no es único: dos rutas
/// pueden llamarse "Norte" en plantas distintas, y aquí solo hay una planta pero
/// mañana puede haber más.
class ReferenciaOpcion {
  const ReferenciaOpcion({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory ReferenciaOpcion.nuevaRuta(Ruta ruta) =>
      ReferenciaOpcion(id: ruta.id, nombre: ruta.nombre);

  factory ReferenciaOpcion.nuevaUnidad(Unidad unidad) =>
      ReferenciaOpcion(id: unidad.id, nombre: unidad.nombre);
}

/// Nombres de las rutas y de las unidades, para los desplegables del formulario.
///
/// Van en dos listas y no en una mezclada: son cosas distintas y una lista única
/// haría imposible distinguir una ruta de una unidad al elegir.
class OpcionesZona {
  const OpcionesZona({
    this.rutas = const <ReferenciaOpcion>[],
    this.unidades = const <ReferenciaOpcion>[],
  });

  final List<ReferenciaOpcion> rutas;
  final List<ReferenciaOpcion> unidades;

  bool get hayRutas => rutas.isNotEmpty;
  bool get hayUnidades => unidades.isNotEmpty;
}
