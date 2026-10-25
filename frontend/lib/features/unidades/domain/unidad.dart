/// Unidad tal como la devuelve `GET /unidades`.
///
/// La API no tiene un DTO para este recurso: devuelve las columnas tal cual,
/// así que el tipo refleja el modelo y no una forma transformada.
class Unidad {
  const Unidad({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.capacidad,
    required this.cerrado,
    required this.activo,
    this.plantaId,
    this.acopiadorId,
  });

  final int id;
  final String nombre;

  /// `furgon` o `motocarga`. El servidor lo tiene como enumerado, así que el
  /// formulario ofrece esas dos y no una caja de texto libre.
  final String tipo;

  /// Litros que transporta. El servidor no lo pone entero: es `FLOAT`.
  final double capacidad;

  /// Cerrada: no admite más carga hoy.
  ///
  /// No es lo mismo que `activo`. `activo` es si la unidad existe en el
  /// calendario; `cerrado` es el estado de hoy. Por eso son dos campos y no uno.
  final bool cerrado;

  final bool activo;

  final int? plantaId;

  /// Chófer asignado. Admite nulo: hay unidades sin conductor, y ese es un
  /// estado legítimo al que se llega creando la unidad antes de repartir el
  /// turno.
  final int? acopiadorId;

  factory Unidad.fromJson(Map<String, dynamic> json) => Unidad(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String? ?? 'furgon',
        // `as num?` y no `as double?`: la API puede mandar `1500` entero y en
        // Dart un `int` no es un `double`, así que el cast directo fallaría.
        capacidad: (json['capacidad'] as num?)?.toDouble() ?? 0,
        cerrado: json['cerrado'] as bool? ?? false,
        activo: json['activo'] as bool? ?? true,
        plantaId: json['plantaId'] as int?,
        acopiadorId: json['acopiadorId'] as int?,
      );

  Unidad copyWith({
    String? nombre,
    String? tipo,
    double? capacidad,
    bool? cerrado,
    bool? activo,
    int? acopiadorId,
    bool limpiarAcopiador = false,
  }) {
    return Unidad(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      capacidad: capacidad ?? this.capacidad,
      cerrado: cerrado ?? this.cerrado,
      activo: activo ?? this.activo,
      plantaId: plantaId,
      // Sin este flag no se podría quitar el conductor: `null` se confundiría
      // con "no tocarlo".
      acopiadorId: limpiarAcopiador ? null : (acopiadorId ?? this.acopiadorId),
    );
  }
}

/// Los dos tipos de unidad que admite el servidor.
enum TipoUnidad {
  furgon('furgon', 'Furgón'),
  motocarga('motocarga', 'Motocarga');

  const TipoUnidad(this.valor, this.etiqueta);

  /// Texto exacto que va y viene por la API.
  final String valor;

  /// Cómo se lo enseña a la persona.
  final String etiqueta;

  static TipoUnidad desdeTexto(String? texto) => switch (texto) {
        'motocarga' => TipoUnidad.motocarga,
        _ => TipoUnidad.furgon,
      };
}

/// Una página de unidades con su estado de paginación.
class UnidadesPagina {
  const UnidadesPagina({
    required this.unidades,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Unidad> unidades;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory UnidadesPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return UnidadesPagina(
      unidades: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Unidad.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}