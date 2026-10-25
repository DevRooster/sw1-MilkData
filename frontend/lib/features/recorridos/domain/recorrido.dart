/// Los cuatro estados que puede tener un recorrido.
///
/// Es un `ENUM` en la base y el servidor solo admite transiciones concretas.
/// [EstadoRecorrido] las recoge aquí para que la pantalla no tenga que
/// compar cadenas sueltas en seis sitios distintos.
enum EstadoRecorrido {
  planificado('PLANIFICADO', 'Planificado'),
  enRuta('EN_RUTA', 'En ruta'),
  finalizado('FINALIZADO', 'Finalizado'),
  cancelado('CANCELADO', 'Cancelado');

  const EstadoRecorrido(this.valor, this.etiqueta);

  /// Lo que viaja al servidor y lo que vuelve de él.
  final String valor;

  /// Cómo se lo enseñamos a la persona.
  final String etiqueta;

  static EstadoRecorrido desde(String? valor) {
    return EstadoRecorrido.values.firstWhere(
      (e) => e.valor == valor,
      // Un estado que el servidor invente no debe romper la pantalla: se
      // teaches como PLANIFICADO, que es el estado inicial, y la app sigue
      // funcionando en vez de dejar una lista en blanco.
      orElse: () => EstadoRecorrido.planificado,
    );
  }

  /// Lo que le pasa a una parada que no se atendió al finalizar.
  static const String omitida = 'OMITIDA';

  /// Estado de una parada recién sellada.
  static const String pendiente = 'PENDIENTE';

  /// Estado de una parada atendida.
  static const String atendida = 'ATENDIDA';
}

/// Un recorrido: una ruta, una unidad, un acopiador y un día.
///
/// **Las paradas se sellan al iniciar, no al crear.** Al crear sale con cero, y
/// `iniciar` copia las de la ruta en ese momento. Por eso el detalle de un
/// recorrido planificado y el de uno en ruta no tienen la misma información, y
/// por eso la pantalla no debe prometer paradas antes de arrancar.
class Recorrido {
  const Recorrido({
    required this.id,
    required this.rutaId,
    required this.unidadId,
    required this.acopiadorId,
    required this.estado,
    required this.fecha,
    this.ruta,
    this.unidad,
    this.acopiador,
    this.ayudanteNombre,
    this.ayudanteApellido,
    this.ayudanteDni,
    this.ayudanteCelular,
    this.horaInicio,
    this.horaFin,
    this.horaInicioReal,
    this.horaFinReal,
    this.fechaInicio,
    this.fechaFin,
    this.kilometrajeInicio,
    this.kilometrajeFin,
    this.observaciones,
    this.paradas = const <ParadaRecorrido>[],
  });

  final int id;
  final int rutaId;
  final int unidadId;

  /// Quién lleva el recorrido. Lo pone el servidor tomando la sesión si el
  /// cuerpo no lo dice, así que siempre hay uno.
  final int acopiadorId;

  final EstadoRecorrido estado;

  /// Día previsto. Es `DATEONLY`: un día, sin hora.
  final String fecha;

  /// Horario **previsto**. El real va en `horaInicioReal` / `horaFinReal`, y lo
  /// pone el servidor al iniciar y al finalizar. Confundirlos es fácil porque se
  /// llaman parecido, y por eso van con nombres distintos y sin abreviaturas.
  final String? horaInicio;
  final String? horaFin;

  final String? horaInicioReal;
  final String? horaFinReal;
  final String? fechaInicio;
  final String? fechaFin;

  final double? kilometrajeInicio;
  final double? kilometrajeFin;

  final String? observaciones;

  final String? ayudanteNombre;
  final String? ayudanteApellido;
  final String? ayudanteDni;
  final String? ayudanteCelular;

  final RutaRecorrido? ruta;
  final UnidadRecorrido? unidad;
  final AcopiadorRecorrido? acopiador;

  /// Paradas selladas. Vacías mientras el recorrido está planificado.
  final List<ParadaRecorrido> paradas;

  /// El ayudante en una línea, o `null` si el recorrido va solo.
  ///
  /// Con usuario interno el nombre sale de la cuenta; sin él, de los campos
  /// sueltos. Los dos casos llegan ya resueltos desde aquí.
  String? get ayudante {
    final partes = [ayudanteNombre, ayudanteApellido]
        .where((p) => p != null && p.isNotEmpty)
        .toList();

    if (partes.isEmpty) {
      return null;
    }
    return partes.join(' ');
  }

  /// `true` si este recorrido ya tiene horario previsto.
  String get horarioPrevisto {    final desde = horaCorta(horaInicio);
    final hasta = horaCorta(horaFin);

    if (desde == null && hasta == null) {
      return 'Sin horario';
    }
    if (desde == null) {
      return 'Hasta las $hasta';
    }
    if (hasta == null) {
      return 'Desde las $desde';
    }
    return '$desde – $hasta';
  }

