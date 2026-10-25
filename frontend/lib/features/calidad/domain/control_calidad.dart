/// Control de calidad de una recolección.
///
/// Es un análisis de laboratorio: grasa, proteína, lactosa, densidad, pH, agua
/// añadida y temperatura. Solo hay **dos** veredictos, `pura` y `adulterada`, y
/// son el único campo que decide algo.
///
/// **Una recolección solo admite un control.** `recoleccionId` es único en la
/// base, así que un segundo análisis de la misma recogida se rechaza con un 400,
/// y al editar tampoco se puede mover un control a una recolección que ya tenga
/// uno. La pantalla lo dice en vez de dejar que el error llegue después.
class ControlCalidad {
  const ControlCalidad({
    required this.id,
    required this.recoleccionId,
    required this.usuarioId,
    required this.resultado,
    this.grasa,
    this.proteina,
    this.lactosa,
    this.densidad,
    this.temperatura,
    this.aguaAnadida,
    this.ph,
    this.recoleccion,
    this.usuario,
  });

  final int id;

  /// La recolección analizada. Única: no hay dos controles por recolección.
  final int recoleccionId;

  /// Quién firmó el análisis. El servidor no lo deduce de la sesión.
  final int usuarioId;

  /// Porcentaje de grasa.
  final double? grasa;

  /// Porcentaje de proteína.
  final double? proteina;

  /// Porcentaje de lactosa.
  final double? lactosa;

  final double? densidad;

  /// Temperatura a la que se midió.
  final double? temperatura;

  /// Agua añadida, si se detectó.
  final double? aguaAnadida;

  final double? ph;

  /// `pura` o `adulterada`. **Es el único campo obligatorio por decisión** y
  /// tiene valor por defecto `pura` en la base, a diferencia de `registradoEn`
  /// en Recolecciones, que obliga a elegir.
  final String resultado;

  final CalidadRecoleccion? recoleccion;
  final CalidadUsuario? usuario;

  /// `true` si el análisis salió adulterado.
  bool get esAdulterada => resultado == ControlCalidad.adulterada;

  /// `true` si el análisis salió puro.
  bool get esPura => resultado == ControlCalidad.pura;

  /// Qué se ha medido y qué no, en el orden en que se lee.
  ///
  /// Los siete campos admiten `null`, así que un control puede venir con uno solo
  /// —una sola temperatura— o con ninguno. Ensamblar la lista aquí y no en la
  /// pantalla evita que cada sitio se libre de las siete comprobaciones y
  /// que se le olvide una.
  Map<String, double?> get medidas => {
        'Grasa': grasa,
        'Proteína': proteina,
        'Lactosa': lactosa,
        'Densidad': densidad,
        'pH': ph,
        'Temp.': temperatura,
        'Agua añadida': aguaAnadida,
      };

  /// Solo las medidas que tienen valor, para la ficha resumida de la fila.
  List<MapEntry<String, double?>> get medidasInformativas =>
      medidas.entries.where((m) => m.value != null).toList();

  /// Cuántas de las siete medidas hay.
  int get cuantasMedidas => medidasInformativas.length;

  /// Un control sin ninguna medida no dice nada: es un veredicto sin pruebas.
  bool get tieneMedidas => cuantasMedidas > 0;

  /// Un número con coma decimal y sin ceros de más: `3.80` sale de la base,
  /// `3,8` se lee.
  static String formatea(double valor, {int decimales = 1}) {
    if (valor == valor.truncateToDouble()) {
      return valor.truncate().toString();
    }
    return valor.toStringAsFixed(decimales).replaceAll('.', ',');
  }

  factory ControlCalidad.fromJson(Map<String, dynamic> json) => ControlCalidad(
        id: json['id'] as int? ?? 0,
        recoleccionId: json['recoleccionId'] as int? ?? 0,
        usuarioId: json['usuarioId'] as int? ?? 0,
        // `as num?` y no `as double?`: la API puede mandar `3.8` como `3.8`
        // —double— pero también un entero si el valor fuera redondo, y un `int`
        // no es un `double` en Dart.
        grasa: (json['grasa'] as num?)?.toDouble(),
        proteina: (json['proteina'] as num?)?.toDouble(),
        lactosa: (json['lactosa'] as num?)?.toDouble(),
        densidad: (json['densidad'] as num?)?.toDouble(),
        temperatura: (json['temperatura'] as num?)?.toDouble(),
        aguaAnadida: (json['aguaAnadida'] as num?)?.toDouble(),
        ph: (json['ph'] as num?)?.toDouble(),
        resultado: json['resultado'] as String? ?? pura,
        recoleccion: json['recoleccion'] == null
            ? null
            : CalidadRecoleccion.fromJson(json['recoleccion'] as Map<String, dynamic>),
        usuario: json['usuario'] == null
            ? null
            : CalidadUsuario.fromJson(json['usuario'] as Map<String, dynamic>),
      );

  /// Los dos veredictos que admite el `ENUM` de la base.
  ///
  /// Constantes y no cadenas sueltas: aparecen en el modelo, en el formulario y
  /// en las pruebas, y `"pura"` escrita a mano en tres sitios diverge en cuanto
  /// una se escribe con mayúscula.
  static const String pura = 'pura';
  static const String adulterada = 'adulterada';

  /// Rango de pH que se considera normal en leche de vaca.
  ///
  /// `6,6` a `6,8` es el intervalo que usan las normativas de leche y el Codex, no
  /// una cifra inventada aquí. **Constante y no número suelto dentro de la regla**:
  /// si el laboratorio usa otro rango, se cambia en estos dos sitios una vez y no
  /// hay que ir a buscarlos dentro de una comparación.
  static const double phMinimo = 6.6;
  static const double phMaximo = 6.8;

