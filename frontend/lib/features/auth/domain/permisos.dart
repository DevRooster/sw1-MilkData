/// Los recursos que puede usar el token actual.
///
/// Viene de `GET /auth/permisos`, que devuelve la misma matriz que aplica el
/// backend a cada petición. **No se reescribe aquí a propósito**: si la app
/// decidiera por su cuenta qué módulos mostrar, tendría su propia copia de la
/// matriz, las dos se desincronizarían, y el síntoma sería un módulo visible en
/// el menú al que la API contesta 403.
class Permisos {
  const Permisos({
    required this.rol,
    required this.recursos,
    this.superadmin = false,
    this.plantaId,
  });

  final String rol;
  final bool superadmin;
  final int? plantaId;

  /// Operaciones por recurso: `{'unidades': ['read', 'write'], ...}`.
  final Map<String, List<String>> recursos;

  /// ¿Puede abrir este módulo?
  ///
  /// Lo que decide es si puede **leer**: un módulo del que solo puede escribir
  /// y no leer no tiene pantalla, porque no hay nada que mostrar.
  bool puede(String recurso) => puedeCon(recurso, 'read');

  /// ¿Puede hacer esta operación sobre este módulo?
  bool puedeCon(String recurso, String operacion) {
    final concedidas = recursos[recurso];
    if (concedidas == null) {
      return false;
    }
    // `write` implica `read`: es lo mismo que aplica `authorizeMiddleware`, para
    // que el móvil y el servidor cuenten igual.
    return concedidas.contains(operacion) ||
        (concedidas.contains('write') && operacion == 'read');
  }

  factory Permisos.fromJson(Map<String, dynamic> json) {
    final crudo = json['recursos'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final recursos = <String, List<String>>{
      for (final entrada in crudo.entries)
        entrada.key: (entrada.value as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(),
    };

    return Permisos(
      rol: json['rol'] as String? ?? '',
      superadmin: json['superadmin'] as bool? ?? false,
      plantaId: json['plantaId'] as int?,
      recursos: recursos,
    );
  }

  /// Sin nada concedido.
  ///
  /// Se usa mientras la respuesta no ha llegado. Sale vacío a propósito: el
  /// menú se dibuja sin módulos y se rellena solo cuando llegan, en vez de
  /// suponer que el rol puede de todo.
  static const Permisos vacio = Permisos(rol: '', recursos: {});
}