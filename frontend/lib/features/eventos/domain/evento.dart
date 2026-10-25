/// Un evento al que se puede asistir.
///
/// Nace de un problema concreto del módulo de Asistencias: el evento era un texto
/// libre de 150 caracteres y cada quien lo escribía a su modo —"Reunion de ruta",
/// "reunion de ruta", "REUNION RUTA NORTE"— así que buscar una charla concreta no
/// encontraba las tres primeras. Con entidad propia se escribe una vez y se elige.
///
/// A diferencia del resto de módulos, aquí **no hay color ni nada raro**: es un
/// nombre, un día, un sitio y una nota.
class Evento {
  const Evento({
    required this.id,
    required this.nombre,
    required this.fecha,
    required this.plantaId,
    this.lugar,
    this.descripcion,
  });

  final int id;

  /// De qué planta es. **Todos los registros que puede ver una persona son de su
  /// misma planta** —el backend lo garantiza— así que esto es información, no un
  /// filtro. Va en el modelo porque la fila lo enseña.
  final int plantaId;

  /// Cómo se llama. Obligatorio, y único dentro de la planta.
  final String nombre;

  /// El día, `YYYY-MM-DD`. **Obligatorio**: un evento sin día no se puede ordenar
  /// ni buscar por rango, y un "próximo evento" sin fecha hay que acordarse.
  final String fecha;

  final String? lugar;
  final String? descripcion;

  /// El día en corto, `dd/mm/aaaa`.
  ///
  /// `2026-10-20` no lo lee nadie de un vistazo.
  String get fechaLegible {
    if (fecha.length < 10) {
      return fecha;
    }
    return '${fecha.substring(8, 10)}/${fecha.substring(5, 7)}/${fecha.substring(0, 4)}';
  }

  /// Nombre y sitio en una línea, para el desplegable de Asistencias.
  ///
  /// El sitio solo si lo hay: "Reunión de ruta · Sala de reuniones" se lee bien,
  /// pero "Capacitación · " con un punto y nada detrás parece un texto roto.
  String get etiquetaCorta {
    final sitio = lugar?.trim();
    if (sitio == null || sitio.isEmpty) {
      return nombre;
    }

    return '$nombre · $sitio';
  }

  /// Si el evento ya pasó.
  ///
  /// Se compara contra el día local y no contra la fecha y la hora: un evento de
  /// hoy sigue siendo "hoy" a las once de la noche.
  bool get yaPaso {
    final hoy = DateTime.now();
    final deHoy = '${hoy.year.toString().padLeft(4, '0')}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';

    return fecha.compareTo(deHoy) < 0;
  }

  /// Tope de caracteres del nombre, el de la columna.
  static const int maximoNombre = 150;

  /// Tope del lugar, también el de la columna.
  static const int maximoLugar = 150;

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
        id: json['id'] as int? ?? 0,
        plantaId: json['plantaId'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
        lugar: json['lugar'] as String?,
        descripcion: json['descripcion'] as String?,
      );

  Evento copyWith({
    String? nombre,
    String? fecha,
    String? lugar,
    String? descripcion,
    bool limpiarLugar = false,
    bool limpiarDescripcion = false,
  }) {
    return Evento(
      id: id,
      plantaId: plantaId,
      nombre: nombre ?? this.nombre,
      fecha: fecha ?? this.fecha,
      lugar: limpiarLugar ? null : (lugar ?? this.lugar),
      descripcion: limpiarDescripcion ? null : (descripcion ?? this.descripcion),
    );
  }
}

/// Una página de eventos con su paginación.
class EventosPagina {
  const EventosPagina({
    required this.eventos,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Evento> eventos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory EventosPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return EventosPagina(
      eventos: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Evento.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}