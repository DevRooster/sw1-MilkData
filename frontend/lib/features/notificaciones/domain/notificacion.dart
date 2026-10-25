/// Aviso a un proveedor o a un usuario de la planta.
///
/// Notificaciones tiene **dos estados de vida** que no se deducen del registro:
///
/// - Un aviso creado con `POST /notificaciones` es un **borrador**: existe en la
///   base pero nadie lo ha recibido (`enviada` en `false`, sin fecha de envío).
/// - El mismo aviso creado con `POST /notificaciones/enviar` **sale** con
///   `enviada` en `true` y la fecha puesta por el servidor.
///
/// Y hay una trampa: **al editar una ya enviada no hay ningún bloqueo**. El
/// servidor acepta cambiarle el título a un aviso que el proveedor ya leyó. La
/// app lo avisa, pero no puede impedirlo sin inventarse una regla que el
/// servidor no tiene.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    required this.enviada,
    this.proveedorId,
    this.usuarioId,
    this.fechaEnvio,
    this.proveedor,
    this.usuario,
  });

  final int id;

  /// A quién va dirigida. **Es opcional**: un aviso puede ir a la planta entera
  /// y no a nadie en concreto.
  final int? proveedorId;

  /// Quién lo escribió. Opcional por el mismo motivo.
  final int? usuarioId;

  /// `adulteracion`, `reunion` o `capacitacion`. No hay un cuarto valor: el
  /// `ENUM` de la base los rechaza.
  final String tipo;

  final String titulo;
  final String mensaje;

  /// Si quien lo recibe ya lo ha visto. Se cambia con un `PUT`; no hay endpoint
  /// aparte para marcarlo.
  final bool leida;

  /// Si salió hacia el proveedor. Lo pone el endpoint de enviar, no la app.
  final bool enviada;

  /// Cuándo salió. La pone el servidor.
  final DateTime? fechaEnvio;

  final NotificacionProveedor? proveedor;
  final NotificacionUsuario? usuario;

  /// `true` si solo se guardó y todavía no salió.
  bool get esBorrador => !enviada;

  /// `true` si sale a un proveedor concreto en vez de a la planta entera.
  bool get esDirigida => proveedorId != null;

  /// A quién se le manda, en palabras.
  ///
  /// El backend anida al proveedor, así que el nombre está disponible. Cuando no
  /// hay proveedor —un aviso para la planta— dice eso mismo en lugar de enseñar
  /// un hueco.
  String get destinatario {
    final nombre = proveedor?.nombreCompleto;
    if (nombre != null) {
      return nombre;
    }
    return esDirigida ? 'Proveedor #$proveedorId' : 'Toda la planta';
  }

  /// La fecha de envío en corto, o `null` si no se ha enviado.
  ///
  /// Depende de `enviada` y no de la fecha: el servidor **no borra** `fechaEnvio`
  /// cuando alguien hace un `PUT { enviada: false }`, así que un aviso puede
  /// tener fecha y no estar enviado. Mostrar la fecha en ese caso daría a
  /// entender que salió cuando no.
  String? get fechaEnvioLegible {
    if (!enviada || fechaEnvio == null) {
      return null;
    }

    final d = fechaEnvio!;
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year}';
  }

  /// El mensaje, recortado para la fila.
  ///
  /// Corta **por un espacio**, no en el límite exacto de caracteres: un corte a
  /// media palabra se lee como un fallo de la pantalla y no como un resumen. Los
  /// seis puntos suspensivos van al final, ya sin el espacio que los precedía.
  String get mensajeCorto {
    const limite = 90;
    if (mensaje.length <= limite) {
      return mensaje;
    }

    final troceado = mensaje.substring(0, limite);
    final ultimoEspacio = troceado.lastIndexOf(' ');

    // Sin espacio en el trozo —un texto de una sola palabra larguísima—, se corta
    // donde toque: antes de dejar la fila vacía.
    final cuerpo = ultimoEspacio > 0 ? troceado.substring(0, ultimoEspacio) : troceado;

    return '$cuerpo…';
  }

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
        id: json['id'] as int? ?? 0,
        proveedorId: json['proveedorId'] as int?,
        usuarioId: json['usuarioId'] as int?,
        tipo: json['tipo'] as String? ?? adulteracion,
        titulo: json['titulo'] as String? ?? '',
        mensaje: json['mensaje'] as String? ?? '',
        leida: json['leida'] as bool? ?? false,
        enviada: json['enviada'] as bool? ?? false,
        fechaEnvio: DateTime.tryParse(json['fechaEnvio'] as String? ?? ''),
        proveedor: json['proveedor'] == null
            ? null
            : NotificacionProveedor.fromJson(json['proveedor'] as Map<String, dynamic>),
        usuario: json['usuario'] == null
            ? null
            : NotificacionUsuario.fromJson(json['usuario'] as Map<String, dynamic>),
      );

  /// Los tres tipos del `ENUM` de la base.
  ///
  /// Constantes y no cadenas sueltas: aparecen en el modelo, en el formulario y
  /// en las pruebas, y tres copias de `"reunion"` divergirían en cuanto una se
  /// escribiera con tilde o mayúscula.
  static const String adulteracion = 'adulteracion';
  static const String reunion = 'reunion';
  static const String capacitacion = 'capacitacion';

  /// Los tres, en el orden en que los enseña el formulario.
  static const List<String> tipos = [adulteracion, reunion, capacitacion];

  /// Cómo se lee cada tipo en la lista.
  static String etiquetaDeTipo(String tipo) {
    switch (tipo) {
      case adulteracion:
        return 'Adulteración';
      case reunion:
        return 'Reunión';
      case capacitacion:
        return 'Capacitación';
      default:
        // Si el servidor añadiera un tipo mañana, se enseña crudo en vez de
        // dejar la fila en blanco.
        return tipo;
    }
  }

  Notificacion copyWith({
    String? titulo,
    String? mensaje,
    String? tipo,
    int? proveedorId,
    bool? leida,
    bool limpiarProveedor = false,
  }) {
    return Notificacion(
      id: id,
      // Sin `limpiarProveedor` no se podría pasar de "a un proveedor" a "a la
      // planta entera": `null` es justo el valor que significa eso.
      proveedorId: limpiarProveedor ? null : (proveedorId ?? this.proveedorId),
      usuarioId: usuarioId,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      leida: leida ?? this.leida,
      // `enviada` y `fechaEnvio` no se tocan: son del servidor. La app nunca
      // hace un `PUT` de `enviada`, porque el servidor no borra la fecha al
      // ponerla en `false` y el resultado sería un "borrador" con fecha de
      // envío.
      enviada: enviada,
      fechaEnvio: fechaEnvio,
      proveedor: proveedor,
      usuario: usuario,
    );
  }
}

/// Lo justo del proveedor para reconocer a quién se avisa.
class NotificacionProveedor {
  const NotificacionProveedor({required this.id, required this.nombre, this.apellido, this.codigo});

  final int id;
  final String nombre;
  final String? apellido;
  final String? codigo;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Proveedor $id' : partes.join(' ');
  }

  factory NotificacionProveedor.fromJson(Map<String, dynamic> json) => NotificacionProveedor(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        codigo: json['codigo'] as String?,
      );
}

class NotificacionUsuario {
  const NotificacionUsuario({required this.id, required this.nombre, this.apellido});

  final int id;
  final String nombre;
  final String? apellido;

  factory NotificacionUsuario.fromJson(Map<String, dynamic> json) => NotificacionUsuario(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
      );
}

/// Una página de avisos con su paginación.
class NotificacionesPagina {
  const NotificacionesPagina({
    required this.notificaciones,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Notificacion> notificaciones;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory NotificacionesPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return NotificacionesPagina(
      notificaciones: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Notificacion.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}