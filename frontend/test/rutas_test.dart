// Pruebas del módulo Rutas y del lanzador que lo ofrece.
//
// Este módulo va partido a propósito: la ruta se puede dar de alta y editar sin
// más, pero sus paradas dependen del módulo de Proveedores. Lo que se comprueba
// aquí es que la pantalla está y que avisa de lo que aún no se puede hacer, no al
// revés: no se ofrece un botón que fuera a fallar con un 400.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/rutas/presentation/lista_rutas_page.dart';
import 'package:milkdata_app/features/rutas/presentation/providers/rutas_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_ruta_api.dart';
import 'helpers/fake_token_storage.dart';

/// Monta la app con los dobles, incluido el de rutas.
Widget montar({
  FakeRutaApi? rutas,
  Permisos? permisos,
}) {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = permisos ?? _todoPermitido();

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(
          api: cliente,
          storage: ref.watch(tokenStorageProvider),
        ),
      ),
      rutaApiProvider.overrideWithValue(rutas ?? FakeRutaApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de rutas, con su propio contenedor de providers.
///
/// Permite hablar con el controlador desde el propio test, sin pasar por un
/// gesto: lo que importa es qué llega al servidor, no cómo se escogió la opción.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeRutaApi rutas) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      rutaApiProvider.overrideWithValue(rutas),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: RutasPage()),
    ),
  );

  return contenedor;
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'rutas': ['read', 'write'],
        'productos': ['read', 'write'],
        'unidades': ['read', 'write'],
      },
    );

