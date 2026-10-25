/// Ruta tal como la devuelve `GET /rutas`: sin paradas, solo cuántas tiene.
///
/// **El mismo nombre `paradas` significa dos cosas distintas** según de dónde
/// venga la respuesta: en el listado es un número y en el detalle es una lista
/// de objetos. Por eso hay dos tipos en vez de uno con un campo que a veces es
/// un `int` y otras un `List`: un campo así obliga a preguntar siempre de dónde
/// salió el dato, y se acabaría convirtiendo en un `dynamic`.
class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.activa,
    this.descripcion,
    this.horaInicio,
    this.horaFin,
    this.paradasCount = 0,
    this.zonas = const <ZonaRuta>[],
  });

  final int id;
  final String nombre;
  final String codigo;
  final String? descripcion;

  /// Hora de inicio prevista, como `HH:MM:SS`. Es de planning: cuándo debería
  /// salir, no cuándo salió.
  final String? horaInicio;
  final String? horaFin;

  final bool activa;

  /// Cuántas paradas tiene. En el listado viene como número.
  final int paradasCount;

  /// Zonas que confluyen en esta ruta.
  final List<ZonaRuta> zonas;

  /// Horario en formato corto, `06:00 – 11:00`.
  ///
  /// Si falta uno de los dos no se inventa nada: se enseña solo el que hay.
  String get horario {
    final desde = _horaCorta(horaInicio);
    final hasta = _horaCorta(horaFin);

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
  static String? _horaCorta(String? valor) {
    if (valor == null || valor.isEmpty) {
      return null;
    }
    return valor.length >= 5 ? valor.substring(0, 5) : valor;
  }

  factory Ruta.fromJson(Map<String, dynamic> json) => Ruta(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        descripcion: json['descripcion'] as String?,
        horaInicio: json['horaInicio'] as String?,
        horaFin: json['horaFin'] as String?,
        activa: json['activa'] as bool? ?? true,
        paradasCount: json['paradas'] is int ? json['paradas'] as int : 0,
        zonas: (json['zonas'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ZonaRuta.fromJson)
            .toList(),
      );

  Ruta copyWith({
    String? nombre,
    String? codigo,
    String? descripcion,
    String? horaInicio,
    String? horaFin,
    bool? activa,
  }) {
    return Ruta(
      id: id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      activa: activa ?? this.activa,
      paradasCount: paradasCount,
      zonas: zonas,
    );
  }
}

/// Ruta con sus paradas, que es lo que devuelve `GET /rutas/{id}`.
class RutaDetalle extends Ruta {
  const RutaDetalle({
    required super.id,
    required super.nombre,
    required super.codigo,
    required super.activa,
    super.descripcion,
    super.horaInicio,
    super.horaFin,
    super.zonas,
    this.paradas = const <ParadaRuta>[],
  }) : super(paradasCount: 0);

  /// Paradas en el orden en que se recorren.
  final List<ParadaRuta> paradas;

  @override
  int get paradasCount => paradas.length;

  factory RutaDetalle.fromJson(Map<String, dynamic> json) {
    final base = Ruta.fromJson(json);

    return RutaDetalle(
      id: base.id,
      nombre: base.nombre,
      codigo: base.codigo,
      descripcion: base.descripcion,
      horaInicio: base.horaInicio,
      horaFin: base.horaFin,
      activa: base.activa,
      zonas: base.zonas,
      paradas: (json['paradas'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ParadaRuta.fromJson)
          .toList(),
    );
  }
}

/// Una parada de una ruta: un proveedor en un punto del recorrido.
class ParadaRuta {
  const ParadaRuta({
    required this.id,
    required this.proveedorId,
    required this.orden,
    required this.activa,
    this.horaEstimada,
    this.proveedor,
  });

  final int id;
  final int proveedorId;

  /// Posición en el recorrido, contando desde 1.
  final int orden;

  final String? horaEstimada;
  final bool activa;
  final ProveedorRuta? proveedor;

  factory ParadaRuta.fromJson(Map<String, dynamic> json) => ParadaRuta(
        id: json['id'] as int? ?? 0,
        proveedorId: json['proveedorId'] as int? ?? 0,
        orden: json['orden'] as int? ?? 0,
        horaEstimada: json['horaEstimada'] as String?,
        activa: json['activa'] as bool? ?? true,
        proveedor: json['proveedor'] == null
            ? null
            : ProveedorRuta.fromJson(
                (json['proveedor'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
              ),
      );
}

/// El proveedor que se visita en una parada.
///
/// Solo los datos que hacen falta para reconocerlo en la lista: la ficha
/// completa es cosa del módulo de Proveedores.
class ProveedorRuta {
  const ProveedorRuta({
    required this.id,
    required this.nombre,
    this.apellido,
    this.codigo,
  });

  final int id;
  final String nombre;
  final String? apellido;
  final String? codigo;

  String get nombreCompleto {
    // El apellido puede venir vacío, y un `isNotEmpty` sobre un `String?`
    // revienta: hay que filtrar los nulos antes de mirar el texto.
    final partes = [nombre, apellido]
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
    return partes.isEmpty ? 'Proveedor $id' : partes.join(' ');
  }

  factory ProveedorRuta.fromJson(Map<String, dynamic> json) => ProveedorRuta(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        codigo: json['codigo'] as String?,
      );
}

/// Zona de una ruta.
class ZonaRuta {
  const ZonaRuta({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory ZonaRuta.fromJson(Map<String, dynamic> json) => ZonaRuta(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
      );
}

/// Una página de rutas con su estado de paginación.
class RutasPagina {
  const RutasPagina({
    required this.rutas,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Ruta> rutas;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory RutasPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return RutasPagina(
      rutas: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Ruta.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}