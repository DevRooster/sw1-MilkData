/// Asistencia de un proveedor a un evento.
///
/// Es un registro corto: quién, qué evento, qué día y cómo se anotó. Lo único
/// con forma cerrada es [registradoPor], que distingue **lo escaneado con QR de
/// lo apuntado a mano** —esa es la diferencia entre un registro fiable y una
/// anotación de memoria—.
///
/// [evento] es **texto libre**, no un catálogo cerrado. La columna es un
/// `VARCHAR(150)` y lo escribe quien registra la asistencia, así que no hay
/// desplegable posible: hay un campo y escribir lo que pasó.
class Asistencia {
  const Asistencia({
    required this.id,
    required this.proveedorId,
    required this.usuarioId,
    required this.evento,
    required this.fecha,
    required this.registradoPor,
    this.eventoId,
    this.eventoCatalogo,
    this.proveedor,
    this.usuario,
  });

  final int id;

  /// El proveedor al que se le registró la asistencia. Obligatorio.
  final int proveedorId;

  /// Quién lo registró. Obligatorio, y sale de la sesión: no es una decisión de
  /// quien rellena la pantalla, es quien está delante del móvil.
  final int usuarioId;

  /// Qué pasó, en texto libre. `VARCHAR(150)` en la base.
  final String evento;

  /// El evento **del catálogo** al que apunta esta asistencia, o `null`.
  ///
  /// **Son dos cosas distintas y por eso hay dos campos.** El texto es lo que
  /// escribió quien la anotó y sigue siendo obligatorio: hay asistencias viejas
  /// con textos como "reunion de ruta" en minúsculas y sin tilde, que no
  /// corresponden a ningún evento del catálogo y no se pueden adivinar. El
  /// catálogo es lo que hace que "buscar la capacitación de abril" funcione.
  final int? eventoId;

  final EventoAsistencia? eventoCatalogo;

  /// `true` cuando la asistencia viene apuntada a un evento del catálogo.
  ///
  /// La lista enseña el nombre del catálogo y no el texto cuando lo hay, porque
  /// el del catálogo es el que se escribió una vez y se puede comparar.
  bool get tieneEventoCatalogo => eventoCatalogo != null;

  /// El nombre que se enseña en la lista.
  ///
  /// El del catálogo si lo hay; si no, el texto que se escribió. **Nunca queda
  /// vacío**, porque el campo es obligatorio en la base.
  String get eventoLegible => eventoCatalogo?.nombre ?? evento;

  /// El día, `YYYY-MM-DD`. Es `DATEONLY`.
  final String fecha;

  /// `QR` o `manual`. **Obligatorio y sin valor por defecto en la base**: sin
  /// él, el alta falla con `asistencia.registradoPor cannot be null`.
  final String registradoPor;

  final AsistenciaProveedor? proveedor;
  final AsistenciaUsuario? usuario;

  /// `true` si se escaneó con QR.
  bool get esQr => registradoPor == Asistencia.qr;

  /// `true` si se anotó a mano.
  ///
  /// Los dos getters llevan `es` delante porque los valores del `ENUM` se llaman
  /// igual: un `Asistencia.manual` que devuelve `bool` y un `Asistencia.manual`
  /// que devuelve el texto `'manual'` no pueden convivir en Dart, y el que gana
  /// es el que se escriba sin querer.
  bool get esManual => registradoPor == Asistencia.manual;

  /// El día en corto, `dd/mm/aaaa`.
  ///
  /// `2026-10-13` no lo lee nadie de un vistazo; `13/10/2026` sí.
  String get fechaLegible {
    if (fecha.length < 10) {
      return fecha;
    }
    final dia = fecha.substring(8, 10);
    final mes = fecha.substring(5, 7);
    return '$dia/$mes/${fecha.substring(0, 4)}';
  }

  /// A quién se le registró, en palabras.
  String get nombreProveedor {
    final nombre = proveedor?.nombreCompleto;
    return nombre ?? 'Proveedor #$proveedorId';
  }

  /// Cómo se lee el origen del registro en la lista.
  String get etiquetaRegistro => esQr ? 'QR' : 'manual';

