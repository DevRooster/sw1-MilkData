// Pruebas del módulo Asistencias.
//
// Lo que este módulo tiene de particular es que `evento` es **texto libre** y
// `registradoPor` es un `ENUM` **sin valor por defecto**. Las dos cosas se
// comprueban aquí, porque son las que hacen la pantalla distinta de las demás.
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
import 'package:milkdata_app/features/proveedores/presentation/providers/proveedores_controller.dart';

import 'helpers/fake_asistencia_api.dart';
import 'helpers/fake_auth_api.dart';
import 'helpers/fake_proveedor_api.dart';
import 'helpers/fake_token_storage.dart';

/// Monta la app entera con los dobles.
Widget montar({
  FakeAsistenciaApi? asistencias,
  Permisos? permisos,
  List<Asistencia> lista = const <Asistencia>[],
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
      asistenciaApiProvider.overrideWithValue(
        asistencias ?? FakeAsistenciaApi(asistencias: lista),
      ),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de asistencias, con su contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeAsistenciaApi api) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      asistenciaApiProvider.overrideWithValue(api),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: AsistenciasPage()),
    ),
  );

  return contenedor;
}

Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'asistencias': ['read', 'write'],
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

/// Baja hasta el final del lanzador, sin buscar nada.
Future<void> bajarAlFinal(WidgetTester tester) async {
  for (var intento = 0; intento < 20; intento += 1) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Asistencias a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      await bajarHasta(tester, 'Asistencias');
      expect(find.text('Asistencias'), findsOneWidget);
    });

    testWidgets('no lo enseña a quien no tiene el permiso', (tester) async {
      // Ojo con el nombre del rol: en la matriz real del backend el **recolector
      // sí tiene `asistencias`**, y el recolector tampoco sirve para este módulo.
      // Aquí lo que se prueba es el filtrado del lanzador, no la matriz, así que
      // se dan permisos que de verdad no incluyen el módulo.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'proveedor',
          plantaId: 1,
          recursos: {
            'proveedores': ['read'],
            'recorridos': ['read'],
            'recolecciones': ['read'],
          },
        ),
      ));
      await pumpListo(tester);

      // Se recorre entero: mirar sin más daría `findsNothing` tanto si está
      // filtrado como si simplemente queda por debajo del pliegue.
      await bajarAlFinal(tester);
      expect(find.text('Asistencias'), findsNothing);
      expect(find.text('Recolecciones'), findsOneWidget, reason: 'y sí ve algo');
    });
  });

  group('el modelo', () {
    test('el origen del registro se distingue y se lee', () {
      expect(asistenciaDePrueba(registradoPor: Asistencia.qr).esQr, isTrue);
      expect(asistenciaDePrueba(registradoPor: Asistencia.qr).esManual, isFalse);
      expect(asistenciaDePrueba(registradoPor: Asistencia.manual).esManual, isTrue);
      expect(asistenciaDePrueba(registradoPor: Asistencia.qr).etiquetaRegistro, 'QR');
      expect(asistenciaDePrueba(registradoPor: Asistencia.manual).etiquetaRegistro, 'manual');
    });

    test('el ENUM va en mayúsculas exactas, porque el backend ya distingue', () {
      // Con la validación `isIn` de la entidad, `qr` en minúscula es un 400. La
      // app manda las constantes y nunca el texto escrito a mano.
      expect(Asistencia.qr, 'QR');
      expect(Asistencia.manual, 'manual');
      // Y el registro por defecto es `manual`, porque esta pantalla ES el
      // registro manual: quien la abre está apuntando, no escaneando.
      expect(Asistencia.registroPorDefecto, Asistencia.manual);
    });

    test('la fecha se lee como día/mes/año, no como ISO', () {
      // `2026-10-13` no lo lee nadie de un vistazo.
      expect(asistenciaDePrueba(fecha: '2026-10-13').fechaLegible, '13/10/2026');
      // Y una fecha rara no revienta la pantalla.
      expect(asistenciaDePrueba(fecha: '2026-10').fechaLegible, '2026-10');
    });

    test('un registro sin proveedor no dice "null"', () {
      final huerfano = Asistencia.fromJson(const <String, dynamic>{
        'id': 1,
        'proveedorId': 7,
        'usuarioId': 1,
        'evento': 'Reunión',
        'fecha': '2026-10-13',
        'registradoPor': 'QR',
      });

      expect(huerfano.proveedor, isNull);
      expect(huerfano.nombreProveedor, 'Proveedor #7');
    });

    test('un origen desconocido no rompe la fila', () {
      // Si el servidor añadiera un tercero, la pantalla lo sigue enseñando.
      final raro = Asistencia.fromJson(const <String, dynamic>{
        'id': 1,
        'proveedorId': 1,
        'usuarioId': 1,
        'evento': 'E',
        'fecha': '2026-10-13',
        'registradoPor': 'LECTOR',
      });

      expect(raro.esQr, isFalse);
      expect(raro.esManual, isFalse);
      expect(raro.etiquetaRegistro, 'manual');
    });
  });

  group('las reglas que el servidor impone', () {
    testWidgets('un origen que no es QR ni manual se rechaza con 400', (tester) async {
      final api = FakeAsistenciaApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(asistenciasControllerProvider.notifier).crear(
        proveedorId: 1,
        usuarioId: 1,
        evento: 'Reunión',
        fecha: '2026-10-13',
        registradoPor: 'escaner',
      );

      expect(ok, isFalse);
      expect(api.registrosRechazados, contains('escaner'));
      expect(api.creados, isEmpty);
      // Y el error queda en el estado para que la pantalla lo pueda enseñar.
      expect(contenedor.read(asistenciasControllerProvider).error, isNotNull);
    });

    testWidgets('un evento de más de 150 caracteres se rechaza', (tester) async {
      final api = FakeAsistenciaApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(asistenciasControllerProvider.notifier).crear(
        proveedorId: 1,
        usuarioId: 1,
        evento: 'a' * 151,
        fecha: '2026-10-13',
      );

      expect(ok, isFalse);
      expect(api.eventosLargos, hasLength(1));
      expect(api.creados, isEmpty);
    });

    test('el tope del evento es el de la columna', () {
      // El `VARCHAR(150)` de la base, no un número inventado en la app.
      expect(Asistencia.maximoEvento, 150);
    });

    testWidgets('un alta válida sí entra', (tester) async {
      final api = FakeAsistenciaApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(asistenciasControllerProvider.notifier).crear(
        proveedorId: 1,
        usuarioId: 1,
        evento: 'Reunión de ruta',
        fecha: '2026-10-13',
        registradoPor: Asistencia.qr,
      );

      expect(ok, isTrue);
      expect(api.creados, hasLength(1));
    });
  });

  group('los filtros', () {
    testWidgets('el evento busca por fragmento y sin distinguir tildes', (tester) async {
      // `evento` es texto libre: quien recuerda "reunion" —sin tilde, como se
      // escribe deprisa— tiene que encontrar "Reunión de ruta del Norte". El
      // `LIKE` de MySQL con `utf8mb4_0900_ai_ci` tampoco distingue acentos, y el
      // doble tiene que repartirlo o la prueba mediría un doble más estricto que
      // el servidor.
      final api = FakeAsistenciaApi(asistencias: [
        asistenciaDePrueba(id: 1, evento: 'Reunión de ruta del Norte'),
        asistenciaDePrueba(id: 2, evento: 'Capacitación sobre adulteración'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(asistenciasControllerProvider.notifier)
          .filtrarPorEvento('reunion');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.evento, 'reunion');
      expect(contenedor.read(asistenciasControllerProvider).asistencias, hasLength(1));
      expect(
        contenedor.read(asistenciasControllerProvider).asistencias.first.evento,
        'Reunión de ruta del Norte',
      );
    });

    testWidgets('el origen viaja como el texto exacto del ENUM', (tester) async {
      final api = FakeAsistenciaApi(asistencias: [
        asistenciaDePrueba(id: 1, registradoPor: Asistencia.qr),
        asistenciaDePrueba(id: 2, registradoPor: Asistencia.manual),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(asistenciasControllerProvider.notifier)
          .filtrarPorRegistro(Asistencia.qr);
      await pumpListo(tester);

      // `QR` en mayúsculas, que es como lo acepta el backend.
      expect(api.ultimaConsulta?.registradoPor, 'QR');
      expect(contenedor.read(asistenciasControllerProvider).asistencias, hasLength(1));
    });

    testWidgets('volver a "las dos" quita el filtro', (tester) async {
      final api = FakeAsistenciaApi(asistencias: [
        asistenciaDePrueba(id: 1, registradoPor: Asistencia.qr),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final controller = contenedor.read(asistenciasControllerProvider.notifier);
      await controller.filtrarPorRegistro(Asistencia.qr);
      await pumpListo(tester);
      expect(api.ultimaConsulta?.registradoPor, 'QR');

      await controller.filtrarPorRegistro(null);
      await pumpListo(tester);
      expect(api.ultimaConsulta?.registradoPor, isNull);
    });
  });

  group('la lista', () {
    testWidgets('distingue lo escaneado de lo apuntado', (tester) async {
      await tester.pumpWidget(montar(lista: [
        asistenciaDePrueba(id: 1, proveedorId: 1, registradoPor: Asistencia.qr),
        // Nombre distinto a propósito: el helper trae "Juan Pérez" por defecto, y
        // con las dos filas iguales la comprobación del proveedor no distinguiría
        // una fila de otra.
        asistenciaDePrueba(
          id: 2,
          proveedorId: 2,
          nombreProveedor: 'María',
          apellidoProveedor: 'López',
          registradoPor: Asistencia.manual,
        ),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Asistencias');

      expect(find.text('QR'), findsOneWidget);
      expect(find.text('manual'), findsOneWidget);
      // El proveedor va en la misma línea que la fecha, así que va por fragmento.
      expect(find.textContaining('Juan Pérez'), findsOneWidget);
    });

    testWidgets('el resumen cuenta cuántas son de QR', (tester) async {
      await tester.pumpWidget(montar(lista: [
        asistenciaDePrueba(id: 1, registradoPor: Asistencia.qr),
        asistenciaDePrueba(id: 2, registradoPor: Asistencia.qr),
        asistenciaDePrueba(id: 3, registradoPor: Asistencia.manual),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Asistencias');

      // La proporción importa: si casi todas son manuales, el registro se está
      // llenando de memoria, y eso hay que poder verlo sin exportar nada.
      await bajarHasta(tester, 'por QR de 3');
      expect(find.textContaining('2 por QR de 3 en esta página'), findsOneWidget);
    });

    testWidgets('avisa si no hay asistencias', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Asistencias');

      expect(find.textContaining('no se ha registrado ninguna asistencia'), findsOneWidget);
    });
  });

  group('borrar', () {
    testWidgets('elimina y descuenta del resumen de QR', (tester) async {
      final api = FakeAsistenciaApi(asistencias: [
        asistenciaDePrueba(id: 1, registradoPor: Asistencia.qr),
        asistenciaDePrueba(id: 2, registradoPor: Asistencia.manual),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(contenedor.read(asistenciasControllerProvider).porQr, 1);

      await contenedor
          .read(asistenciasControllerProvider.notifier)
          .eliminar(asistenciaDePrueba(id: 1, registradoPor: Asistencia.qr));
      await pumpListo(tester);

      expect(api.eliminados, [1]);
      // Si no bajara, el resumen daría un QR que ya no está.
      expect(contenedor.read(asistenciasControllerProvider).porQr, 0);
      expect(contenedor.read(asistenciasControllerProvider).asistencias, hasLength(1));
    });
  });
}