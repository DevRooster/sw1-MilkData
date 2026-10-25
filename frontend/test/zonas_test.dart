// Pruebas del módulo Zonas y del lanzador que lo ofrece.
//
// La regla incómoda de este módulo es que `rutaId` y `unidadId` son opcionales
// y desasignan: mandar `null` quita la asignación, omitir el campo deja la que
// había. Es la diferencia entre "desasignar" y "no tocar", y no se ve en la
// pantalla: solo se ve en lo que llega al servidor. Por eso hay pruebas que
// miran exactamente eso.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/rutas/presentation/providers/rutas_controller.dart';
import 'package:milkdata_app/features/unidades/presentation/providers/unidades_controller.dart';
import 'package:milkdata_app/features/zonas/presentation/lista_zonas_page.dart';
import 'package:milkdata_app/features/zonas/presentation/providers/zonas_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_ruta_api.dart';
import 'helpers/fake_token_storage.dart';
import 'helpers/fake_unidad_api.dart';
import 'helpers/fake_zona_api.dart';

/// Monta la app con los dobles.
///
/// El formulario de zonas pide rutas y unidades para sus desplegables, así que
/// aquí también van sus dobles. Si no, el formulario se quedaría girando y las
/// pruebas de guardar no llegarían nunca al botón.
Widget montar({
  FakeZonaApi? zonas,
  FakeRutaApi? rutas,
  FakeUnidadApi? unidades,
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
      zonaApiProvider.overrideWithValue(zonas ?? FakeZonaApi()),
      rutaApiProvider.overrideWithValue(rutas ?? FakeRutaApi()),
      unidadApiProvider.overrideWithValue(unidades ?? FakeUnidadApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de zonas, con su propio contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeZonaApi zonas) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      zonaApiProvider.overrideWithValue(zonas),
      rutaApiProvider.overrideWithValue(FakeRutaApi()),
      unidadApiProvider.overrideWithValue(FakeUnidadApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: ZonasPage()),
    ),
  );

  return contenedor;
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'zonas': ['read', 'write'],
        'rutas': ['read', 'write'],
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
    testWidgets('enseña Zonas a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      expect(find.text('Zonas'), findsOneWidget);
    });

    testWidgets('no lo enseña a un proveedor', (tester) async {
      // `proveedor` no tiene `zonas` en la matriz del servidor, así que la API
      // le respondería 403.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'proveedor',
          plantaId: 1,
          recursos: {
            'recolecciones': ['read'],
            'productos': ['read'],
          },
        ),
      ));
      await pumpListo(tester);

      expect(find.text('Zonas'), findsNothing);
    });
  });

  group('la lista de zonas', () {
    testWidgets('enseña las zonas que devuelve la API', (tester) async {
      await tester.pumpWidget(montar(
        zonas: FakeZonaApi(zonas: [
          zonaDePrueba(id: 1, nombre: 'Zona Norte'),
          zonaDePrueba(id: 2, nombre: 'Zona Sur', rutaId: 2, unidadId: 2),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      expect(find.text('Zona Norte'), findsOneWidget);
      expect(find.text('Zona Sur'), findsOneWidget);
    });

    testWidgets('dice sin ruta y sin unidad en vez de callar', (tester) async {
      await tester.pumpWidget(montar(
        zonas: FakeZonaApi(zonas: [
          zonaDePrueba(id: 1, nombre: 'Zona Suelta', rutaId: null, unidadId: null),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      // Ruta y unidad son opcionales en la base. Que estén vacías es una
      // situación normal, no un dato que falte: se dice en pantalla en vez de
      // dejar dos huecos donde el usuario no sabe qué pasó.
      expect(find.text('sin ruta'), findsOneWidget);
      expect(find.text('sin unidad'), findsOneWidget);
    });

    testWidgets('el horario se muestra corto y con guion', (tester) async {
      await tester.pumpWidget(montar(
        zonas: FakeZonaApi(zonas: [zonaDePrueba(id: 1)]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      // Viene de un TIME como "06:00:00". Los segundos no se enseñan.
      expect(find.textContaining('06:00 – 10:00'), findsOneWidget);
    });

    testWidgets('la búsqueda viaja al servidor y la X la quita', (tester) async {
      final api = FakeZonaApi(zonas: [
        zonaDePrueba(id: 1, nombre: 'Zona Norte'),
        zonaDePrueba(id: 2, nombre: 'Zona Sur'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);

      await contenedor.read(zonasControllerProvider.notifier).buscar('Norte');
      await pumpListo(tester);

      // La búsqueda llega al servidor: si se filtrara en la pantalla, la lista
      // mentiría sobre lo que devuelve la API.
      expect(api.ultimaConsulta?.busqueda, 'Norte');
      expect(find.text('Zona Norte'), findsOneWidget);
      expect(find.text('Zona Sur'), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill).first);
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, isNull);
      expect(find.text('Zona Sur'), findsOneWidget);
    });

    testWidgets('el filtro de inactivas viaja como activo=false', (tester) async {
      final api = FakeZonaApi(zonas: [
        zonaDePrueba(id: 1, nombre: 'Zona Norte'),
        zonaDePrueba(id: 2, nombre: 'Zona Vieja', activo: false),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(zonasControllerProvider.notifier).alternarSoloInactivas();
      await pumpListo(tester);

      // `activo=false`, no un `?inactivas`: el servidor solo conoce `activo`, y
      // mandar un filtro inventado daría un 400 en vez de una lista.
      expect(api.ultimaConsulta?.activo, isFalse);
      expect(find.text('Zona Vieja'), findsOneWidget);
      expect(find.text('Zona Norte'), findsNothing);
    });

    testWidgets('avisa distinto si no hay zonas o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(zonas: FakeZonaApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      expect(find.text('Esta planta todavía no tiene zonas.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).first, 'zzz');
      await pumpListo(tester);

      expect(find.text('Ninguna zona coincide con el filtro.'), findsOneWidget);
    });

    testWidgets('al borrar avisa de lo que se queda apuntando a ella', (tester) async {
      await tester.pumpWidget(montar(
        zonas: FakeZonaApi(zonas: [zonaDePrueba(id: 1, rutaId: 1, unidadId: 1)]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      await tester.tap(find.byIcon(CupertinoIcons.trash).first);
      await pumpListo(tester);

      // Avisar solo de "no se puede deshacer" dejaría al usuario sin saber que
      // su ruta y su unidad se quedan con un puntero a algo que ya no está.
      expect(find.textContaining('su ruta se queda sin esta zona'), findsOneWidget);
      expect(
        find.textContaining('la unidad pierde la zona que recogía'),
        findsOneWidget,
      );
    });
  });

  group('el formulario de zonas', () {
    testWidgets('no deja guardar sin nombre', (tester) async {
      final api = FakeZonaApi();

      await tester.pumpWidget(montar(zonas: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await bajarHasta(tester, 'Crear zona');
      await tester.tap(find.text('Crear zona'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('Ponle un nombre a la zona.'), findsOneWidget);
      // No se llegó a llamar a la API: la validación es de cliente y el error
      // va junto al campo, no en un aviso arriba.
      expect(api.creados, isEmpty);
    });



    // La regla incómoda de este módulo, en las dos direcciones.
    testWidgets('sin ruta elegida manda null, no omite el campo', (tester) async {
      final api = FakeZonaApi();

      await tester.pumpWidget(montar(zonas: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Zonas');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Zona Suelta');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear zona');
      await tester.tap(find.text('Crear zona'));
      await pumpListo(tester);

      // Si el campo se omitiera, el servidor dejaría el valor anterior y "quitar
      // la ruta" no sería una acción sino un olvido. `null` es lo que desasigna.
      expect(api.ultimaGuardada?.rutaId, isNull);
      expect(api.ultimaGuardada?.unidadId, isNull);
    });

    testWidgets('editar sin cambiar la ruta la deja como estaba', (tester) async {
      final api = FakeZonaApi(zonas: [
        zonaDePrueba(id: 1, nombre: 'Zona Norte', rutaId: 1, unidadId: 1),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(zonasControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Editar'));
      await pumpListo(tester);
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Zona Norte Ampliada');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Guardar cambios');
      await tester.tap(find.text('Guardar cambios'));
      await pumpListo(tester);

      // Se manda lo que tenía, no `null`. Aquí la diferencia es la contraria:
      // mandar `null` por no haber tocado el campo le quitaría la ruta sin que
      // nadie lo hubiera pedido.
      expect(api.ultimaGuardada?.rutaId, 1);
      expect(api.ultimaGuardada?.unidadId, 1);
      expect(api.editados, contains(1));
    });
  });
}
