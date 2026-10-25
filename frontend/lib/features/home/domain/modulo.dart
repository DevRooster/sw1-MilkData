import 'package:flutter/cupertino.dart';

import '../../auth/domain/permisos.dart';
import '../../auth/presentation/usuarios_page.dart';
import '../../asistencias/presentation/lista_asistencias_page.dart';
import '../../calidad/presentation/lista_calidad_page.dart';
import '../../eventos/presentation/lista_eventos_page.dart';
import '../../notificaciones/presentation/lista_notificaciones_page.dart';
import '../../productos/presentation/lista_productos_page.dart';
import '../../proveedores/presentation/lista_proveedores_page.dart';
import '../../recolecciones/presentation/lista_recolecciones_page.dart';
import '../../recorridos/presentation/lista_recorridos_page.dart';
import '../../plantas/presentation/lista_plantas_page.dart';
import '../../reportes/presentation/lista_reportes_page.dart';
import '../../rutas/presentation/lista_rutas_page.dart';
import '../../unidades/presentation/lista_unidades_page.dart';
import '../../zonas/presentation/lista_zonas_page.dart';

/// Un módulo de la aplicación, tal como se ofrece en el lanzador de Inicio.
///
/// El `recurso` es lo único que decide si el módulo se enseña, y tiene que
/// coincidir exactamente con la clave que devuelve `GET /auth/permisos`. Si
/// aquí se escribiera `unidades` y el servidor dijera `unidad`, el módulo no
/// aparecería nunca y no habría ningún aviso: simplemente faltarían.
class Modulo {
  const Modulo({
    required this.recurso,
    required this.titulo,
    required this.resumen,
    required this.icono,
    required this.destino,
  });

  /// Clave del recurso en la matriz de permisos del servidor.
  final String recurso;

  /// Cómo se lo enseña a la persona.
  final String titulo;

  /// Una línea de qué se hace aquí. Es lo que se lee antes de abrir.
  final String resumen;

  final IconData icono;

  /// La pantalla que se abre al tocar la tarjeta.
  final Widget Function() destino;
}

