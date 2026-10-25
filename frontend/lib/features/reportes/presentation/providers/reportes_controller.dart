import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../proveedores/presentation/providers/proveedores_controller.dart';
import '../../data/reporte_api.dart';
import '../../domain/reporte.dart';

final reporteApiProvider = Provider<ReporteApi>((ref) {
  return ReporteApi(ref.watch(apiClientProvider));
});

/// Estado de la pantalla de reportes.
///
/// Lleva **las tres listas a la vez y un solo `tipo`** que dice cuál se está
/// enseñando, en vez de tres estados distintos con sus tres constructores. Los
/// reportes son listas de filas y se ven igual: separarlos obligaría a duplicar
/// la construcción tres veces y a que una se quedara sin algún arreglo que las
/// otras dos sí tendrían.
class ReportesState {
  const ReportesState({
    this.contraste = const <FilaContraste>[],
    this.calidad,
    this.calidadPorProveedor = const <FilaCalidad>[],
    this.tipo = TipoReporte.contraste,
    this.proveedorId,
    this.nombreProveedor,
    this.cargando = false,
    this.error,
  });

  /// Filas del reporte de contraste.
  final List<FilaContraste> contraste;

  /// La fila de calidad, ya sea de toda la planta o de un proveedor. `null` si
  /// todavía no se ha pedido o si no hay ninguna.
  final FilaCalidad? calidad;

  /// Filas del reporte de calidad por proveedor.
  final List<FilaCalidad> calidadPorProveedor;

  /// Qué reporte está en pantalla.
  ///
  /// Va en el estado y no como variable del widget para que al rotar el móvil no
  /// se vuelva al primero.
  final TipoReporte tipo;

  /// El proveedor del detalle, o `null` si se ve toda la planta.
  final int? proveedorId;

  /// Su nombre, para el título. Va aparte del id porque en la fila del reporte
  /// solo viene el id, y "Proveedor #4" no le dice nada a nadie.
  final String? nombreProveedor;

  final bool cargando;
  final AppException? error;

  /// Las filas del reporte que toca, listas para pintar.
  ///
  /// Como `List<Object>` a propósito: quien llama solo las dibuja, y todas
  /// saben cómo. El `switch` por tipo quedaría en la pantalla si esto fuera
  /// `List<FilaContraste>`, y ahí es donde se colaría un tipo sin pintar.
  List<Object> get filasVisibles {
    switch (tipo) {
      case TipoReporte.contraste:
        return contraste;
      case TipoReporte.calidad:
        return calidad == null ? const <Object>[] : <Object>[calidad!];
      case TipoReporte.calidadPorProveedor:
        return calidadPorProveedor;
    }
  }

  int get total => filasVisibles.length;

  bool get vacio => filasVisibles.isEmpty;

  ReportesState copyWith({
    List<FilaContraste>? contraste,
    FilaCalidad? calidad,
    List<FilaCalidad>? calidadPorProveedor,
    TipoReporte? tipo,
    int? proveedorId,
    String? nombreProveedor,
    bool? cargando,
    AppException? error,
    bool limpiarError = false,
  }) {
    return ReportesState(
      contraste: contraste ?? this.contraste,
      calidad: calidad ?? this.calidad,
      calidadPorProveedor: calidadPorProveedor ?? this.calidadPorProveedor,
      tipo: tipo ?? this.tipo,
      proveedorId: proveedorId ?? this.proveedorId,
      nombreProveedor: nombreProveedor ?? this.nombreProveedor,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// Carga los reportes y cambia entre ellos.
class ReportesController extends Notifier<ReportesState> {
  @override
  ReportesState build() {
    // La carga inicial **no** se dispara aquí: se pide desde la pantalla, que es
    // quien sabe qué reporte quiere ver primero. Un `build` que pide datos
    // dispara la petición aunque nadie abra el módulo.
    return const ReportesState();
  }

  ReporteApi get _api => ref.read(reporteApiProvider);

  /// Pide el reporte que toca.
  ///
  /// Cada uno se pide **solo cuando se abre**: son cuatro consultas contra
  /// tablas distintas, y pedirlas todas al entrar haría cuatro viajes para
  /// enseñar uno.
  Future<void> cargar({TipoReporte? tipo, int? proveedorId}) async {
    final elegido = tipo ?? state.tipo;
    final proveedor = proveedorId ?? state.proveedorId;

    state = state.copyWith(
      tipo: elegido,
      proveedorId: proveedor,
      nombreProveedor: _nombreDe(proveedor),
      cargando: true,
      limpiarError: true,
    );

    try {
      switch (elegido) {
        case TipoReporte.contraste:
          final reporte = await _api.contraste();
          state = state.copyWith(contraste: reporte.filas);

        case TipoReporte.calidad:
          final reporte = proveedor == null
              ? await _api.calidad()
              : await _api.calidadDeProveedor(proveedor);
          state = state.copyWith(calidad: reporte.filas.isEmpty ? null : reporte.filas.first);

        case TipoReporte.calidadPorProveedor:
          final reporte = await _api.calidadPorProveedor();
          state = state.copyWith(calidadPorProveedor: reporte.filas);
      }
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    } finally {
      state = state.copyWith(cargando: false);
    }
  }

  /// Cambia de reporte y lo pide.
  Future<void> ver(TipoReporte tipo) => cargar(tipo: tipo);

  /// Mira el detalle de un proveedor concreto.
  Future<void> verProveedor(int proveedorId) => cargar(proveedorId: proveedorId);

  /// Vuelve al de toda la planta.
  Future<void> verTodaLaPlanta() => cargar(proveedorId: null);

  void limpiarError() {
    if (state.error != null) {
      state = state.copyWith(limpiarError: true);
    }
  }

  /// El nombre del proveedor, para el título.
  ///
  /// Va contra la lista de proveedores ya cargada en vez de pedir el reporte de
  /// ese uno otra vez solo por su nombre.
  String? _nombreDe(int? proveedorId) {
    if (proveedorId == null) {
      return null;
    }

    // `maybeWhen` y no `valueOrNull`: en Riverpod 3 el accesor directo se fue.
    // `?? const []` sobre el `AsyncValue` entero daría un error dentro de la
    // propia lista cuando todavía no ha llegado.
    final opciones = ref.read(opcionesDeProveedorProvider).maybeWhen(
          data: (lista) => lista,
          orElse: () => const <ReferenciaProveedor>[],
        );
    for (final opcion in opciones) {
      if (opcion.id == proveedorId) {
        return opcion.nombreCompleto;
      }
    }

    return null;
  }
}

final reportesControllerProvider =
    NotifierProvider<ReportesController, ReportesState>(ReportesController.new);
