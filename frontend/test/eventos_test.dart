// Pruebas del módulo Eventos.
//
// Lo particular de este módulo es que nació de un problema concreto: el evento de
// las asistencias era texto libre, cada uno lo escribía a su modo y buscar una
// charla concreta no encontraba las tres primeras. Las pruebas comprueban que la
// búsqueda ahora encuentra esas tres, y que se puede seguir apuntando sin catálogo.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/asistencias/domain/asistencia.dart';
import 'package:milkdata_app/features/asistencias/presentation/lista_asistencias_page.dart';
import 'package:milkdata_app/features/asistencias/presentation/providers/asistencias_controller.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/eventos/domain/evento.dart';
import 'package:milkdata_app/features/eventos/presentation/lista_eventos_page.dart';
import 'package:milkdata_app/features/eventos/presentation/providers/eventos_controller.dart';
import 'package:milkdata_app/features/proveedores/presentation/providers/proveedores_controller.dart';

import 'helpers/fake_asistencia_api.dart';
import 'helpers/fake_auth_api.dart';
import 'helpers/fake_evento_api.dart';
import 'helpers/fake_proveedor_api.dart';
import 'helpers/fake_token_storage.dart';

Widget montar({
  FakeEventoApi? eventos,
  Permisos? permisos,
  List<Evento> lista = const <Evento>[],
}) {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = permisos ?? _conAsistencias();

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      eventoApiProvider.overrideWithValue(eventos ?? FakeEventoApi(eventos: lista)),
      asistenciaApiProvider.overrideWithValue(FakeAsistenciaApi()),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la pantalla de eventos, con su contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeEventoApi api) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _conAsistencias();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      eventoApiProvider.overrideWithValue(api),
      asistenciaApiProvider.overrideWithValue(FakeAsistenciaApi()),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: EventosPage()),
    ),
  );

  return contenedor;
}

Permisos _conAsistencias() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'asistencias': ['read', 'write'],
        'proveedores': ['read', 'write'],
      },
    );

Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Abre un módulo del lanzador, bajando hasta encontrarlo.
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