/// Los módulos que la aplicación ofrece.
///
/// Va a crecer con cada módulo nuevo, y es el único sitio que hay que tocar para
/// que algo aparezca en el lanzador. El orden es el que se quiere ver: primero
/// los que se usan a diario, al final la configuración.
///
/// No se comprueba aquí si el usuario puede: eso lo hace `modulosPermitidos`,
/// para que la lista completa siga siendo la fuente de verdad de qué existe.
///
/// Es `final` y no `const` porque cada entrada lleva un cierre que construye una
/// pantalla, y eso no es una expresión constante.
final List<Modulo> catalogoModulos = <Modulo>[
  // Módulo 3 del ROADMAP.
  Modulo(
    recurso: 'unidades',
    titulo: 'Unidades',
    resumen: 'Camiones y furgones, con su capacidad y su chófer',
    icono: CupertinoIcons.cube_box,
    destino: () => const UnidadesPage(),
  ),
  Modulo(
    recurso: 'productos',
    titulo: 'Productos',
    resumen: 'Qué se vende, a qué precio y con qué foto',
    icono: CupertinoIcons.cube_box_fill,
    destino: () => const ProductosPage(),
  ),
  Modulo(
    recurso: 'rutas',
    titulo: 'Rutas',
    resumen: 'Recorridos de recogida, con sus horarios y paradas',
    icono: CupertinoIcons.map_fill,
    destino: () => const RutasPage(),
  ),
  Modulo(
    recurso: 'zonas',
    titulo: 'Zonas',
    resumen: 'Territorios de recogida, con su ruta y su unidad',
    icono: CupertinoIcons.map_pin_ellipse,
    destino: () => const ZonasPage(),
  ),
  // Módulo 7. Abre la puerta a las paradas de Rutas y a Recolecciones.
  Modulo(
    recurso: 'proveedores',
    titulo: 'Proveedores',
    resumen: 'Los productores de la planta, con su DNI y su zona',
    icono: CupertinoIcons.person_2,
    destino: () => const ProveedoresPage(),
  ),
  // Módulo 8. El primero con una máquina de estados de verdad: planificado,
  // en ruta, finalizado y cancelado.
  Modulo(
    recurso: 'recorridos',
    titulo: 'Recorridos',
    resumen: 'Salidas de recogida, con sus paradas y su estado',
    icono: CupertinoIcons.car_detailed,
    destino: () => const RecorridosPage(),
  ),
  // Módulo 9. Cierra la cadena: un recorrido tiene paradas, una parada produce
  // una recolección.
  Modulo(
    recurso: 'recolecciones',
    titulo: 'Recolecciones',
    resumen: 'Los litros recogidos, y de dónde se anotaron',
    icono: CupertinoIcons.drop_fill,
    destino: () => const RecoleccionesPage(),
  ),
  // Módulo 10. El único con una restricción que no se ve: una recolección solo
  // admite un análisis, y eso hay que ofrecerlo filtrado en el desplegable.
  Modulo(
    recurso: 'calidad',
    titulo: 'Calidad',
    resumen: 'Los análisis de laboratorio y su veredicto',
    icono: CupertinoIcons.checkmark_seal,
    destino: () => const CalidadPage(),
  ),
  // Módulo 11. El único con dos formas de guardar de verdad: un aviso puede
  // quedar solo guardado (borrador) o mandarse de verdad por otro endpoint.
  Modulo(
    recurso: 'notificaciones',
    titulo: 'Notificaciones',
    resumen: 'Los avisos a los proveedores, y si ya salieron',
    icono: CupertinoIcons.bell,
    destino: () => const NotificacionesPage(),
  ),
  // Módulo 12. El único cuyo campo principal es texto libre: `evento` es un
  // VARCHAR(150), así que no hay desplegable posible y sí una regla de longitud.
  Modulo(
    recurso: 'asistencias',
    titulo: 'Asistencias',
    resumen: 'Quién asistió a qué, y si se escaneó o se anotó',
    icono: CupertinoIcons.checkmark_square,
    destino: () => const AsistenciasPage(),
  ),
  // Eventos van **antes** que Asistencias: sin un evento al que apuntarse, el
  // catálogo de asistencias es una lista de texto libre que nadie puede filtrar.
  Modulo(
    recurso: 'asistencias',
    titulo: 'Eventos',
    resumen: 'Capacitaciones y reuniones a las que se puede asistir',
    icono: CupertinoIcons.calendar_badge_plus,
    destino: () => const EventosPage(),
  ),
  Modulo(
    recurso: 'usuarios',
    titulo: 'Usuarios',
    resumen: 'Altas, roles y cuentas de la planta',
    icono: CupertinoIcons.person_2_fill,
    destino: () => const UsuariosPage(),
  ),
  // Plantas. Lo ve también el admin, que solo puede leer: el botón de alta se
  // esconde sin `plantas: write` y el servidor rechaza el alta igual. Un módulo
  // superadmin en exclusiva habría dejado al admin sin poder ni mirar por
  // dónde trabaja.
  Modulo(
    recurso: 'plantas',
    titulo: 'Plantas',
    resumen: 'Las sedes de la lechera y sus códigos',
    icono: CupertinoIcons.building_2_fill,
    destino: () => const PlantasPage(),
  ),
  // Módulo 13. Solo lectura y **todo bajo el mismo permiso**, `reportes`: una
  // pantalla que mezclase módulos con permisos distintos devolvería "no se ve"
  // sin decir cuál, y eso no se puede diagnosticar.
  Modulo(
    recurso: 'reportes',
    titulo: 'Reportes',
    resumen: 'Contraste de campo contra planta, y promedios de calidad',
    icono: CupertinoIcons.chart_bar_alt_fill,
    destino: () => const ReportesPage(),
  ),
];

/// Los módulos que este token puede abrir.
///
/// Filtra con `Permisos.puede`, que es el mismo criterio que aplica
/// `authorizeMiddleware`: si el módulo no sale aquí, la API lo rechazaría con
/// 403. Por eso tocar un módulo de la lista nunca acaba en un error de
/// permisos: no deja llegar hasta él.
List<Modulo> modulosPermitidos(Permisos permisos) {
  return catalogoModulos.where((m) => permisos.puede(m.recurso)).toList();
}