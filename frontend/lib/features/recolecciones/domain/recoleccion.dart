/// Recolección tal como la devuelve `GET /recolecciones`.
///
/// Una recogida es un volumen, de un proveedor, en una zona, con una unidad, un
/// día y una hora. **`registradoEn` dice dónde se anotó** —en el campo o ya en la
/// planta— y no es un adorno: es lo que separa lo pendiente de subir de lo que ya
/// está en el sistema.
class Recoleccion {
  const Recoleccion({
    required this.id,
    required this.proveedorId,
    required this.zonaId,
    required this.unidadId,
    required this.usuarioId,
    required this.cantidad,
    required this.fecha,
    required this.registradoEn,
    required this.sincronizado,
    this.hora,
    this.temperatura,
    this.recorridoParadaId,
    this.proveedor,
    this.zona,
    this.unidad,
    this.usuario,
  });

  final int id;
  final int proveedorId;
  final int zonaId;
  final int unidadId;

  /// Quién la anotó. El servidor no lo deduce de la sesión: hay que mandarlo,
  /// porque una recogida se puede registrar en nombre de otro.
  final int usuarioId;

  /// Litros recogidos.
  final double cantidad;

  /// Día de la recogida, `YYYY-MM-DD`. Es `DATEONLY`.
  final String fecha;

  /// Hora de la recogida. Viene como `HH:MM:SS`, y es opcional: hay recogidas
  /// en las que no se anotó la hora.
  final String? hora;

  /// Temperatura de la leche en el momento de recogerla, si se midió.
  final double? temperatura;

  /// La parada del recorrido de la que salió, si salió de una.
  ///
  /// Antes el DTO no lo devolvía, así que una recogida hecha en el campo llegaba
  /// a la app sin ningún vínculo con el recorrido que la originó.
  final int? recorridoParadaId;

  /// `campo` si se anotó allí, `planta` si se anotó ya en la oficina.
  final String registradoEn;

  /// Si ya está subida. Viene `false` en un alta y lo pone el sincronizador.
  final bool sincronizado;

  final RecoleccionProveedor? proveedor;
  final RecoleccionZona? zona;
  final RecoleccionUnidad? unidad;
  final RecoleccionUsuario? usuario;

  /// `true` si se anotó en el campo.
  bool get enCampo => registradoEn == Recoleccion.campo;

  /// Litros con una coma decimal y sin decimales de más.
  ///
  /// `25.500000` sale de la base y no lo lee nadie; `25,5` sí.
  String get cantidadFormateada {
    if (cantidad == cantidad.truncateToDouble()) {
      return '${cantidad.truncate()} L';
    }
    return '${cantidad.toStringAsFixed(1).replaceAll('.', ',')} L';
  }

  /// La hora en corto, o `null` si no la hay.
  String? get horaLegible {
    if (hora == null || hora!.isEmpty) {
      return null;
    }
    return hora!.length >= 5 ? hora!.substring(0, 5) : hora!;
  }

  factory Recoleccion.fromJson(Map<String, dynamic> json) => Recoleccion(
        id: json['id'] as int? ?? 0,
        proveedorId: json['proveedorId'] as int? ?? 0,
        zonaId: json['zonaId'] as int? ?? 0,
        unidadId: json['unidadId'] as int? ?? 0,
        usuarioId: json['usuarioId'] as int? ?? 0,
        // `as num?` y no `as double?`: la API puede mandar `25` entero, y un
        // `int` no es un `double` en Dart.
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        fecha: json['fecha'] as String? ?? '',
        hora: json['hora'] as String?,
        temperatura: (json['temperatura'] as num?)?.toDouble(),
        recorridoParadaId: json['recorridoParadaId'] as int?,
        registradoEn: json['registradoEn'] as String? ?? planta,
        sincronizado: json['sincronizado'] as bool? ?? false,
        proveedor: json['proveedor'] == null
            ? null
            : RecoleccionProveedor.fromJson(json['proveedor'] as Map<String, dynamic>),
        zona: json['zona'] == null
            ? null
            : RecoleccionZona.fromJson(json['zona'] as Map<String, dynamic>),
        unidad: json['unidad'] == null
            ? null
            : RecoleccionUnidad.fromJson(json['unidad'] as Map<String, dynamic>),
        usuario: json['usuario'] == null
            ? null
            : RecoleccionUsuario.fromJson(json['usuario'] as Map<String, dynamic>),
      );

