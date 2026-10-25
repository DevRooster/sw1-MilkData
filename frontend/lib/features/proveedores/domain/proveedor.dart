/// Proveedor tal como lo devuelve `GET /proveedores`.
///
/// **No tiene `rutaId`.** En qué ruta está un proveedor se dice en las paradas
/// de esa ruta (`POST/DELETE /rutas/{id}/paradas`), no en su propia ficha: la
/// columna `proveedor.ruta_id` se mantiene sola y escribirla por su cuenta
/// dejaba proveedores que decían estar en una ruta y cuya parada estaba en
/// otra. Por eso el backend rechaza la clave, incluso valiendo `null`.
class Proveedor {
  const Proveedor({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.codigo,
    required this.activo,
    this.telefono,
    this.direccion,
    this.zonaId,
    this.usuarioId,
    this.imagen,
  });

  final int id;
  final String nombre;
  final String apellido;

  /// Documento de identidad. Es único en toda la base, no solo en la planta:
  /// dos proveedores con el mismo DNI son la misma persona.
  final String dni;

  /// Código corto con el que se trabaja en la hoja de rutas. También único.
  final String codigo;

  final String? telefono;

  /// Dirección. Opcional, y el backend la devuelve desde que se corrigió el DTO:
  /// antes se guardaba pero no salía, y el segundo guardado la borraba.
  final String? direccion;

  /// Zona a la que pertenece, o `null` si no tiene ninguna asignada.
  final int? zonaId;

  /// Cuenta de usuario enlazada, o `null` si es un proveedor sin acceso.
  final int? usuarioId;

  final String? imagen;
  final bool activo;

  String get nombreCompleto => '$nombre $apellido'.trim();

  /// Lo que va debajo del nombre: el código y la zona si la tiene.
  ///
  /// La zona sale como número porque es lo que devuelve la lista. La pantalla
  /// que sí sabe el nombre de la zona —el formulario— lo resuelve aparte; no
  /// aquí, porque sería una petición extra por cada fila.
  String get resumen {
    final partes = <String>[codigo];
    if (zonaId != null) {
      partes.add('zona #$zonaId');
    }
    return partes.join(' · ');
  }

  factory Proveedor.fromJson(Map<String, dynamic> json) => Proveedor(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String? ?? '',
        dni: json['dni'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        telefono: json['telefono'] as String?,
        direccion: json['direccion'] as String?,
        zonaId: json['zonaId'] as int?,
        usuarioId: json['usuarioId'] as int?,
        imagen: json['imagen'] as String?,
        activo: json['activo'] as bool? ?? true,
      );

  Proveedor copyWith({
    String? nombre,
    String? apellido,
    String? dni,
    String? codigo,
    String? telefono,
    String? direccion,
    int? zonaId,
    bool? activo,
    bool limpiarZona = false,
  }) {
    return Proveedor(
      id: id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      dni: dni ?? this.dni,
      codigo: codigo ?? this.codigo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      // Sin este flag no se podría sacar de una zona: `null` es justamente el
      // valor que significa eso.
      zonaId: limpiarZona ? null : (zonaId ?? this.zonaId),
      usuarioId: usuarioId,
      imagen: imagen,
      activo: activo ?? this.activo,
    );
  }
}

/// Zona de un proveedor, tal como viene anidada en la respuesta.
class ZonaProveedor {
  const ZonaProveedor({
    required this.id,
    required this.nombre,
    this.horaInicio,
    this.horaFin,
    this.ruta,
  });

  final int id;
  final String nombre;
  final String? horaInicio;
  final String? horaFin;

  /// Nombre de la ruta a la que confluye la zona, si el backend lo trae.
  final String? ruta;

  factory ZonaProveedor.fromJson(Map<String, dynamic> json) => ZonaProveedor(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        horaInicio: json['horaInicio'] as String?,
        horaFin: json['horaFin'] as String?,
        ruta: json['ruta'] as String?,
      );
}

/// Una página de proveedores con su estado de paginación.
class ProveedoresPagina {
  const ProveedoresPagina({
    required this.proveedores,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Proveedor> proveedores;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory ProveedoresPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ProveedoresPagina(
      proveedores: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Proveedor.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}
