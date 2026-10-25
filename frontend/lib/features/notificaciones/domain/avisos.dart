import 'notificacion.dart';

/// Un canal de Android: lo que el usuario silencia o silencia no.
///
/// Hay **uno por tipo de aviso**, y no uno único, porque la utilidad está
/// justamente en poder apagarlos por separado: a quien le interesan las reuniones
/// le da igual que suene una cada semana, pero un aviso de adulteración tiene
/// que llegar siempre. Con un solo canal habría que elegir entre tapar al que
/// necesita enterarse o despertar al que no.
class Canal {
  const Canal({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.importante,
  });

  final String id;

  /// Lo que se ve en los ajustes del móvil.
  final String nombre;

  final String descripcion;

  /// Si el aviso interrumpe: vibre y suena fuerte.
  ///
  /// Solo `adulteracion` lo es, y no por capricho: es el único de los tres
  /// detrás del cual hay leche que puede no entrar en la planta.
  final bool importante;

  /// El canal de un tipo de aviso, con un canal propio para cada uno.
  static Canal deTipo(String tipo) {
    switch (tipo) {
      case Notificacion.adulteracion:
        return const Canal(
          id: 'adulteracion',
          nombre: 'Adulteración',
          descripcion: 'Leche que no debe entrar en la planta.',
          importante: true,
        );
      case Notificacion.reunion:
        return const Canal(
          id: 'reunion',
          nombre: 'Reuniones',
          descripcion: 'Avisos de reuniones y convocatorias.',
          importante: false,
        );
      default:
        return const Canal(
          id: 'capacitacion',
          nombre: 'Capacitaciones',
          descripcion: 'Avisos de capacitación y formación.',
          importante: false,
        );
    }
  }

  /// Los tres canales, para crearlos todos de golpe al arrancar.
  static List<Canal> todos() =>
      Notificacion.tipos.map(deTipo).toList(growable: false);
}

/// Cuántos avisos se avisan de una vez.
///
/// Tope, no preferencia: alguien que abre la app después de una semana sin
/// mirar no quiere cuarenta notificaciones del móvil, quiere enterarse de que hay
/// cuarenta. Los que se quedan fuera ya están en la lista y no se pierden.
const int maximoDeAvisos = 5;

/// Qué avisos hay que avisar, y hasta dónde queda la marca.
///
/// Función pura a propósito: decidir qué es "nuevo" no debería depender de que
/// detrás haya un plugin de notificaciones, porque esa parte sí se puede probar
/// sin móvil y es la que decide si el usuario recibe tres avisos razonables o
/// cuarenta.
///
/// - Solo avisa de los que están **sin leer**: un aviso que ya se leyó no necesita
///   salir en la barra del sistema.
/// - Solo de los **más nuevos que la marca**: es lo que evita repetir en cada
///   recarga. Un filtro de la lista, o volver a abrir el módulo, no deben volver
///   a avisar de lo mismo.
/// - La marca avanza siempre al **id mayor de la lista entera**, no solo al de los
///   avisados. Si no, los que se saltaron por el tope se quedarían pidiendo aviso
///   para siempre.
({List<Notificacion> nuevos, int marca}) calculaNuevos(
  List<Notificacion> avisos, {
  required int ultimaMarcada,
  required bool esPrimeraVez,
  int maximo = maximoDeAvisos,
}) {
  if (avisos.isEmpty) {
    return (nuevos: const <Notificacion>[], marca: ultimaMarcada);
  }

  // La marca avanza con la lista entera, se avise o no. Va primero a propósito:
  // todo lo que viene detrás decide sobre el `maximo`.
  final mayor = avisos.map((a) => a.id).reduce((a, b) => a > b ? a : b);
  final marca = mayor > ultimaMarcada ? mayor : ultimaMarcada;

  // **La primera vez no se avisa de nada.** Sin una marca guardada, todo parece
  // nuevo, y al instalar la app el móvil recibiría de golpe todos los avisos
  // históricos. La primera carga solo deja constancia de por dónde se empieza.
  if (esPrimeraVez) {
    return (nuevos: const <Notificacion>[], marca: marca);
  }

  final sinLeer = avisos
      .where((a) => a.id > ultimaMarcada && !a.leida)
      .toList()
    // De más nuevo a más viejo: el último que se ve es el más reciente.
    ..sort((a, b) => b.id.compareTo(a.id));

  return (nuevos: sinLeer.take(maximo).toList(), marca: marca);
}