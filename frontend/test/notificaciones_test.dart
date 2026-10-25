// Pruebas del módulo Notificaciones.
//
// Lo que distingue este módulo de los demás son **dos caminos de guardado que no
// son el mismo con un interruptor**: guardar deja un borrador y enviar llama a
// otro endpoint que además pone la fecha. Y hay un estado imposible que el
// servidor permite y la app tiene que saber manejar.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/notificaciones/domain/notificacion.dart';
import 'package:milkdata_app/features/notificaciones/presentation/lista_notificaciones_page.dart';
import 'package:milkdata_app/features/notificaciones/presentation/providers/notificaciones_controller.dart';
import 'package:milkdata_app/features/proveedores/presentation/providers/proveedores_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_notificacion_api.dart';
import 'helpers/fake_proveedor_api.dart';
import 'helpers/fake_token_storage.dart';

/// Monta la app entera con los dobles.
Widget montar({
  FakeNotificacionApi? notificaciones,
  Permisos? permisos,
  List<Notificacion> avisos = const <Notificacion>[],
}) {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = permisos ?? _todoPermitido();

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      notificacionApiProvider.overrideWithValue(
        notificaciones ?? FakeNotificacionApi(notificaciones: avisos),
      ),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de avisos, con su propio contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeNotificacionApi api) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      notificacionApiProvider.overrideWithValue(api),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: NotificacionesPage()),
    ),
  );

  return contenedor;
}

Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'notificaciones': ['read', 'write'],
        'proveedores': ['read', 'write'],
        'recorridos': ['read'],
        'recolecciones': ['read'],
      },
    );

Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Abre un módulo del lanzador, bajando hasta encontrarlo.
///
/// El lanzador es un `ListView`: solo construye lo visible, y con diez módulos
/// Notificaciones queda por debajo del pliegue. `hitTestable` y no `find` a
/// secas, porque un `ListView` construye también lo que queda fuera de pantalla.
Future<void> abrirModulo(WidgetTester tester, String titulo) async {
  for (var intento = 0; intento < 20; intento += 1) {
    final finder = find.text(titulo).hitTestable();

    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  fail('No se encontró "$titulo" en el lanzador ni bajando del todo.');
}

/// Baja la lista hasta ver un texto, sin pulsarlo.
Future<void> bajarHasta(WidgetTester tester, String texto) async {
  for (var intento = 0; intento < 20; intento += 1) {
    if (find.textContaining(texto).hitTestable().evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  fail('No se encontró "$texto" bajando del todo.');
}

/// Baja hasta el final del lanzador, sin buscar nada en concreto.
///
/// Para probar que un módulo **no** está: mirar sin bajar daría `findsNothing`
/// para un módulo que simplemente queda por debajo del pliegue, y eso sería un
/// verde falso. Recorriendo la lista entera, el "no está" es de verdad.
Future<void> bajarAlFinal(WidgetTester tester) async {
  for (var intento = 0; intento < 20; intento += 1) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Notificaciones a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      // Es el décimo módulo, así que hay que bajar: en el móvil tampoco se ve
      // sin desplazarse.
      await bajarHasta(tester, 'Notificaciones');
      expect(find.text('Notificaciones'), findsOneWidget);
    });

    testWidgets('no lo enseña a un recolector sin permiso', (tester) async {
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'recolector',
          plantaId: 1,
          recursos: {
            'recorridos': ['read', 'write'],
            'recolecciones': ['read', 'write'],
          },
        ),
      ));
      await pumpListo(tester);

      // Se recorre el lanzador entero: mirar sin más daría `findsNothing` tanto
      // si el módulo está filtrado como si simplemente queda por debajo del
      // pliegue, y ese "no" no comprobaría nada.
      await bajarAlFinal(tester);
      expect(find.text('Notificaciones'), findsNothing);
      // Y sí ve algo, para que el "no" no venga de una lista vacía.
      expect(find.text('Recolecciones'), findsOneWidget);
    });
  });

  group('los dos caminos de guardar', () {
    // Esta es la diferencia que hace que este módulo exista. Si `crear` y
    // `crearEnviada` fueran la misma llamada, la pantalla ofrecería dos botones
    // que harían exactamente lo mismo.
    testWidgets('guardar deja un borrador: sin enviada y sin fecha', (tester) async {
      final api = FakeNotificacionApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(notificacionesControllerProvider.notifier).crear(
        tipo: Notificacion.reunion,
        titulo: 'Reunión de ruta',
        mensaje: 'Lunes a las nueve.',
      );

      expect(ok, isTrue);
      expect(api.borradoresCreados, hasLength(1));
      expect(api.enviadosCreados, isEmpty);

      final creado = await api.ver(api.borradoresCreados.first);
      expect(creado.enviada, isFalse);
      expect(creado.esBorrador, isTrue);
      expect(creado.fechaEnvio, isNull);
    });

    testWidgets('enviar sale con enviada y fecha puestas por el servidor',
        (tester) async {
      final api = FakeNotificacionApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(notificacionesControllerProvider.notifier).enviar(
        tipo: Notificacion.adulteracion,
        titulo: 'Lote 12',
        mensaje: 'Salió adulterada.',
      );

      expect(ok, isTrue);
      expect(api.enviadosCreados, hasLength(1));
      expect(api.borradoresCreados, isEmpty);

      final creado = await api.ver(api.enviadosCreados.first);
      expect(creado.enviada, isTrue);
      expect(creado.esBorrador, isFalse);
      // La fecha la pone el servidor; la app nunca la manda.
      expect(creado.fechaEnvio, isNotNull);
    });
  });

  group('el estado imposible', () {
    // Medido: el servidor NO borra `fechaEnvio` cuando un `PUT` pone `enviada`
    // en `false`. Se puede quedar un "borrador" con fecha de envío, y la app no
    // debe enseñarla como si hubiera salido.
    test('un borrador con fecha no enseña fecha de envío', () {
      final raro = Notificacion.fromJson(const <String, dynamic>{
        'id': 1,
        'tipo': 'reunion',
        'titulo': 'T',
        'mensaje': 'M',
        'leida': false,
        'enviada': false,
        'fechaEnvio': '2026-10-13T09:30:00.000Z',
      });

      // La fecha está...
      expect(raro.fechaEnvio, isNotNull);
      // ...pero no se enseña, porque no salió.
      expect(raro.esBorrador, isTrue);
      expect(raro.fechaEnvioLegible, isNull);
    });

    test('una enviada sí enseña su fecha, en día/mes/año', () {
      final enviada = notificacionDePrueba(
        enviada: true,
        fechaEnvio: DateTime(2026, 10, 13, 9, 30),
      );

      expect(enviada.esBorrador, isFalse);
      expect(enviada.fechaEnvioLegible, '13/10/2026');
    });

    testWidgets('editar un aviso enviado no lo des-envía', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, enviada: true, fechaEnvio: DateTime(2026, 10, 13)),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // Se edita el contenido de un aviso ya enviado: es legal y el servidor lo
      // acepta. Lo que no puede pasar es que quede como borrador, porque no hay
      // forma de retirar uno ya entregado.
      await contenedor.read(notificacionesControllerProvider.notifier).editar(
        notificacionDePrueba(id: 1, enviada: true),
        titulo: 'Título corregido',
      );
      await pumpListo(tester);

      final fila = contenedor.read(notificacionesControllerProvider).notificaciones
          .firstWhere((n) => n.id == 1);
      expect(fila.titulo, 'Título corregido');
      expect(fila.enviada, isTrue, reason: 'editar no retira el aviso');
      expect(fila.fechaEnvio, isNotNull);
    });
  });

  group('leer y no leer', () {
    testWidgets('marcar leída cambia la fila sin recargar la lista', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1),
        notificacionDePrueba(id: 2),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(contenedor.read(notificacionesControllerProvider).sinLeer, 2);

      await contenedor
          .read(notificacionesControllerProvider.notifier)
          .marcarLeida(notificacionDePrueba(id: 1), true);
      await pumpListo(tester);

      // El contador baja sin volver a pedir la lista: recargarla tiraría la
      // pantalla justo cuando alguien está tachando varios seguidos.
      expect(contenedor.read(notificacionesControllerProvider).sinLeer, 1);
      final fila = contenedor.read(notificacionesControllerProvider).notificaciones
          .firstWhere((n) => n.id == 1);
      expect(fila.leida, isTrue);
    });

    testWidgets('volver a marcar lo que ya está así no llama al servidor',
        (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, leida: true),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(notificacionesControllerProvider.notifier)
          .marcarLeida(notificacionDePrueba(id: 1, leida: true), true);
      await pumpListo(tester);

      expect(ok, isTrue);
      // Un `PUT` inútil gastaría una ida al servidor y podría fallar sin motivo.
      expect(contenedor.read(notificacionesControllerProvider).sinLeer, 0);
    });
  });

  group('los filtros', () {
    testWidgets('"sin leer" pregunta leida=false, no null', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, leida: false),
        notificacionDePrueba(id: 2, leida: true),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(notificacionesControllerProvider.notifier).alternarSoloSinLeer();
      await pumpListo(tester);

      // `false` y no `null`: `null` preguntaría por todos, que es lo contrario de
      // lo que quiere quien pulsa "sin leer".
      expect(api.ultimaConsulta?.leida, isFalse);
    });

    testWidgets('con el filtro apagado la pregunta es null, no false', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, leida: true),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // Sin filtro, la lista tiene que traer también las leídas. Y se leen del
      // controlador, no de la petición: el orden en que el doble recibe su
      // última consulta no prueba que fuera la de esta pantalla.
      expect(api.ultimaConsulta?.leida, isNull);
      expect(contenedor.read(notificacionesControllerProvider).notificaciones, hasLength(1));
    });

    testWidgets('"borradores" pregunta enviada=false', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, enviada: false),
        notificacionDePrueba(id: 2, enviada: true, fechaEnvio: DateTime(2026, 10, 13)),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(notificacionesControllerProvider.notifier).alternarSoloBorradores();
      await pumpListo(tester);

      expect(api.ultimaConsulta?.enviada, isFalse);
      expect(contenedor.read(notificacionesControllerProvider).notificaciones, hasLength(1));
      expect(
        contenedor.read(notificacionesControllerProvider).notificaciones.first.id,
        1,
        reason: 'solo debe quedar el borrador, no el ya enviado',
      );
    });

    testWidgets('el tipo viaja como el texto del ENUM', (tester) async {
      final api = FakeNotificacionApi(notificaciones: [
        notificacionDePrueba(id: 1, tipo: Notificacion.reunion),
        notificacionDePrueba(id: 2, tipo: Notificacion.adulteracion),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(notificacionesControllerProvider.notifier)
          .filtrarPorTipo(Notificacion.reunion);
      await pumpListo(tester);

      // `reunion`, el valor del `ENUM`. No `Reunión`, que es la etiqueta de
      // pantalla y el servidor no la conoce.
      expect(api.ultimaConsulta?.tipo, 'reunion');
    });
  });

  group('el modelo', () {
    test('sin proveedor, el aviso es para toda la planta', () {
      final aviso = notificacionDePrueba(id: 1);
      expect(aviso.esDirigida, isFalse);
      expect(aviso.destinatario, 'Toda la planta');
    });

    test('con proveedor, se dice su nombre y no su id', () {
      final aviso = notificacionDePrueba(id: 1, proveedorId: 4);
      expect(aviso.esDirigida, isTrue);
      expect(aviso.destinatario, 'Juan Pérez');
      expect(aviso.destinatario, isNot(contains('#')));
    });

    test('los tres tipos tienen etiqueta, y uno desconocido no deja la fila en blanco', () {
      expect(Notificacion.etiquetaDeTipo(Notificacion.adulteracion), 'Adulteración');
      expect(Notificacion.etiquetaDeTipo(Notificacion.reunion), 'Reunión');
      expect(Notificacion.etiquetaDeTipo(Notificacion.capacitacion), 'Capacitación');
      // Si el servidor añadiera un cuarto tipo mañana, se enseña crudo.
      expect(Notificacion.etiquetaDeTipo('NUEVO'), 'NUEVO');
    });

    test('el mensaje largo se recorta con puntos y el corto no se toca', () {
      Notificacion conMensaje(String texto) => Notificacion.fromJson(<String, dynamic>{
            'id': 1,
            'tipo': 'reunion',
            'titulo': 'T',
            'mensaje': texto,
            'leida': false,
            'enviada': false,
          });

      final corto = 'El análisis dio agua añadida.';
      expect(conMensaje(corto).mensajeCorto, corto, reason: 'si cabe, no se toca');

      final largo = List.filled(200, 'palabra').join(' ');
      final recortado = conMensaje(largo).mensajeCorto;

      expect(recortado.length, lessThan(largo.length));
      expect(recortado, endsWith('…'));

      // Lo que se ve es un prefijo del original, y lo que se quitó empieza justo
      // en un espacio: cortar en mitad de palabra se lee como un fallo de la
      // pantalla y no como un resumen.
      final cuerpo = recortado.substring(0, recortado.length - 1);
      expect(largo.startsWith(cuerpo), isTrue);
      expect(largo[cuerpo.length], ' ');
    });
  });

  group('la lista', () {
    testWidgets('distingue lo enviado de lo que solo está guardado', (tester) async {
      await tester.pumpWidget(montar(avisos: [
        notificacionDePrueba(id: 1, enviada: true, fechaEnvio: DateTime(2026, 10, 13)),
        notificacionDePrueba(id: 2, enviada: false),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Notificaciones');

      expect(find.text('sin enviar'), findsOneWidget);
      expect(find.textContaining('enviado 13/10/2026'), findsOneWidget);
    });

    testWidgets('marca en la fila lo que sigue sin leer', (tester) async {
      await tester.pumpWidget(montar(avisos: [
        notificacionDePrueba(id: 1, titulo: 'Aviso pendiente', leida: false),
        notificacionDePrueba(id: 2, titulo: 'Aviso ya visto', leida: true),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Notificaciones');

      expect(find.text('sin leer'), findsOneWidget);
      await bajarHasta(tester, '1 sin leer');
      expect(find.textContaining('1 sin leer'), findsOneWidget);
    });

    testWidgets('avisa si no hay avisos o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Notificaciones');

      expect(find.textContaining('todavía no tiene avisos'), findsOneWidget);
    });
  });
}
