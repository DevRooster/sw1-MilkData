/// Planta que devuelve `GET /auth/plantas`.
///
/// Es la lista de plantas que el usuario puede supervisar. El alcance decide
/// cuántas son: un admin ve solo la suya, un superadmin las ve todas.
class Planta {
  const Planta({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.direccion,
    this.activo = true,
  });

  final int id;
  final String nombre;
  final String codigo;
  final String? direccion;
  final bool activo;

  factory Planta.fromJson(Map<String, dynamic> json) => Planta(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        direccion: json['direccion'] as String?,
        activo: json['activo'] as bool? ?? true,
      );
}

/// Alcance del usuario sobre las plantas.
///
/// La API lo manda como texto: `PROPIA` para un admin, `TODAS` para un
/// superadmin. Se parsesa a enum para no andar comparando cadenas sueltas por
/// la app.
enum AlcancePlantas {
  propia('PROPIA', 'Solo tu planta'),
  todas('TODAS', 'Todas las plantas');

  const AlcancePlantas(this.valor, this.etiqueta);

  /// Texto exacto que manda la API.
  final String valor;

  /// Cómo se lo explica a la persona.
  final String etiqueta;

  static AlcancePlantas desdeTexto(String? texto) => switch (texto) {
        'TODAS' => AlcancePlantas.todas,
        _ => AlcancePlantas.propia,
      };
}

/// Respuesta de `GET /auth/plantas`.
class PlantasDisponibles {
  const PlantasDisponibles({
    required this.alcance,
    required this.plantas,
    required this.total,
  });

  final AlcancePlantas alcance;
  final List<Planta> plantas;
  final int total;

  factory PlantasDisponibles.fromJson(Map<String, dynamic> json) => PlantasDisponibles(
        alcance: AlcancePlantas.desdeTexto(json['alcance'] as String?),
        plantas: (json['plantas'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Planta.fromJson)
            .toList(),
        total: json['total'] as int? ?? 0,
      );
}

/// Token nuevo emitido por `POST /auth/refresh` o `POST /auth/planta`.
class TokenEmitido {
  const TokenEmitido({required this.token});

  final String token;
}