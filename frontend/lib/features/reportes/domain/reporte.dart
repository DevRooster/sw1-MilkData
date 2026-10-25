/// Una fila del reporte de contraste: lo recogido en el campo contra lo que
/// entró en la planta.
///
/// La diferencia es lo que se busca: si en el campo se recogieron 52 litros y en
/// la planta solo entraron 25, esos 27 litros se quedaron por el camino. **Un
/// porcentaje negativo no es un error de cálculo**, es el resultado.
class FilaContraste {
  const FilaContraste({
    required this.proveedorId,
    required this.fecha,
    required this.cantidadCampo,
    required this.cantidadPlanta,
    required this.diferencia,
    this.porcentajeDiferencia,
  });

  final int proveedorId;

  /// El día, `YYYY-MM-DD`.
  final String fecha;

  /// Litros anotados como recogidos en el campo.
  final double cantidadCampo;

  /// Litros anotados como entrados en la planta.
  final double cantidadPlanta;

  /// `cantidadCampo - cantidadPlanta`. Positiva: faltó leche; negativa: entró de
  /// más. Cero es lo normal.
  final double diferencia;

  /// La diferencia en porcentaje sobre lo recogido en el campo.
  ///
  /// **Es `null` cuando no se recogió nada en el campo**, aunque la diferencia
  /// sea enorme: dividir entre cero daría `Infinity` o `NaN`, y el servidor
  /// devuelve `null` en ese caso en vez de un número que no significa nada.
  final double? porcentajeDiferencia;

  /// `true` cuando falta leche entre el campo y la planta.
  bool get hayFaltante => diferencia > 0;

  /// 	rue cuando entró más de lo que se recogió, que es lo que hace sospechar de
  /// adulteración o de un robo.
  bool get hayExceso => diferencia < 0;

  String get fechaLegible {
    if (fecha.length < 10) {
      return fecha;
    }
    return '${fecha.substring(8, 10)}/${fecha.substring(5, 7)}/${fecha.substring(0, 4)}';
  }

  /// El porcentaje con su signo y un decimal.
  ///
  /// La API devuelve `52.501000000000005`; en pantalla tiene que ser `52,5`.
  /// `null` sale como guion y no como cero: no hay porcentaje, no un 0 %.
  String? get porcentajeLegible {
    final valor = porcentajeDiferencia;
    if (valor == null) {
      return null;
    }
    return '${valor.toStringAsFixed(1).replaceAll('.', ',')} %';
  }

  /// Los litros con coma y sin decimales de más.
  String get litrosLegibles => '${_formatea(cantidadCampo)} → ${_formatea(cantidadPlanta)} L';

  /// La diferencia con signo, que es la cifra que importa.
  String get diferenciaLegible {
    final signo = diferencia > 0 ? '+' : '';
    return '$signo${_formatea(diferencia)} L';
  }

  static String _formatea(double valor) {
    if (valor == valor.truncateToDouble()) {
      return valor.truncate().toString();
    }
    return valor.toStringAsFixed(1).replaceAll('.', ',');
  }

  factory FilaContraste.fromJson(Map<String, dynamic> json) => FilaContraste(
        proveedorId: json['proveedorId'] as int? ?? 0,
        fecha: json['fecha'] as String? ?? '',
        cantidadCampo: (json['cantidadCampo'] as num?)?.toDouble() ?? 0,
        cantidadPlanta: (json['cantidadPlanta'] as num?)?.toDouble() ?? 0,
        diferencia: (json['diferencia'] as num?)?.toDouble() ?? 0,
        porcentajeDiferencia: (json['porcentajeDiferencia'] as num?)?.toDouble(),
      );
}

/// Una fila del reporte de calidad: los promedios de las siete medidas.
///
/// **Una sola fila, sin lista**: el reporte resume toda la planta —o un
/// proveedor—, no pagina. Por eso aquí no hay `totalPaginas` ni nada parecido.
class FilaCalidad {
  const FilaCalidad({required this.proveedorId, required this.muestras, required this.promedios});

  /// El proveedor, o `null` cuando el reporte es de toda la planta.
  final int? proveedorId;

  /// Cuántos controles de calidad se promediaron.
  ///
  /// **Cero no es lo mismo que cero de calidad**: no es que la leche esté mal,
  /// es que **nadie ha analizado nada**. La pantalla lo dice, porque un `0,00 %`
  /// de grasa se lee como un análisis y no como su ausencia.
  final int muestras;

  final Map<String, double?> promedios;

  bool get sinAnalisis => muestras == 0;

  /// Solo las medidas con valor, en el orden en que se leen.
  List<MapEntry<String, double?>> get promediosInformativos =>
      promedios.entries.where((p) => p.value != null).toList();

  String? get nombreProveedor =>
      proveedorId == null ? null : 'Proveedor #$proveedorId';

  factory FilaCalidad.fromJson(Map<String, dynamic> json) {
    final promedios = (json['promedios'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return FilaCalidad(
      proveedorId: json['proveedorId'] as int?,
      muestras: json['muestras'] as int? ?? 0,
      promedios: {
        'Grasa': (promedios['grasa'] as num?)?.toDouble(),
        'Proteína': (promedios['proteina'] as num?)?.toDouble(),
        'Lactosa': (promedios['lactosa'] as num?)?.toDouble(),
        'Densidad': (promedios['densidad'] as num?)?.toDouble(),
        'pH': (promedios['ph'] as num?)?.toDouble(),
        'Temp.': (promedios['temperatura'] as num?)?.toDouble(),
        'Agua añadida': (promedios['aguaAnadida'] as num?)?.toDouble(),
      },
    );
  }
}

/// Un número del reporte con su formato ya hecho.
///
/// Va en el dominio y no en la pantalla porque los cuatro reportes enseñan lo
/// mismo de distintas maneras, y cada pantalla reescribir el `toStringAsFixed`
/// es donde se cuelan los ceros de más y las comas perdidas.
String formateaMedida(double? valor) {
  if (valor == null) {
    return '—';
  }
  if (valor == valor.truncateToDouble()) {
    return valor.truncate().toString();
  }
  return valor.toStringAsFixed(2).replaceAll('.', ',');
}

/// Lo que envuelve cualquiera de los cuatro reportes: un nombre, las filas y la
/// planta a la que pertenecen.
class Reporte<T> {
  const Reporte({required this.nombre, required this.filas, required this.plantaId});

  /// El identificador del reporte: `contraste`, `calidad`, `calidadProveedor`.
  ///
  /// Viene de la API y sirve de etiqueta en la pantalla.
  final String nombre;

  final List<T> filas;

  /// Siempre la planta de la sesión, nunca una de la petición. El aislamiento lo
  /// garantiza el servidor; aquí solo se lee.
  final int plantaId;

  bool get vacio => filas.isEmpty;

  factory Reporte.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fila) {
    return Reporte<T>(
      nombre: json['name'] as String? ?? '',
      filas: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(fila)
          .toList(),
      plantaId: json['plantaId'] as int? ?? 0,
    );
  }
}
