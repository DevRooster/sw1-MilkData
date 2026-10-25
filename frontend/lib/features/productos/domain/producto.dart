/// Producto tal como lo devuelve `GET /productos`.
///
/// El precio llega como número, no como cadena: el DTO del backend ya hace
/// `Number(entidad.precioVenta)`. Viene de un `DECIMAL(10,2)` en MySQL, así
/// que llega como `double` en Dart y se formatea al mostrar.
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.estado,
    this.descripcion,
    this.unidadMedida,
    this.precioVenta = 0,
    this.imagen,
    this.plantaId,
  });

  final int id;
  final String nombre;
  final String? descripcion;

  /// Cómo se vende: "unidad", "litro", "kilo"...
  ///
  /// Es texto libre, no un enumerado: la planta decide qué vende. Por eso el
  /// formulario lo ofrece como sugerencias en vez de un selector cerrado, que
  /// obligaría a adivinar una lista que no existe en el servidor.
  final String? unidadMedida;

  final double precioVenta;

  /// Imagen principal. La galería completa está en el módulo de imágenes; esta
  /// es la que se ve en la lista, y el backend la mantiene desnormalizada.
  final String? imagen;

  final bool estado;
  final int? plantaId;

  /// Precio con dos decimales y coma decimal: los precios no se leen con punto
  /// en un móvil, y menos cuando el número viene de una base de datos.
  String get precioFormateado {
    final entero = precioVenta.truncate();
    final decimales = ((precioVenta - entero) * 100).round().abs().toString().padLeft(2, '0');
    return '$entero,$decimales';
  }

  /// Lo que se ve bajo el nombre: unidad y precio juntos, o solo uno de los dos.
  String get resumen {
    final partes = <String>[];
    if (unidadMedida != null && unidadMedida!.isNotEmpty) {
      partes.add('por ${unidadMedida!}');
    }
    partes.add(precioFormateado);
    return partes.join(' · ');
  }

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        descripcion: json['descripcion'] as String?,
        unidadMedida: json['unidadMedida'] as String?,
        // `as num?` y no `as double?`: la API puede mandar `3` entero y un `int`
        // no es un `double` en Dart, así que el cast directo fallaría.
        precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0,
        imagen: json['imagen'] as String?,
        estado: json['estado'] as bool? ?? true,
        plantaId: json['plantaId'] as int?,
      );

  Producto copyWith({
    String? nombre,
    String? descripcion,
    String? unidadMedida,
    double? precioVenta,
    String? imagen,
    bool? estado,
    bool limpiarImagen = false,
    bool limpiarUnidad = false,
  }) {
    return Producto(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      // Sin estos dos flags no se podría vaciar un campo: `null` es justamente
      // el valor que significa "quítalo".
      unidadMedida: limpiarUnidad ? null : (unidadMedida ?? this.unidadMedida),
      precioVenta: precioVenta ?? this.precioVenta,
      imagen: limpiarImagen ? null : (imagen ?? this.imagen),
      estado: estado ?? this.estado,
      plantaId: plantaId,
    );
  }
}

/// Unidades de medida que se sugieren al escribir.
///
/// No son un enumerado cerrado: el servidor acepta cualquier texto de hasta 30
/// caracteres. Son solo atajos para lo habitual en una planta lechera, y el
/// campo sigue siendo de escritura libre.
const List<String> unidadesSugeridas = <String>[
  'unidad',
  'litro',
  'kilo',
  'paquete',
  'caja',
];

/// Una página de productos con su estado de paginación.
class ProductosPagina {
  const ProductosPagina({
    required this.productos,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Producto> productos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory ProductosPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ProductosPagina(
      productos: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Producto.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}