  /// Qué se puede hacer con este recorrido ahora mismo.
  ///
  /// Se calcula del estado y no de los permisos porque es el servidor quien
  /// rechaza: un botón que se ofrezca y dé 400 es peor que no ofrecerlo. El
  /// permiso de escritura se comprueba aparte, en la pantalla.
  bool get puedeIniciar => estado == EstadoRecorrido.planificado;

  bool get puedeFinalizar => estado == EstadoRecorrido.enRuta;

  /// Cancelar vale desde cualquier estado menos desde finalizado: un recorrido
  /// acabado no se puede deshacer.
  bool get puedeCancelar => estado != EstadoRecorrido.finalizado;

  /// Marcar paradas solo tiene sentido con el recorrido en marcha. Antes no hay
  /// paradas selladas, y después ya no se puede corregir.
  bool get puedeAtenderParadas => estado == EstadoRecorrido.enRuta;

  /// Cómo se lee la fecha. `2026-10-13` no lo lee nadie de un vistazo.
  String get fechaLegible {
    final partes = fecha.split('-');
    if (partes.length != 3) {
      return fecha;
    }
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  /// Copia con algunos campos cambiados.
  ///
  /// Se usa al aplicar una transición: `iniciar` y `finalizar` devuelven el
  /// recorrido entero con el estado nuevo, las paradas selladas o las pendientes
  /// ya omitidas y la hora real puesta. Reconstruirlo a mano en la pantalla
  /// significaría recordar todos esos campos, y el primero que se olvide
  /// perdería datos silenciosamente.
  Recorrido copyWith({
    EstadoRecorrido? estado,
    String? horaInicioReal,
    String? horaFinReal,
    String? fechaInicio,
    String? fechaFin,
    String? observaciones,
    List<ParadaRecorrido>? paradas,
  }) {
    return Recorrido(
      id: id,
      rutaId: rutaId,
      unidadId: unidadId,
      acopiadorId: acopiadorId,
      estado: estado ?? this.estado,
      fecha: fecha,
      ruta: ruta,
      unidad: unidad,
      acopiador: acopiador,
      ayudanteNombre: ayudanteNombre,
      ayudanteApellido: ayudanteApellido,
      ayudanteDni: ayudanteDni,
      ayudanteCelular: ayudanteCelular,
      horaInicio: horaInicio,
      horaFin: horaFin,
      horaInicioReal: horaInicioReal ?? this.horaInicioReal,
      horaFinReal: horaFinReal ?? this.horaFinReal,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      kilometrajeInicio: kilometrajeInicio,
      kilometrajeFin: kilometrajeFin,
      observaciones: observaciones ?? this.observaciones,
      paradas: paradas ?? this.paradas,
    );
  }

  factory Recorrido.fromJson(Map<String, dynamic> json) => Recorrido(
        id: json['id'] as int? ?? 0,
        rutaId: json['rutaId'] as int? ?? 0,
        unidadId: json['unidadId'] as int? ?? 0,
        acopiadorId: json['acopiadorId'] as int? ?? 0,
        estado: EstadoRecorrido.desde(json['estado'] as String?),
        fecha: json['fecha'] as String? ?? '',
        ruta: json['ruta'] == null
            ? null
            : RutaRecorrido.fromJson(json['ruta'] as Map<String, dynamic>),
        unidad: json['unidad'] == null
            ? null
            : UnidadRecorrido.fromJson(json['unidad'] as Map<String, dynamic>),
        acopiador: json['acopiador'] == null
            ? null
            : AcopiadorRecorrido.fromJson(json['acopiador'] as Map<String, dynamic>),
        ayudanteNombre: json['ayudanteNombre'] as String?,
        ayudanteApellido: json['ayudanteApellido'] as String?,
        ayudanteDni: json['ayudanteDni'] as String?,
        ayudanteCelular: json['ayudanteCelular'] as String?,
        horaInicio: json['horaInicio'] as String?,
        horaFin: json['horaFin'] as String?,
        horaInicioReal: json['horaInicioReal'] as String?,
        horaFinReal: json['horaFinReal'] as String?,
        fechaInicio: json['fechaInicio'] as String?,
        fechaFin: json['fechaFin'] as String?,
        // `as num?` y no `as double?`: la API puede mandar un entero, y un
        // `int` no es un `double` en Dart.
        kilometrajeInicio: (json['kilometrajeInicio'] as num?)?.toDouble(),
        kilometrajeFin: (json['kilometrajeFin'] as num?)?.toDouble(),
        observaciones: json['observaciones'] as String?,
        paradas: (json['paradas'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ParadaRecorrido.fromJson)
            .toList(),
      );
}

/// Una parada de un recorrido.
///
/// Nace `PENDIENTE` al sellar las paradas de la ruta, pasa a `ATENDIDA` cuando
/// se atiende y a `OMITIDA` cuando el recorrido se finaliza con ella pendiente.
class ParadaRecorrido {
  const ParadaRecorrido({
    required this.id,
    required this.orden,
    required this.estado,
    this.horaLlegada,
    this.kilometraje,
    this.observaciones,
    this.proveedor,
    this.rutaParadaId,
  });

  final int id;

  /// Posición en el recorrido, heredada del orden de la ruta.
  final int orden;

  /// `PENDIENTE`, `ATENDIDA` u `OMITIDA`.
  final String estado;

  final String? horaLlegada;
  final double? kilometraje;
  final String? observaciones;

  /// El proveedor que se visita aquí.
  final ProveedorParada? proveedor;

  /// El id del proveedor, venga dentro de `proveedor` o no.
  ///
  /// Es un getter y no un campo porque el proveedor viene anidado: leer
  /// `parada.proveedorId` sin mirar dentro obligaba a repetir el `?.` en cada
  /// sitio, y en uno de ellos se olvidó y el botón de atender salía con "null"
  /// en lugar de con un número.
  int? get proveedorId => proveedor?.id;

  /// La parada de la ruta de la que copió esta.
  final int? rutaParadaId;

  bool get atendida => estado == EstadoRecorrido.atendida;
  bool get pendiente => estado == EstadoRecorrido.pendiente;
  bool get omitida => estado == EstadoRecorrido.omitida;

  factory ParadaRecorrido.fromJson(Map<String, dynamic> json) => ParadaRecorrido(
        id: json['id'] as int? ?? 0,
        orden: json['orden'] as int? ?? 0,
        estado: json['estado'] as String? ?? EstadoRecorrido.pendiente,
        horaLlegada: json['horaLlegada'] as String?,
        kilometraje: (json['kilometraje'] as num?)?.toDouble(),
        observaciones: json['observaciones'] as String?,
        rutaParadaId: json['rutaParadaId'] as int?,
        proveedor: json['proveedor'] == null
            ? null
            : ProveedorParada.fromJson(json['proveedor'] as Map<String, dynamic>),
      );
}

/// Datos mínimos de la ruta, la unidad, el acopiador y el proveedor.
///
/// Cada uno trae lo justo para reconocerlo en una lista. La ficha completa es
/// cosa de los módulos de Rutas, Unidades, Usuarios y Proveedores, y traerla aquí
/// sería copiar cuatro dominios en uno.
class RutaRecorrido {
  const RutaRecorrido({required this.id, required this.nombre, this.codigo});

  final int id;
  final String nombre;
  final String? codigo;

  factory RutaRecorrido.fromJson(Map<String, dynamic> json) => RutaRecorrido(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        codigo: json['codigo'] as String?,
      );
}

class UnidadRecorrido {
  const UnidadRecorrido({required this.id, required this.nombre, this.tipo});

  final int id;
  final String nombre;
  final String? tipo;

  factory UnidadRecorrido.fromJson(Map<String, dynamic> json) => UnidadRecorrido(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String?,
      );
}

class AcopiadorRecorrido {
  const AcopiadorRecorrido({required this.id, required this.nombre, this.apellido});

  final int id;
  final String nombre;
  final String? apellido;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Acopiador $id' : partes.join(' ');
  }

  factory AcopiadorRecorrido.fromJson(Map<String, dynamic> json) => AcopiadorRecorrido(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
      );
}

class ProveedorParada {
  const ProveedorParada({
    required this.id,
    required this.nombre,
    this.apellido,
    this.dni,
    this.codigo,
  });

  final int id;
  final String nombre;
  final String? apellido;
  final String? dni;
  final String? codigo;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Proveedor $id' : partes.join(' ');
  }

  factory ProveedorParada.fromJson(Map<String, dynamic> json) => ProveedorParada(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        dni: json['dni'] as String?,
        codigo: json['codigo'] as String?,
      );
}

/// Una página de recorridos con su estado de paginación.
class RecorridosPagina {
  const RecorridosPagina({
    required this.recorridos,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<Recorrido> recorridos;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory RecorridosPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return RecorridosPagina(
      recorridos: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Recorrido.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}

/// `06:00:00` pasa a `06:00`, que es como se lee una hora.
///
/// `horaInicio` es lo previsto y `horaInicioReal` lo que pasó. Se recortan los
/// dos igual porque se enseñan uno al lado del otro, y si uno saliera entero y
/// el otro no, parecería que uno viene del servidor y el otro no.
String? horaCorta(String? valor) {
  if (valor == null || valor.isEmpty) {
    return null;
  }
  return valor.length >= 5 ? valor.substring(0, 5) : valor;
}
