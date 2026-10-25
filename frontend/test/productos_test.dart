// Pruebas del módulo Productos y del lanzador que lo ofrece.
//
// Este módulo es el primero que usa `SelectorImagen`, que llevaba tiempo escrito
// sin ninguna pantalla que lo llamara. Lo que se comprueba aquí es que aparece
// donde toca y que no rompe el formulario, no la subida de archivos: eso lo
// cubren las pruebas del módulo de imágenes.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/productos/presentation/lista_productos_page.dart';
import 'package:milkdata_app/features/productos/presentation/providers/productos_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_producto_api.dart';
import 'helpers/fake_token_storage.dart';

/// Monta la app con los dobles, incluido el de productos.
///
/// El `FakeAuthApi` se crea aquí con una sesión de ejemplo: sin ella la app se
/// queda en el login y no hay lanzador que probar.
Widget montar({
  FakeProductoApi? productos,
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
      productoApiProvider.overrideWithValue(productos ?? FakeProductoApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de productos, con su propio contenedor de providers.
///
/// Permite hablar con el controlador desde el propio test, sin pasar por un
/// gesto: la rueda del selector no es determinista en pruebas y lo que importa
/// es qué llega al servidor, no cómo se escogió la opción.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeProductoApi productos) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      productoApiProvider.overrideWithValue(productos),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: ProductosPage()),
    ),
  );

  return contenedor;
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'productos': ['read', 'write'],
        'unidades': ['read', 'write'],
        'usuarios': ['read', 'write'],
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
    testWidgets('enseña Productos a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      expect(find.text('Productos'), findsOneWidget);
    });

    testWidgets('no lo enseña a un acopiador', (tester) async {
      // Sale de la matriz real: `acopiador` no tiene `productos`, así que la
      // API le respondería 403. Aparecerle en el menú sería tocar algo y
      // descubrirlo ahí.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'acopiador',
          plantaId: 1,
          recursos: {
            'recorridos': ['read', 'write'],
            'recolecciones': ['read', 'write'],
          },
        ),
      ));
      await pumpListo(tester);

      expect(find.text('Productos'), findsNothing);
    });
  });

  group('la lista de productos', () {
    testWidgets('enseña los productos que devuelve la API', (tester) async {
      await tester.pumpWidget(montar(
        productos: FakeProductoApi(productos: [
          productoDePrueba(id: 1, nombre: 'Yogurt natural 1 L'),
          productoDePrueba(id: 2, nombre: 'Queso fresco', unidadMedida: 'kilo', precioVenta: 12.5),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      expect(find.text('Yogurt natural 1 L'), findsOneWidget);
      expect(find.text('Queso fresco'), findsOneWidget);
    });

    testWidgets('el precio se muestra con coma y no con punto', (tester) async {
      await tester.pumpWidget(montar(
        productos: FakeProductoApi(productos: [
          productoDePrueba(id: 1, precioVenta: 12.5),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      // Viene de un DECIMAL(10,2) en MySQL y se muestra como 12,50. Con punto
      // se lee como un millar o como un número de otra cosa.
      expect(find.textContaining('12,50'), findsOneWidget);
    });

    testWidgets('la búsqueda viaja al servidor y la X la quita', (tester) async {
      final api = FakeProductoApi(productos: [
        productoDePrueba(id: 1, nombre: 'Yogurt natural', descripcion: 'de leche fresca'),
        productoDePrueba(id: 2, nombre: 'Queso', descripcion: 'curado'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
      expect(find.text('Yogurt natural'), findsOneWidget);
      expect(find.text('Queso'), findsOneWidget);

      // La búsqueda llega al servidor: si se filtrara en la pantalla, la lista
      // mentiría sobre lo que devuelve la API.
      await contenedor.read(productosControllerProvider.notifier).buscar('fresca');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, 'fresca');
      expect(find.text('Yogurt natural'), findsOneWidget);
      expect(find.text('Queso'), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill).first);
      await pumpListo(tester);

      expect(api.ultimaConsulta?.busqueda, isNull);
      expect(find.text('Queso'), findsOneWidget);
    });

    testWidgets('el filtro por unidad y el de inactivos viajan al servidor', (tester) async {
      final api = FakeProductoApi(productos: [
        productoDePrueba(id: 1, nombre: 'Yogurt', unidadMedida: 'unidad'),
        productoDePrueba(id: 2, nombre: 'Queso', unidadMedida: 'kilo'),
        productoDePrueba(id: 3, nombre: 'Retirado', unidadMedida: 'unidad', estado: false),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(productosControllerProvider.notifier)
          .filtrarPorUnidad('kilo');
      await pumpListo(tester);

      expect(api.ultimaConsulta?.unidadMedida, 'kilo');
      expect(find.text('Queso'), findsOneWidget);
      expect(find.text('Yogurt'), findsNothing);

      await contenedor.read(productosControllerProvider.notifier).alternarSoloInactivos();
      await pumpListo(tester);

      expect(api.ultimaConsulta?.estado, isFalse);
    });

    testWidgets('avisa distinto si no hay productos o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(productos: FakeProductoApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      expect(find.text('Esta planta todavía no tiene productos.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).first, 'zzz');
      await pumpListo(tester);

      expect(find.text('Ningún producto coincide con el filtro.'), findsOneWidget);
    });
  });

  group('el formulario de productos', () {
    testWidgets('no deja guardar sin nombre ni precio', (tester) async {
      final api = FakeProductoApi();

      await tester.pumpWidget(montar(productos: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await bajarHasta(tester, 'Crear producto');
      await tester.tap(find.text('Crear producto'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('Ponle un nombre al producto.'), findsOneWidget);
      expect(find.text('Indica el precio de venta.'), findsOneWidget);
      // No se llegó a llamar a la API: la validación es de cliente y el error
      // va junto al campo, no en un aviso arriba.
      expect(api.creados, isEmpty);
    });

    testWidgets('rechaza un precio que no es un número', (tester) async {
      final api = FakeProductoApi();

      await tester.pumpWidget(montar(productos: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Yogurt');
      await tester.enterText(find.byType(CupertinoTextField).at(3), 'mucho');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear producto');
      await tester.tap(find.text('Crear producto'));
      await pumpListo(tester);
      await irAlPrincipio(tester);

      expect(find.text('Eso no es un número.'), findsOneWidget);
      expect(api.creados, isEmpty);
    });

    testWidgets('crea el producto con lo que se escribió', (tester) async {
      final api = FakeProductoApi();

      await tester.pumpWidget(montar(productos: api));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Yogurt natural 1 L');
      // El precio es el cuarto campo y se escribe con coma, que es como se leen los precios, y el
      // formulario tiene que entenderlo igual.
      await tester.enterText(find.byType(CupertinoTextField).at(3), '3,75');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear producto');
      await tester.tap(find.text('Crear producto'));
      await pumpListo(tester);

      expect(api.creados, hasLength(1));
      expect(find.text('Yogurt natural 1 L'), findsOneWidget);
    });

    testWidgets('en el alta avisa de que la imagen se pone después', (tester) async {
      await tester.pumpWidget(montar(productos: FakeProductoApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Productos');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await pumpListo(tester);

      // Una imagen necesita un producto al que colgarse, y en el alta no existe
      // todavía. Ofrecer el selector ahí sería prometer algo que no se puede
      // hacer.
      expect(
        find.textContaining('Podrás añadir una imagen'),
        findsOneWidget,
      );
    });
  });
}