/// Zona tal como la devuelve `GET /zonas`.
///
/// Una zona es un trozo de territorio con su horario de recogida, y pertenece a
/// una ruta y a una unidad. Las dos son **opcionales** (`allowNull: true` en la
/// base): una zona puede existir sin ruta asignada y sin unidad que la recorra,
/// y `null` significa exactamente eso, no "cualquiera".
class Zona {
  const Zona({
    required this.id,
    required this.nombre,
    required this.activo,
    this.horaInicio,
    this.horaFin,
    this.rutaId,
    this.unidadId,
  });

  final int id;
  final String nombre;

  /// Ventana de recogida de la zona. Viene como `HH:MM:SS`.
  final String? horaInicio;
  final String? horaFin;

  /// Ruta a la que pertenece, o `null` si todavía no está asignada.
  final int? rutaId;

  /// Unidad que la recorre, o `null` si no hay ninguna asignada.
  final int? unidadId;

  final bool activo;

  /// Horario en formato corto, `06:00 – 10:00`.
  ///
  /// Si falta uno de los dos no se inventa nada: se enseña solo el que hay.
  String get horario {
    final desde = horaCorta(horaInicio);
    final hasta = horaCorta(horaFin);

    if (desde == null && hasta == null) {
      return 'Sin horario';
    }
    if (desde == null) {
      return 'Hasta las $hasta';
    }
    if (hasta == null) {
      return 'Desde las $desde';
    }
    return '$desde – $hasta';
  }

  /// `06:00:00` pasa a `06:00`, que es como se lee una hora.
  ///
  /// Vive aquí y no en cada pantalla porque cuatro módulos muestran horas de
  /// zonas, rutas y paradas, y cuatro copias de este `substring` acabarían
  /// divergiendo en cuanto una cambiara.
  static String? horaCorta(String? valor) {
    if (valor == null || valor.isEmpty) {
      return null;
    }
    return valor.length >= 5 ? valor.substring(0, 5) : valor;
  }

  factory Zona.fromJson(Map<String, dynamic> json) => Zona(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        horaInicio: json['horaInicio'] as String?,
        horaFin: json['horaFin'] as String?,
        rutaId: json['rutaId'] as int?,
        unidadId: json['unidadId'] as int?,
        activo: json['activo'] as bool? ?? true,
      );

  Zona copyWith({
    String? nombre,
    String? horaInicio,
    String? horaFin,
    int? rutaId,
    int? unidadId,
    bool? activo,
    bool limpiarRuta = false,
    bool limpiarUnidad = false,
    bool limpiarHorario = false,
  }) {
    return Zona(
      id: id,
      nombre: nombre ?? this.nombre,
      horaInicio: limpiarHorario ? null : (horaInicio ?? this.horaInicio),
      horaFin: limpiarHorario ? null : (horaFin ?? this.horaFin),
      // Sin estos dos flags no se podría desasignar: `null` es justamente el
      // valor que significa "quítale la ruta".
      rutaId: limpiarRuta ? null : (rutaId ?? this.rutaId),
      unidadId: limpiarUnidad ? null : (unidadId ?? this.unidadId),
      activo: activo ?? this.activo,
    );
  }
}

/// Una página de zonas con su estado de paginación.
class ZonasPagina {
  const ZonasPagina({
    required this.zonas,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Zona> zonas;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory ZonasPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ZonasPagina(
      zonas: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Zona.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}
