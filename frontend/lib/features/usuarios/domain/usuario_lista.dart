import '../../auth/domain/sesion.dart';

/// Usuario tal como lo devuelve `GET /usuarios`.
///
/// No es el mismo tipo que `UsuarioSesion`: aquí viene el registro completo con
/// planta y rol, y ese es el que se lista y edita. El otro es lo que la sesión
/// lleva encima para pintar la cabecera.
class UsuarioLista {
  const UsuarioLista({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    required this.activo,
    this.plantaId,
    this.planta,
    this.imagen,
    this.ultimoAcceso,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final Rol rol;
  final bool activo;
  final int? plantaId;
  final dynamic planta;
  final String? imagen;
  final DateTime? ultimoAcceso;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p.isNotEmpty).toList();
    return partes.isEmpty ? email : partes.join(' ');
  }

  /// Iniciales para la lista: "Ana Prueba" -> "AP".
  ///
  /// Con un solo nombre se cae a la primera letra, porque "A" es mejor que una
  /// inicial vacía.
  String get iniciales {
    final partes = [nombre, apellido].where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) {
      return '?';
    }

    // `substring(0, 1)` y no `characters.first`: `characters` haría falta para
    // contar letras, y aquí solo se toma la primera. Añadir una dependencia por
    // eso sería más coste que ventaja.
    return partes.map((p) => p.substring(0, 1).toUpperCase()).join();
  }

  factory UsuarioLista.fromJson(Map<String, dynamic> json) => UsuarioLista(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String? ?? '',
        email: json['email'] as String? ?? '',
        rol: Rol.fromJson(
          (json['rol'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
        ),
        activo: json['activo'] as bool? ?? true,
        plantaId: json['plantaId'] as int?,
        planta: json['planta'],
        imagen: json['imagen'] as String?,
        ultimoAcceso: DateTime.tryParse(json['ultimoAcceso'] as String? ?? ''),
      );

  UsuarioLista copyWith({Rol? rol, bool? activo, String? nombre, String? apellido}) {
    return UsuarioLista(
      id: id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      plantaId: plantaId,
      planta: planta,
      imagen: imagen,
      ultimoAcceso: ultimoAcceso,
    );
  }
}

/// Una página de usuarios con su estado de paginación.
class UsuariosPagina {
  const UsuariosPagina({
    required this.usuarios,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<UsuarioLista> usuarios;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory UsuariosPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return UsuariosPagina(
      usuarios: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(UsuarioLista.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}