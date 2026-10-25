// Pruebas del módulo Proveedores y del lanzador que lo ofrece.
//
// La regla incómoda de este módulo es la más tajante de las que hay: **`rutaId`
// no se puede mandar ni vacío**. El backend lo rechaza en el alta y en la
// edición, y también cuando vale `null`, porque compara con `undefined` y en
// JSON `"rutaId": null` es `null`. La pertenencia a una ruta se decide desde las
// paradas de esa ruta.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/proveedores/presentation/lista_proveedores_page.dart';
import 'package:milkdata_app/features/proveedores/presentation/providers/proveedores_controller.dart';
import 'package:milkdata_app/features/rutas/presentation/providers/rutas_controller.dart';
import 'package:milkdata_app/features/unidades/presentation/providers/unidades_controller.dart';
import 'package:milkdata_app/features/zonas/presentation/providers/zonas_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_proveedor_api.dart';
import 'helpers/fake_ruta_api.dart';
import 'helpers/fake_token_storage.dart';
import 'helpers/fake_unidad_api.dart';
import 'helpers/fake_zona_api.dart';

/// Monta la app con los dobles.
///
/// El formulario de proveedores pide las zonas para su desplegable, así que
/// también van las de Zonas. Las de Rutas y Unidades no las usa este módulo,
/// pero se registran para que el contenedor esté completo y ningún `ref.read`
/// de alguno de ellos se quede sin su provider.
Widget montar({
  FakeProveedorApi? proveedores,
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
      proveedorApiProvider.overrideWithValue(proveedores ?? FakeProveedorApi()),
      zonaApiProvider.overrideWithValue(FakeZonaApi()),
      rutaApiProvider.overrideWithValue(FakeRutaApi()),
      unidadApiProvider.overrideWithValue(FakeUnidadApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de proveedores, con su propio contenedor de providers.
Future<ProviderContainer> pumpPagina(
  WidgetTester tester,
  FakeProveedorApi proveedores,
) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      proveedorApiProvider.overrideWithValue(proveedores),
      zonaApiProvider.overrideWithValue(FakeZonaApi()),
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
      child: const CupertinoApp(home: ProveedoresPage()),
    ),
  );

  return contenedor;
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'proveedores': ['read', 'write'],
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
    testWidgets('enseña Proveedores a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      expect(find.text('Proveedores'), findsOneWidget);
    });

    testWidgets('no lo enseña a un laboratorio', (tester) async {
      // Sale de la matriz real: `laboratorio` no tiene `proveedores`.
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

      expect(find.text('Proveedores'), findsNothing);
    });
  });

  group('la lista de proveedores', () {
    testWidgets('enseña los proveedores que devuelve la API', (tester) async {
      await tester.pumpWidget(montar(
        proveedores: FakeProveedorApi(proveedores: [
          proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez'),
          proveedorDePrueba(
            id: 2,
            nombre: 'María',
            apellido: 'Gómez',
            dni: '70000002',
            codigo: 'PROV-002',
          ),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('María Gómez'), findsOneWidget);
    });

    testWidgets('la búsqueda viaja al servidor y la X la quita', (tester) async {
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez'),
        proveedorDePrueba(
          id: 2,
          nombre: 'María',
          apellido: 'Gómez',
          dni: '70000002',
          codigo: 'PROV-002',
        ),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(proveedoresControllerProvider.notifier).buscar('Gómez');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, 'Gómez');
      expect(find.text('María Gómez'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsNothing);
    });

    testWidgets('la búsqueda llega también por el DNI y por el código', (tester) async {
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez'),
        proveedorDePrueba(
          id: 2,
          nombre: 'María',
          apellido: 'Gómez',
          dni: '70000002',
          codigo: 'PROV-002',
        ),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // Quien tiene el documento delante busca por el DNI; quien trabaja con la
      // hoja de rutas, por el código. Los dos tienen que encontrar a la misma
      // persona.
      await contenedor.read(proveedoresControllerProvider.notifier).buscar('70000002');
      await pumpListo(tester);

      expect(find.text('María Gómez'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsNothing);

      await contenedor.read(proveedoresControllerProvider.notifier).buscar('PROV-001');
      await pumpListo(tester);

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('María Gómez'), findsNothing);
    });

    testWidgets('el filtro de inactivos viaja como activo=false', (tester) async {
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez'),
        proveedorDePrueba(
          id: 2,
          nombre: 'Retirado',
          apellido: 'Old',
          activo: false,
        ),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(proveedoresControllerProvider.notifier).alternarSoloInactivos();
      await pumpListo(tester);

      expect(api.ultimaConsulta?.activo, isFalse);
      expect(find.text('Retirado Old'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsNothing);
    });

    testWidgets('avisa distinto si no hay proveedores o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(proveedores: FakeProveedorApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      expect(find.text('Esta planta todavía no tiene proveedores.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).first, 'zzz');
      await pumpListo(tester);

      expect(find.text('Ningún proveedor coincide con el filtro.'), findsOneWidget);
    });
  });

  group('el formulario de proveedores', () {
    testWidgets('no deja guardar sin nombre, apellido ni DNI', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('Ponle el nombre.'), findsOneWidget);
      expect(find.text('Ponle al menos un apellido.'), findsOneWidget);
      expect(find.text('El DNI es obligatorio.'), findsOneWidget);
      // No se llegó a llamar a la API: la validación es de cliente y el error
      // va junto al campo, no en un aviso arriba.
      expect(api.creados, isEmpty);
    });

    testWidgets('rechaza un DNI con letras', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      // Los campos van: nombre, apellido, DNI, teléfono, dirección. El código ya
      // no se escribe: lo pone el servidor.
      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Pérez');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000001-A');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('El DNI va solo con números.'), findsOneWidget);
      expect(api.creados, isEmpty);
    });

    testWidgets('crea el proveedor con lo que se escribió', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Pérez');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000001');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);

      expect(api.creados, hasLength(1));
      expect(find.text('Juan Pérez'), findsOneWidget);
    });

    // La regla incómoda del módulo. No basta con decir que el formulario no
    // tiene campo de ruta: hay que comprobar que la clave no se cuela.
    testWidgets('el alta NO manda rutaId, ni siquiera con null', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Pérez');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000001');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);

      // El backend rechaza `rutaId` aunque valga `null`. Si el formulario lo
      // mandara "por no poner nada", el alta entera fallaría con un 400 que
      // habla de rutas, y quien lo vería no entendería qué pasó.
      expect(api.ultimoCuerpo, isNotNull);
      expect(api.ultimoCuerpo!.containsKey('rutaId'), isFalse);
      expect(api.creados, hasLength(1));
    });

    testWidgets('la edición tampoco manda rutaId', (tester) async {
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(proveedoresControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Editar'));
      await pumpListo(tester);
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan Carlos');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Guardar cambios');
      await tester.tap(find.text('Guardar cambios'));
      await pumpListo(tester);

      expect(api.ultimoCuerpo!.containsKey('rutaId'), isFalse);
      expect(api.editados, contains(1));
    });

    testWidgets('la dirección se manda y vuelve a leerse', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Pérez');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000001');
      // Los campos son nombre, apellido, DNI, teléfono y dirección. El código ya
      // no está: lo pone el servidor y no se escribe.
      await tester.enterText(find.byType(CupertinoTextField).at(4), 'Av. Los Álamos 123');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);

      // Antes el DTO no la devolvía: se guardaba y a continuación salía vacía, y
      // el segundo guardado la borraba. Ahora tiene que volver.
      expect(api.ultimoCuerpo!['direccion'], 'Av. Los Álamos 123');
    });

    // El código del proveedor lo pone el servidor. Estas pruebas fijan las dos
    // mitades de esa decisión: que la app no lo manda y que lo que se enseña no
    // promete un número.
    testWidgets('el alta NO manda codigo: lo pone el servidor', (tester) async {
      final api = FakeProveedorApi();

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Pérez');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000001');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);

      // `proveedor.codigo` es único y la app solo ve una página de la lista, así
      // que no puede saber qué códigos hay. Si lo mandara, dos altas a la vez
      // pedirían el mismo número.
      expect(api.ultimoCuerpo, isNotNull);
      expect(api.ultimoCuerpo!.containsKey('codigo'), isFalse);
      expect(api.creados, hasLength(1));
    });

    testWidgets('el campo de codigo no se puede escribir', (tester) async {
      await tester.pumpWidget(montar(proveedores: FakeProveedorApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      // No es un `TextField` deshabilitado: es un campo que no es un campo. Un
      // input gris en un móvil parece un error, y aquí es una decisión.
      expect(find.text('Se genera al guardar'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lock), findsOneWidget);

      // Y desde luego no hay ningún campo de texto con el código: el DNI es el
      // tercero y el siguiente es el teléfono.
      expect(find.byType(CupertinoTextField), findsNWidgets(5));
    });

    testWidgets('al editar enseña el código real, también con candado', (tester) async {
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, nombre: 'Juan', apellido: 'Pérez', codigo: 'PROV-001'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(proveedoresControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Editar'));
      await pumpListo(tester);
      await pumpListo(tester);

      expect(find.text('PROV-001'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lock), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Juan Carlos');
      await tester.pump(const Duration(milliseconds: 300));
      await bajarHasta(tester, 'Guardar cambios');
      await tester.tap(find.text('Guardar cambios'));
      await pumpListo(tester);

      // Editar no lo cambia: la app no manda el código, así que el servidor lo
      // deja como estaba.
      expect(api.ultimoCuerpo!.containsKey('codigo'), isFalse);
    });

    testWidgets('el servidor genera el siguiente código libre', (tester) async {
      // El doble genera el código con el mismo algoritmo que
      // `ProveedorService._siguienteCodigo`. Si los dos se separaran, esta
      // prueba mediría el doble y no el servidor — y quien leyera el verde
      // creería que la app muestra `PROV-006` cuando en realidad muestra otra
      // cosa.
      final api = FakeProveedorApi(proveedores: [
        proveedorDePrueba(id: 1, codigo: 'PROV-001'),
        proveedorDePrueba(id: 2, codigo: 'PROV-002'),
      ]);

      await tester.pumpWidget(montar(proveedores: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Nuevo');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Proveedor');
      await tester.enterText(find.byType(CupertinoTextField).at(2), '70000003');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear proveedor');
      await tester.tap(find.text('Crear proveedor'));
      await pumpListo(tester);

      expect(find.text('PROV-003'), findsOneWidget);
    });

    testWidgets('en el alta avisa de que la foto se pone después', (tester) async {      await tester.pumpWidget(montar(proveedores: FakeProveedorApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Proveedores');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      // El aviso está al final del formulario, que es un `ListView`: solo se
      // construye lo que se ve. Hay que bajar hasta él.
      await bajarHasta(tester, 'Podrás añadir una foto');

      // Una foto necesita un registro al que colgarse, y en el alta todavía no
      // existe. Ofrecer el selector ahí sería prometer algo que no se puede
      // hacer.
      expect(find.textContaining('Podrás añadir una foto'), findsOneWidget);
    });
  });
}