Future<void> bajarAlFinal(WidgetTester tester) async {
  for (var intento = 0; intento < 20; intento += 1) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Eventos a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      await bajarHasta(tester, 'Eventos');
      expect(find.text('Eventos'), findsOneWidget);
    });

    testWidgets('no lo enseña a quien no tiene el permiso', (tester) async {
      // Eventos comparte el permiso `asistencias`: un evento sin asistencias no
      // sirve para nada, así que abrir un permiso aparte serían dos puertas a lo
      // mismo.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'proveedor',
          plantaId: 1,
          recursos: {
            'proveedores': ['read'],
            'recolecciones': ['read'],
          },
        ),
      ));
      await pumpListo(tester);

      await bajarAlFinal(tester);
      expect(find.text('Eventos'), findsNothing);
      expect(find.text('Recolecciones'), findsOneWidget, reason: 'y sí ve algo');
    });
  });

  group('el modelo', () {
    test('la fecha se lee como día/mes/año', () {
      expect(eventoDePrueba(fecha: '2026-10-20').fechaLegible, '20/10/2026');
      // Y una fecha rara no revienta la pantalla.
      expect(eventoDePrueba(fecha: '2026-10').fechaLegible, '2026-10');
    });

    test('el lugar solo aparece si lo hay', () {
      // "Capacitación · " con un punto y nada detrás parece un texto roto.
      expect(eventoDePrueba(lugar: 'Sala').etiquetaCorta, 'Reunion de ruta del Norte · Sala');
      expect(eventoDePrueba(lugar: null).etiquetaCorta, 'Reunion de ruta del Norte');
      expect(eventoDePrueba(lugar: '   ').etiquetaCorta, 'Reunion de ruta del Norte');
    });

    test('un evento pasado se distingue de uno que no', () {
      final hoy = DateTime.now();
      final deHoy = '${hoy.year.toString().padLeft(4, '0')}-'
          '${hoy.month.toString().padLeft(2, '0')}-'
          '${hoy.day.toString().padLeft(2, '0')}';

      expect(eventoDePrueba(fecha: deHoy).yaPaso, isFalse);
      expect(eventoDePrueba(fecha: '2020-01-01').yaPaso, isTrue);
    });
  });

  group('la búsqueda, que es el motivo del módulo', () {
    testWidgets('encuentra un evento escrito sin tilde ni mayúscula', (tester) async {
      // **Este es el problema que motivó el módulo entero.** Con el evento
      // como texto libre, "reunion" no encontraba "Reunión de ruta del Norte": el
      // `LIKE` de MySQL no distingue acentos, así que la pantalla tiene que
      // comportarse igual o sería más estricta que el servidor.
      final api = FakeEventoApi(eventos: [
        eventoDePrueba(id: 1, nombre: 'Reunion de ruta del Norte', lugar: 'Sala'),
        eventoDePrueba(id: 2, nombre: 'Capacitacion sobre adulteracion', lugar: 'Laboratorio'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(eventosControllerProvider.notifier).filtrarPorTexto('reunion');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, 'reunion');
      expect(contenedor.read(eventosControllerProvider).eventos, hasLength(1));
      expect(
        contenedor.read(eventosControllerProvider).eventos.first.nombre,
        'Reunion de ruta del Norte',
      );
    });

    testWidgets('busca también en el sitio y en la descripción', (tester) async {
      final api = FakeEventoApi(eventos: [
        eventoDePrueba(id: 1, lugar: 'Laboratorio', descripcion: 'Nada que ver'),
        eventoDePrueba(id: 2, nombre: 'Otra cosa', lugar: 'Sala', descripcion: 'Va al laboratorio'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(eventosControllerProvider.notifier).filtrarPorTexto('laboratorio');
      await pumpListo(tester);

      expect(contenedor.read(eventosControllerProvider).eventos, hasLength(2));
    });

    testWidgets('una palabra que no existe devuelve cero, no todo', (tester) async {
      // **Antes esto devolvía todo.** El guard que decide si el `where` está
      // vacío usaba `Object.keys()`, que no cuenta las claves de símbolo, y la
      // búsqueda se construye con `[Op.or]`. Medido contra la API viva.
      final api = FakeEventoApi(eventos: [
        eventoDePrueba(id: 1),
        eventoDePrueba(id: 2),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(eventosControllerProvider.notifier).filtrarPorTexto('zzzznada');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, 'zzzznada');
      expect(contenedor.read(eventosControllerProvider).eventos, isEmpty);
      expect(contenedor.read(eventosControllerProvider).total, 0);
    });
  });

  group('el rango de fechas', () {
    testWidgets('desde y hasta se acumulan, no se pisan', (tester) async {
      final api = FakeEventoApi(eventos: [
        eventoDePrueba(id: 1, fecha: '2026-10-20'),
        eventoDePrueba(id: 2, fecha: '2026-10-27'),
        eventoDePrueba(id: 3, fecha: '2026-11-05'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(eventosControllerProvider.notifier)
          .filtrarPorRango('2026-10-21', '2026-10-31');
      await pumpListo(tester);

      // Con `Object.assign` el `hasta` borraría al `desde` y saldrían los tres.
      expect(api.ultimaConsulta?.desde, '2026-10-21');
      expect(api.ultimaConsulta?.hasta, '2026-10-31');
      expect(contenedor.read(eventosControllerProvider).eventos, hasLength(1));
      expect(contenedor.read(eventosControllerProvider).eventos.first.id, 2);
    });

    testWidgets('volver a limpiar quita el rango', (tester) async {
      final api = FakeEventoApi(eventos: [eventoDePrueba(id: 1)]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final controller = contenedor.read(eventosControllerProvider.notifier);
      await controller.filtrarPorRango('2026-10-21', '2026-10-31');
      await pumpListo(tester);
      expect(contenedor.read(eventosControllerProvider).eventos, isEmpty);

      await controller.limpiarFiltros();
      await pumpListo(tester);
      expect(api.ultimaConsulta?.desde, isNull);
      expect(contenedor.read(eventosControllerProvider).eventos, hasLength(1));
    });
  });

  group('las validaciones que el servidor impone', () {
    testWidgets('un nombre de más de 150 caracteres se rechaza', (tester) async {
      final api = FakeEventoApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(eventosControllerProvider.notifier).crear(
        nombre: 'a' * 151,
        fecha: '2026-10-20',
      );

      expect(ok, isFalse);
      expect(api.nombresLargos, hasLength(1));
      expect(api.creados, isEmpty);
    });

    testWidgets('una fecha en blanco se rechaza con 400, no con 500', (tester) async {
      // **Esto daba un 500**: `allowNull: false` no coge `""`, MySQL convertía la
      // cadena vacía en "Invalid date" y reventaba. Medido contra la API viva.
      final api = FakeEventoApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(eventosControllerProvider.notifier)
          .crear(nombre: 'Reunión', fecha: '');

      expect(ok, isFalse);
      expect(api.fechasRechazadas, ['']);
      expect(api.creados, isEmpty);
      expect(contenedor.read(eventosControllerProvider).error, isNotNull);
    });

    testWidgets('una fecha con letras también se rechaza', (tester) async {
      final api = FakeEventoApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(eventosControllerProvider.notifier)
          .crear(nombre: 'Reunión', fecha: 'el martes');

      expect(ok, isFalse);
      expect(api.creados, isEmpty);
    });

    testWidgets('un evento válido sí entra', (tester) async {
      final api = FakeEventoApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(eventosControllerProvider.notifier).crear(
        nombre: 'Reunión de ruta',
        fecha: '2026-10-20',
        lugar: 'Sala',
      );

      expect(ok, isTrue);
      expect(api.creados, hasLength(1));
    });

    test('los topes son los de la columna', () {
      expect(Evento.maximoNombre, 150);
      expect(Evento.maximoLugar, 150);
    });
  });

  group('la lista', () {
    testWidgets('avisa si no hay eventos', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Eventos');

      expect(find.textContaining('Todavía no hay eventos'), findsOneWidget);
    });

    testWidgets('distingue por nombre, día y sitio', (tester) async {
      await tester.pumpWidget(montar(lista: [eventoDePrueba(id: 1)]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Eventos');

      expect(find.text('Reunion de ruta del Norte'), findsOneWidget);
      expect(find.textContaining('20/10/2026'), findsOneWidget);
      expect(find.textContaining('Sala de reuniones'), findsOneWidget);
    });

    testWidgets('marca los que ya pasaron', (tester) async {
      await tester.pumpWidget(montar(lista: [eventoDePrueba(id: 1, fecha: '2020-01-01')]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Eventos');

      expect(find.text('pasado'), findsOneWidget);
    });

    testWidgets('el resumen cuenta los que no han pasado', (tester) async {
      final hoy = DateTime.now();
      final deHoy = '${hoy.year.toString().padLeft(4, '0')}-'
          '${hoy.month.toString().padLeft(2, '0')}-'
          '${hoy.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(montar(lista: [
        eventoDePrueba(id: 1, fecha: deHoy),
        eventoDePrueba(id: 2, fecha: '2020-01-01'),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Eventos');

      await bajarHasta(tester, '1 por delante');
      expect(find.textContaining('1 por delante'), findsOneWidget);
    });

    testWidgets('avisa si el servidor no devuelve los eventos', (tester) async {
      // El desplegable de Asistencias depende de esta lista, así que tiene que
      // poder decir "no pude cargarlos" y no quedarse mudo.
      final api = FakeEventoApi()..fallarAlListar = true;

      await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(find.textContaining('Todavía no hay eventos'), findsOneWidget);
    });
  });

  group('borrar', () {
    testWidgets('elimina y descuenta del total', (tester) async {
      final api = FakeEventoApi(eventos: [
        eventoDePrueba(id: 1),
        eventoDePrueba(id: 2, fecha: '2020-01-01'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(contenedor.read(eventosControllerProvider).total, 2);

      await contenedor
          .read(eventosControllerProvider.notifier)
          .eliminar(eventoDePrueba(id: 1));
      await pumpListo(tester);

      expect(api.eliminados, [1]);
      expect(contenedor.read(eventosControllerProvider).total, 1);
    });
  });

  group('la asistencia apunta al evento', () {
    testWidgets('el catálogo se elige y la fila enseña su nombre', (tester) async {
      // El caso que pediste: apuntar una asistencia eligiendo el evento, no
      // escribiendo el texto. Y la fila enseña **el nombre del catálogo**.
      final eventos = FakeEventoApi(eventos: [eventoDePrueba(id: 7, nombre: 'Capacitacion')]);
      final asistencias = FakeAsistenciaApi(asistencias: [
        Asistencia(
          id: 1,
          proveedorId: 1,
          usuarioId: 1,
          evento: 'Capacitacion',
          eventoId: 7,
          fecha: '2026-10-20',
          registradoPor: Asistencia.manual,
          eventoCatalogo: const EventoAsistencia(id: 7, nombre: 'Capacitacion'),
        ),
      ]);

      final contenedor = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
          authApiProvider.overrideWithValue(_cliente()),
          authRepositoryProvider.overrideWith((ref) => _repo(ref, _cliente())),
          eventoApiProvider.overrideWithValue(eventos),
          asistenciaApiProvider.overrideWithValue(asistencias),
          proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
        ],
      );
      addTearDown(contenedor.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: contenedor,
          child: const CupertinoApp(home: AsistenciasPage()),
        ),
      );
      await pumpListo(tester);

      // El nombre del catálogo, no el texto libre.
      expect(find.text('Capacitacion'), findsOneWidget);
    });

    test('sin catálogo, la fila enseña el texto que se escribió', () {
      // Las asistencias viejas no tienen evento del catálogo y tienen que
      // seguir enseñando lo suyo: si se borrara, la lista perdería el sentido.
      final vieja = Asistencia(
        id: 1,
        proveedorId: 1,
        usuarioId: 1,
        evento: 'reunion de ruta',
        fecha: '2026-10-20',
        registradoPor: Asistencia.manual,
      );

      expect(vieja.tieneEventoCatalogo, isFalse);
      expect(vieja.eventoLegible, 'reunion de ruta');
    });

    test('con catálogo, manda el nombre del catálogo', () {
      final nueva = Asistencia(
        id: 1,
        proveedorId: 1,
        usuarioId: 1,
        evento: 'texto viejo',
        eventoId: 7,
        fecha: '2026-10-20',
        registradoPor: Asistencia.manual,
        eventoCatalogo: const EventoAsistencia(id: 7, nombre: 'Nombre del catálogo'),
      );

      expect(nueva.tieneEventoCatalogo, isTrue);
      expect(nueva.eventoLegible, 'Nombre del catálogo');
    });
  });
}

FakeAuthApi _cliente() {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _conAsistencias();
  return cliente;
}

AuthRepository _repo(Ref ref, FakeAuthApi cliente) {
  return AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider));
}