/// Deja que la carga del controlador termine.
Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Abre un módulo desde el lanzador.
///
/// 600 ms y no 400: abrir un módulo empuja una ruta con su transición, y la
/// transición de Cupertino dura justo 400 ms.
Future<void> abrirModulo(WidgetTester tester, String titulo) async {
  await tester.tap(find.text(titulo));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Baja la lista hasta que se vea un texto.
///
/// El formulario es un `ListView`, que solo construye lo que se ve.
Future<void> bajarHasta(WidgetTester tester, String etiqueta) async {
  for (var intento = 0; intento < 6; intento += 1) {
    if (find.text(etiqueta).evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Sube la lista hasta arriba, para volver a ver los campos de arriba.
Future<void> irAlPrincipio(WidgetTester tester) async {
  for (var intento = 0; intento < 6; intento += 1) {
    await tester.drag(find.byType(ListView).last, const Offset(0, 260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Rutas a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      expect(find.text('Rutas'), findsOneWidget);
    });

    testWidgets('no lo enseña a un laboratorio', (tester) async {
      // Sale de la matriz real: `laboratorio` no tiene `rutas`, así que la API
      // le respondería 403. Aparecerle en el lanzador sería tocar algo y
      // descubrirlo ahí.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'laboratorio',
          plantaId: 1,
          recursos: {
            'productos': ['read'],
            'calidad': ['read', 'write'],
          },
        ),
      ));
      await pumpListo(tester);

      expect(find.text('Rutas'), findsNothing);
    });
  });

  group('la lista de rutas', () {
    testWidgets('enseña las rutas que devuelve la API', (tester) async {
      await tester.pumpWidget(montar(
        rutas: FakeRutaApi(rutas: [
          rutaDePrueba(id: 1, nombre: 'Ruta Norte', paradasCount: 2),
          rutaDePrueba(id: 2, nombre: 'Ruta Sur', codigo: 'RUTASUR', horaInicio: '12:00:00', horaFin: '17:00:00'),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      expect(find.text('Ruta Norte'), findsOneWidget);
      expect(find.text('Ruta Sur'), findsOneWidget);
      expect(find.textContaining('2 paradas'), findsOneWidget);
    });

    testWidgets('el horario se muestra corto y con guion', (tester) async {
      await tester.pumpWidget(montar(
        rutas: FakeRutaApi(rutas: [
          rutaDePrueba(id: 1, horaInicio: '06:00:00', horaFin: '11:00:00'),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      // Viene de un TIME(6) como "06:00:00". Los segundos no se enseñan: una
      // ruta empieza a una hora, no a las 06:00:47.
      expect(find.textContaining('06:00 – 11:00'), findsOneWidget);
    });

    testWidgets('sin horario entero no inventa horas', (tester) async {
      await tester.pumpWidget(montar(
        rutas: FakeRutaApi(rutas: [
          rutaDePrueba(id: 1, horaInicio: null, horaFin: null),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      // Un horario a medias no se rellena por lo bajo: se enseña el que hay.
      expect(find.textContaining('Sin horario'), findsOneWidget);
    });

    testWidgets('la búsqueda viaja al servidor y la X la quita', (tester) async {
      final api = FakeRutaApi(rutas: [
        rutaDePrueba(id: 1, nombre: 'Ruta Norte', codigo: 'RUTANORTE'),
        rutaDePrueba(id: 2, nombre: 'Ruta Sur', codigo: 'RUTASUR'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);

      await contenedor.read(rutasControllerProvider.notifier).buscar('Norte');
      await pumpListo(tester);

      // La búsqueda llega al servidor: si se filtrara en la pantalla, la lista
      // mentiría sobre lo que devuelve la API.
      expect(api.ultimaConsulta?.busqueda, 'Norte');
      expect(find.text('Ruta Norte'), findsOneWidget);
      expect(find.text('Ruta Sur'), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill).first);
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, isNull);
      expect(find.text('Ruta Sur'), findsOneWidget);
    });

    testWidgets('el filtro de inactivas viaja como activa=false', (tester) async {
      final api = FakeRutaApi(rutas: [
        rutaDePrueba(id: 1, nombre: 'Ruta Norte'),
        rutaDePrueba(id: 2, nombre: 'Ruta Vieja', activa: false),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(rutasControllerProvider.notifier).alternarSoloInactivas();
      await pumpListo(tester);

      // `activa=false`, no un `?inactivas`: el servidor solo conoce `activa`, y
      // mandar un filtro inventado daría un 400 en vez de una lista.
      expect(api.ultimaConsulta?.activa, isFalse);
      expect(find.text('Ruta Vieja'), findsOneWidget);
      expect(find.text('Ruta Norte'), findsNothing);
    });

    testWidgets('avisa distinto si no hay rutas o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(rutas: FakeRutaApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      expect(find.text('Esta planta todavía no tiene rutas.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).first, 'zzz');
      await pumpListo(tester);

      expect(find.text('Ninguna ruta coincide con el filtro.'), findsOneWidget);
    });

    testWidgets('al borrar avisa de las paradas que se llevan por delante', (tester) async {
      await tester.pumpWidget(montar(
        rutas: FakeRutaApi(rutas: [
          rutaDePrueba(id: 1, nombre: 'Ruta Norte', paradasCount: 3),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      await tester.tap(find.byIcon(CupertinoIcons.trash).first);
      await pumpListo(tester);

      // Una ruta con paradas deja proveedores sin ruta asignada. Avisar solo de
      // "no se puede deshacer" dejaría al usuario sin saber lo que rompe.
      expect(find.textContaining('3 paradas'), findsWidgets);
      expect(find.textContaining('quedan sin ruta asignada'), findsOneWidget);
    });
  });

  group('el formulario de rutas', () {
    testWidgets('no deja guardar sin nombre ni código', (tester) async {
      final api = FakeRutaApi();

      await tester.pumpWidget(montar(rutas: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await bajarHasta(tester, 'Crear ruta');
      await tester.tap(find.text('Crear ruta'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('Ponle un nombre a la ruta.'), findsOneWidget);
      expect(find.text('Ponle un código a la ruta.'), findsOneWidget);
      // No se llegó a llamar a la API: la validación es de cliente y el error
      // va junto al campo, no en un aviso arriba.
      expect(api.creados, isEmpty);
    });



    testWidgets('crea la ruta y la muestra en la lista', (tester) async {
      final api = FakeRutaApi();

      await tester.pumpWidget(montar(rutas: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Ruta Norte');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'RUTANORTE');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear ruta');
      await tester.tap(find.text('Crear ruta'));
      await pumpListo(tester);

      expect(api.creados, hasLength(1));
      expect(find.text('Ruta Norte'), findsOneWidget);
    });

    testWidgets('el código se escribe solo en mayúsculas y sin espacios', (tester) async {
      final api = FakeRutaApi();

      await tester.pumpWidget(montar(rutas: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Rutas');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Ruta Norte');
      // El código es lo que se teclea en la operativa. "RUTA NORTE" y
      // "RUTANORTE" acabarían siendo dos rutas distintas al buscar.
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'ruta norte');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear ruta');
      await tester.tap(find.text('Crear ruta'));
      await pumpListo(tester);

      expect(api.creados, hasLength(1));
      expect(find.textContaining('RUTANORTE'), findsWidgets);
    });
  });

  group('el detalle de una ruta', () {
    testWidgets('enseña las paradas en el orden en que se recorren', (tester) async {
      final api = FakeRutaApi(rutas: [
        rutaDePrueba(id: 1, nombre: 'Ruta Norte'),
      ])..conParadas(1, [
          paradaDePrueba(id: 1, orden: 1, horaEstimada: '06:30:00'),
          paradaDePrueba(
            id: 2,
            proveedorId: 2,
            orden: 2,
            horaEstimada: '07:15:00',
            nombreProveedor: 'María',
            apellidoProveedor: 'Gómez',
          ),
        ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(rutasControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Ruta Norte'));
      await pumpListo(tester);

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('María Gómez'), findsOneWidget);
      // Las horas estimadas vienen como "06:30:00" y se enseñan cortas.
      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('07:15'), findsOneWidget);
    });

    testWidgets('avisa de que las paradas aún no se pueden tocar', (tester) async {
      final api = FakeRutaApi(rutas: [
        rutaDePrueba(id: 1, nombre: 'Ruta Norte'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(rutasControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Ruta Norte'));
      await pumpListo(tester);

      // No hay botón de añadir parada: una parada es un proveedor, y hasta que
      // llegue el módulo de Proveedores no hay cuáles. Ofrecerlo sería un botón
      // que al pulsarlo responde 400.
      expect(find.textContaining('todavía no hay cuáles elegir'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.add), findsNothing);
    });
  });
}