  factory Asistencia.fromJson(Map<String, dynamic> json) => Asistencia(
        id: json['id'] as int? ?? 0,
        proveedorId: json['proveedorId'] as int? ?? 0,
        usuarioId: json['usuarioId'] as int? ?? 0,
        evento: json['evento'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
        registradoPor: json['registradoPor'] as String? ?? registroPorDefecto,
        eventoId: json['eventoId'] as int?,
        // El backend lo llama `eventoRelacion` porque el nombre `evento` ya lo
        // ocupa el texto libre. Aquí se renombra a algo legible.
        eventoCatalogo: json['eventoRelacion'] == null
            ? null
            : EventoAsistencia.fromJson(
                json['eventoRelacion'] as Map<String, dynamic>,
              ),
        proveedor: json['proveedor'] == null
            ? null
            : AsistenciaProveedor.fromJson(json['proveedor'] as Map<String, dynamic>),
        usuario: json['usuario'] == null
            ? null
            : AsistenciaUsuario.fromJson(json['usuario'] as Map<String, dynamic>),
      );

  /// Los dos valores del `ENUM` de la base.
  ///
  /// Constantes y no cadenas sueltas: aparecen en el modelo, en el formulario y
  /// en las pruebas, y dos copias de `"QR"` divergirían en cuanto una se
  /// escribiera en minúsculas. El backend ahora distingue mayúsculas —la
  /// validación `isIn` lo hace—, así que el texto tiene que salir exacto.
  static const String qr = 'QR';
  static const String manual = 'manual';

  /// El origen del registro por defecto en el formulario.
  ///
  /// `manual`, porque **esta pantalla es el registro manual**: quien la abre está
  /// apuntando algo, no escaneando un QR. Poner `QR` por defecto sería cierto
  /// solo cuando hay un lector, y no lo hay.
  static const String registroPorDefecto = manual;

  /// Tope de caracteres de `evento`, el de la columna.
  ///
  /// El backend responde 400 si se pasa, pero en la app es mejor verlo antes:
  /// escribir 160 caracteres para que al final salga un error no ahorra nada.
  static const int maximoEvento = 150;

  Asistencia copyWith({
    String? evento,
    String? fecha,
    String? registradoPor,
    int? proveedorId,
  }) {
    return Asistencia(
      id: id,
      proveedorId: proveedorId ?? this.proveedorId,
      usuarioId: usuarioId,
      evento: evento ?? this.evento,
      fecha: fecha ?? this.fecha,
      registradoPor: registradoPor ?? this.registradoPor,
      proveedor: proveedor,
      usuario: usuario,
    );
  }
}

/// Lo mínimo del evento del catálogo para reconocerlo en una fila.
class EventoAsistencia {
  const EventoAsistencia({required this.id, required this.nombre, this.fecha, this.lugar});

  final int id;
  final String nombre;
  final String? fecha;
  final String? lugar;

  factory EventoAsistencia.fromJson(Map<String, dynamic> json) => EventoAsistencia(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        fecha: json['fecha'] as String?,
        lugar: json['lugar'] as String?,
      );
}

/// Lo mínimo del proveedor para reconocer a quién se le registró.
class AsistenciaProveedor {
  const AsistenciaProveedor({required this.id, required this.nombre, this.apellido, this.codigo});

  final int id;
  final String nombre;
  final String? apellido;
  final String? codigo;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Proveedor $id' : partes.join(' ');
  }

  factory AsistenciaProveedor.fromJson(Map<String, dynamic> json) => AsistenciaProveedor(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        codigo: json['codigo'] as String?,
      );
}

class AsistenciaUsuario {
  const AsistenciaUsuario({required this.id, required this.nombre, this.apellido, this.email});

  final int id;
  final String nombre;
  final String? apellido;
  final String? email;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Usuario $id' : partes.join(' ');
  }

  factory AsistenciaUsuario.fromJson(Map<String, dynamic> json) => AsistenciaUsuario(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        email: json['email'] as String?,
      );
}

/// Una página de asistencias con su paginación.
class AsistenciasPagina {
  const AsistenciasPagina({
    required this.asistencias,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Asistencia> asistencias;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory AsistenciasPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return AsistenciasPagina(
      asistencias: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Asistencia.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}