  /// Los dos valores que admite `registradoEn`.
  ///
  /// Son un `ENUM` de la base con esos dos valores. Van aquí como constantes
  /// y no como cadenas sueltas porque aparecen en el modelo, en el formulario y en
  /// las pruebas, y tres copias de `"campo"` divergirían en cuanto una se
  /// escribiera mal.
  static const String campo = 'campo';
  static const String planta = 'planta';

  Recoleccion copyWith({
    int? usuarioId,
    double? cantidad,
    String? fecha,
    String? hora,
    double? temperatura,
    int? recorridoParadaId,
    String? registradoEn,
    bool? sincronizado,
    bool limpiarHora = false,
    bool limpiarTemperatura = false,
    bool limpiarParada = false,
  }) {
    return Recoleccion(
      id: id,
      proveedorId: proveedorId,
      zonaId: zonaId,
      unidadId: unidadId,
      usuarioId: usuarioId ?? this.usuarioId,
      cantidad: cantidad ?? this.cantidad,
      fecha: fecha ?? this.fecha,
      // Los tres `limpiar` son por lo mismo que en los otros módulos: `null` es
      // justamente el valor que significa "quítalo", y sin un flag no se podría
      // quitar nada.
      hora: limpiarHora ? null : (hora ?? this.hora),
      temperatura: limpiarTemperatura ? null : (temperatura ?? this.temperatura),
      recorridoParadaId: limpiarParada ? null : (recorridoParadaId ?? this.recorridoParadaId),
      registradoEn: registradoEn ?? this.registradoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      proveedor: proveedor,
      zona: zona,
      unidad: unidad,
      usuario: usuario,
    );
  }
}

/// Lo mínimo de cada relación para reconocerla en una fila. La ficha completa es
/// cosa de los módulos de Proveedores, Zonas, Unidades y Usuarios.
class RecoleccionProveedor {
  const RecoleccionProveedor({required this.id, required this.nombre, this.apellido, this.codigo});

  final int id;
  final String nombre;
  final String? apellido;
  final String? codigo;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Proveedor $id' : partes.join(' ');
  }

  factory RecoleccionProveedor.fromJson(Map<String, dynamic> json) => RecoleccionProveedor(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        codigo: json['codigo'] as String?,
      );
}

class RecoleccionZona {
  const RecoleccionZona({required this.id, required this.nombre, this.ruta});

  final int id;
  final String nombre;
  final String? ruta;

  factory RecoleccionZona.fromJson(Map<String, dynamic> json) => RecoleccionZona(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        ruta: json['ruta'] as String?,
      );
}

class RecoleccionUnidad {
  const RecoleccionUnidad({required this.id, required this.nombre, this.tipo, this.capacidad});

  final int id;
  final String nombre;
  final String? tipo;
  final double? capacidad;

  factory RecoleccionUnidad.fromJson(Map<String, dynamic> json) => RecoleccionUnidad(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String?,
        capacidad: (json['capacidad'] as num?)?.toDouble(),
      );
}

class RecoleccionUsuario {
  const RecoleccionUsuario({required this.id, required this.nombre, this.apellido});

  final int id;
  final String nombre;
  final String? apellido;

  factory RecoleccionUsuario.fromJson(Map<String, dynamic> json) => RecoleccionUsuario(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
      );
}

/// Una página de recolecciones con su estado de paginación.
class RecoleccionesPagina {
  const RecoleccionesPagina({
    required this.recolecciones,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Recoleccion> recolecciones;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory RecoleccionesPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return RecoleccionesPagina(
      recolecciones: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Recoleccion.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}