  ControlCalidad copyWith({
    double? grasa,
    double? proteina,
    double? lactosa,
    double? densidad,
    double? temperatura,
    double? aguaAnadida,
    double? ph,
    String? resultado,
    int? recoleccionId,
    bool limpiarGrasa = false,
    bool limpiarProteina = false,
    bool limpiarLactosa = false,
    bool limpiarDensidad = false,
    bool limpiarTemperatura = false,
    bool limpiarAguaAnadida = false,
    bool limpiarPh = false,
  }) {
    return ControlCalidad(
      id: id,
      recoleccionId: recoleccionId ?? this.recoleccionId,
      usuarioId: usuarioId,
      resultado: resultado ?? this.resultado,
      // Los siete `limpiar` existen por lo mismo que en los otros módulos:
      // `null` es justamente el valor que significa "quítalo", y sin un flag no
      // se podría quitar nada.
      grasa: limpiarGrasa ? null : (grasa ?? this.grasa),
      proteina: limpiarProteina ? null : (proteina ?? this.proteina),
      lactosa: limpiarLactosa ? null : (lactosa ?? this.lactosa),
      densidad: limpiarDensidad ? null : (densidad ?? this.densidad),
      temperatura: limpiarTemperatura ? null : (temperatura ?? this.temperatura),
      aguaAnadida: limpiarAguaAnadida ? null : (aguaAnadida ?? this.aguaAnadida),
      ph: limpiarPh ? null : (ph ?? this.ph),
      recoleccion: recoleccion,
      usuario: usuario,
    );
  }
}

/// Qué veredicto propone [calculaResultado] para unas medidas.
///
/// Función suelta y no método: se puede probar sin montar un widget ni un
/// provider, y el formulario puede llamarla en cuanto cambia un campo sin tener
/// un `ControlCalidad` delante.
///
/// **Una medida sin medir no dice nada** y por eso no dispara la regla: sin `ph`
/// no hay por qué suponer que el pH está mal, y quedarse en `pura` porque nadie
/// midió sería inventarse un análisis.
String calculaResultado({double? aguaAnadida, double? ph}) {
  if (aguaAnadida != null && aguaAnadida > 0) {
    return ControlCalidad.adulterada;
  }

  if (ph != null && (ph < ControlCalidad.phMinimo || ph > ControlCalidad.phMaximo)) {
    return ControlCalidad.adulterada;
  }

  return ControlCalidad.pura;
}

/// Por qué [calculaResultado] dijo lo que dijo, para poder enseñarlo.
///
/// Sin esto la app pondría «adulterada» sin que nadie sepa si fue por el agua o
/// por el pH, y el laboratorio no tiene forma de saber qué medida mirar.
String motivoDe(String veredicto, {double? aguaAnadida, double? ph}) {
  if (veredicto != ControlCalidad.adulterada) {
    return 'El agua añadida es cero y el pH está en rango.';
  }

  if (aguaAnadida != null && aguaAnadida > 0) {
    return 'Le añadieron agua.';
  }

  return 'El pH quedó fuera de ${ControlCalidad.phMinimo.toStringAsFixed(1)}–'
      '${ControlCalidad.phMaximo.toStringAsFixed(1)}.';
}

/// Lo de la recolección que hace falta para reconocerla en una fila.
///
/// El backend manda el id, la fecha y los litros, pero **no el nombre del
/// proveedor**: para eso hay que ir a `/recolecciones/{id}`. Por eso
/// [proveedorId] viene y [nombreProveedor] no, y por eso la pantalla enseña la
/// fecha y los litros, que sí están.
class CalidadRecoleccion {
  const CalidadRecoleccion({
    required this.id,
    required this.proveedorId,
    required this.fecha,
    this.cantidad,
  });

  final int id;
  final int proveedorId;
  final String fecha;
  final double? cantidad;

  /// Los litros con coma, o `null` si no vinieron.
  String? get litrosLegibles {
    if (cantidad == null) {
      return null;
    }
    return '${ControlCalidad.formatea(cantidad!)} L';
  }

  factory CalidadRecoleccion.fromJson(Map<String, dynamic> json) => CalidadRecoleccion(
        id: json['id'] as int? ?? 0,
        proveedorId: json['proveedorId'] as int? ?? 0,
        fecha: json['fecha'] as String? ?? '',
        cantidad: (json['cantidad'] as num?)?.toDouble(),
      );
}

class CalidadUsuario {
  const CalidadUsuario({required this.id, required this.nombre, this.apellido, this.email});

  final int id;
  final String nombre;
  final String? apellido;
  final String? email;

  String get nombreCompleto {
    final partes = [nombre, apellido].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Laboratorio $id' : partes.join(' ');
  }

  factory CalidadUsuario.fromJson(Map<String, dynamic> json) => CalidadUsuario(
        id: json['id'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        apellido: json['apellido'] as String?,
        email: json['email'] as String?,
      );
}

/// Una página de controles con su paginación.
class ControlesPagina {
  const ControlesPagina({
    required this.controles,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.tieneAnterior,
    required this.tieneSiguiente,
  });

  final List<ControlCalidad> controles;
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool tieneAnterior;
  final bool tieneSiguiente;

  factory ControlesPagina.fromJson(Map<String, dynamic> json) {
    final datos = (json['paginacion'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ControlesPagina(
      controles: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ControlCalidad.fromJson)
          .toList(),
      pagina: datos['pagina'] as int? ?? 1,
      totalPaginas: datos['totalPaginas'] as int? ?? 0,
      total: datos['total'] as int? ?? 0,
      tieneAnterior: datos['tieneAnterior'] as bool? ?? false,
      tieneSiguiente: datos['tieneSiguiente'] as bool? ?? false,
    );
  }
}
