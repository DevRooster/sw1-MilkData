/// Rol del usuario, tal como lo devuelve la API.
///
/// La API lo manda como objeto anidado (`user.rol.nombre`), no como texto.
class Rol {
  const Rol({required this.id, required this.nombre, required this.nivel});

  final int id;
  final String nombre;
  final int nivel;

  factory Rol.fromJson(Map<String, dynamic> json) => Rol(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        nivel: json['nivel'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'nivel': nivel};
}

/// Usuario que inició sesión.
class UsuarioSesion {
  const UsuarioSesion({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    this.plantaId,
    this.plantaNombre,
    this.plantaCodigo,
    this.imagen,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final Rol rol;
  final int? plantaId;

  /// Cómo se llama la planta.
  ///
  /// Viene **en la sesión**, y no se pide aparte a propósito: un recolector no
  /// tiene permiso de `plantas: read`, así que no podría averiguar el nombre por
  /// otra vía, y una petición extra solo para pintar una etiqueta es una petición
  /// que se cae en cuanto el móvil pierde cobertura.
  final String? plantaNombre;

  /// El código corto de la planta, `HUA` en este caso.
  final String? plantaCodigo;

  final String? imagen;

  /// "Juan Pérez", para mostrar en la cabecera.
  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p.isNotEmpty).toList();
    return partes.isEmpty ? email : partes.join(' ');
  }

  /// El nombre de la planta, o `null` si el backend no lo mandó.
  ///
  /// `null` y no un texto de relleno: **es mejor no poner nada que poner "Planta"
  /// a secas**, porque "Planta" a secas parece el nombre de una planta llamada
  /// Planta.
  String? get plantaParaMostrar {
    final nombre = plantaNombre?.trim();
    return (nombre == null || nombre.isEmpty) ? null : nombre;
  }

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    // El anidado viene en `planta`. Se lee con calma porque el backend lo anida
    // solo cuando la consulta lo trajo: si no viene, se queda `null` y la
    // pantalla lo omite en vez de inventar un nombre.
    final planta = json['planta'] as Map<String, dynamic>?;

    return UsuarioSesion(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rol: Rol.fromJson(
        (json['rol'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      plantaId: json['plantaId'] as int?,
      plantaNombre: planta?['nombre'] as String?,
      plantaCodigo: planta?['codigo'] as String?,
      imagen: json['imagen'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'rol': rol.toJson(),
        'plantaId': plantaId,
        'planta': {
          'nombre': plantaNombre,
          'codigo': plantaCodigo,
        },
        'imagen': imagen,
      };
}

/// Sesión activa: el token y quién lo usa.
class Sesion {
  const Sesion({required this.token, required this.usuario});

  final String token;
  final UsuarioSesion usuario;

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
        token: json['token'] as String? ?? '',
        usuario: UsuarioSesion.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
        ),
      );
}