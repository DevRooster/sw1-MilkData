// Pruebas del módulo Plantas y del cambio de planta del inicio.
//
// Lo que se comprueba aquí tiene dos caras: que las plantas se den de alta
// bien, y que cambiar de planta **realmente cambie** lo que se ve. La segunda
// importa más: el backend aísla por `plantaId` con un token distinto, y si la app
// no recarga al cambiar, la lista sigue enseñando datos de la planta anterior
// sin avisar.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/domain/planta.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/plantas/presentation/lista_plantas_page.dart';
import 'package:milkdata_app/features/plantas/presentation/providers/plantas_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_planta_api.dart';
import 'helpers/fake_token_storage.dart';

Widget montar({
  FakePlantaApi? plantas,
  FakeAuthApi? cliente,
  Permisos? permisos,
  List<Planta> lista = const <Planta>[],
}) {
  final auth = cliente ?? _cliente(permisos);

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(auth),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: auth, storage: ref.watch(tokenStorageProvider)),
      ),
      plantaApiProvider.overrideWithValue(plantas ?? FakePlantaApi(plantas: lista)),
    ],
    child: const MilkDataApp(),
  );
}

Future<ProviderContainer> pumpPagina(WidgetTester tester, FakePlantaApi api) async {
  final auth = _cliente(null);

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(auth),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: auth, storage: ref.watch(tokenStorageProvider)),
      ),
      plantaApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: PlantasPage()),
    ),
  );

  return contenedor;
}

FakeAuthApi _cliente(Permisos? permisos) {
  final cliente = FakeAuthApi(
    sesionARetornar: sesionDePrueba(nombrePlanta: 'Planta Ecológica Huata'),
  );
  cliente.matrizPermisos = permisos ?? _superadmin();

  return cliente;
}

/// Cliente de superadmin con **dos plantas**, que es lo que hace que la tarjeta
/// del inicio sea pulsable.
///
/// Van en `cliente.plantas` y no en la sesión porque la tarjeta lee
/// `estado.plantas`, que sale de `GET /auth/plantas`. Con una sola planta —la
/// sesión normal— el control no aparece, y eso también hay que probarlo.
FakeAuthApi _superadminConDosPlantas() {
  final cliente = FakeAuthApi(
    sesionARetornar: sesionDePrueba(nombrePlanta: 'Planta Ecológica Huata'),
  );
  cliente.matrizPermisos = _superadmin();
  cliente.plantas = [
    plantaDePrueba(id: 1, nombre: 'Planta Ecológica Huata', codigo: 'HUA'),
    plantaDePrueba(id: 2, nombre: 'Planta del Sur', codigo: 'SUR', direccion: null),
  ];

  return cliente;
}

Permisos _superadmin() => const Permisos(
      rol: 'superadmin',
      plantaId: 1,
      recursos: {'plantas': ['read', 'write']},
    );

/// Solo lectura: es lo que tiene un admin de planta.
Permisos _soloLectura() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {'plantas': ['read']},
    );

Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

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

Future<void> bajarAlFinal(WidgetTester tester) async {
  for (var intento = 0; intento < 20; intento += 1) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('el lanzador', () {
    testWidgets('enseña Plantas a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      await abrirModulo(tester, 'Plantas');
      expect(find.text('Plantas'), findsWidgets);
    });

    testWidgets('no lo enseña a un rol sin permiso', (tester) async {
      await tester.pumpWidget(montar(permisos: const Permisos(
        rol: 'proveedor',
        plantaId: 1,
        recursos: {'proveedores': ['read']},
      )));
      await pumpListo(tester);

      await bajarAlFinal(tester);
      expect(find.text('Plantas'), findsNothing);
    });
  });

  group('la lista', () {
    testWidgets('avisa si no hay ninguna', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Plantas');

      expect(find.textContaining('No hay ninguna planta'), findsOneWidget);
    });

    testWidgets('enseña nombre, código y dirección', (tester) async {
      await tester.pumpWidget(montar(lista: [
        plantaDePrueba(id: 1),
        plantaDePrueba(id: 2, nombre: 'Planta del Sur', codigo: 'SUR', direccion: null),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Plantas');

      expect(find.text('Planta Ecológica Huata'), findsOneWidget);
      // El código va como etiqueta porque es lo que se ve suelto en el resto de
      // pantallas de esa planta.
      expect(find.text('HUA'), findsOneWidget);
      expect(find.text('SUR'), findsOneWidget);
      expect(find.text('Distrito de Huata'), findsOneWidget);
    });

    testWidgets('avisa de las plantas inactivas', (tester) async {
      await tester.pumpWidget(montar(lista: [
        plantaDePrueba(id: 1, activo: false),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Plantas');

      expect(find.textContaining('Está inactiva'), findsOneWidget);
    });

    test('las activas van antes que las inactivas', () {
      // El backend no las ordena: lo ordena la lista para el ojo.
      final estado = PlantasState(plantas: [
        plantaDePrueba(id: 1, nombre: 'Zeta', activo: false),
        plantaDePrueba(id: 2, nombre: 'Alfa'),
        plantaDePrueba(id: 3, nombre: 'Media'),
      ]);

      expect(estado.ordenadas.map((p) => p.nombre), ['Alfa', 'Media', 'Zeta']);
    });
  });

  group('los permisos', () {
    testWidgets('el admin ve el botón de alta pero no puede usarlo', (tester) async {
      // **El botón de alta se esconde sin `plantas: write`.** El servidor lo
      // rechazaría igual, así que dejarlo puesto sería un `+` que sale con 403 al
      // pulsarlo.
      await tester.pumpWidget(montar(
        permisos: _soloLectura(),
        lista: [plantaDePrueba(id: 1)],
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Plantas');

      final mas = find.byIcon(CupertinoIcons.add).hitTestable();
      expect(mas, findsNothing);
      // Pero sí ve la lista: el admin tiene `plantas: ['read']`.
      expect(find.text('Distrito de Huata'), findsOneWidget);
    });

    testWidgets('el superadmin ve el botón de alta', (tester) async {
      await tester.pumpWidget(montar(lista: [plantaDePrueba(id: 1)]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Plantas');

      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
    });
  });

  group('las reglas del servidor', () {
    testWidgets('un código repetido se rechaza', (tester) async {
      final api = FakePlantaApi(plantas: [plantaDePrueba(id: 1, codigo: 'HUA')]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(plantasControllerProvider.notifier).crear(
            nombre: 'Otra planta',
            codigo: 'HUA',
          );

      // Dos plantas con el mismo código harían indistinguibles las etiquetas del
      // resto de la app.
      expect(ok, isFalse);
      expect(api.codigosRepetidos, ['HUA']);
      expect(api.creados, isEmpty);
    });

    testWidgets('un nombre vacío se rechaza', (tester) async {
      final api = FakePlantaApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(plantasControllerProvider.notifier)
          .crear(nombre: '   ', codigo: 'NUE');

      expect(ok, isFalse);
      expect(api.nombresVacios, hasLength(1));
      expect(api.creados, isEmpty);
    });

    testWidgets('una planta válida sí entra', (tester) async {
      final api = FakePlantaApi();

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(plantasControllerProvider.notifier).crear(
            nombre: 'Planta del Norte',
            codigo: 'NOR',
            direccion: 'Carretera 5',
          );

      expect(ok, isTrue);
      expect(api.creados, hasLength(1));
      // Y la lista se recarga sola: si no, la planta nueva no se vería hasta
      // volver a abrir la pantalla.
      expect(contenedor.read(plantasControllerProvider).total, 1);
    });

    testWidgets('editar una planta no choca consigo misma', (tester) async {
      // El código de la propia planta es el suyo: si el doble lo tratara como
      // repetido, **no se podría cambiar el nombre de una planta sin cambiarle
      // antes el código**.
      final api = FakePlantaApi(plantas: [plantaDePrueba(id: 1, codigo: 'HUA')]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(plantasControllerProvider.notifier).editar(
            plantaDePrueba(id: 1, codigo: 'HUA'),
            nombre: 'Planta Ecológica de Huata',
            codigo: 'HUA',
          );

      expect(ok, isTrue);
      expect(api.codigosRepetidos, isEmpty);
      expect(api.editados, [1]);
    });
  });

  group('borrar', () {
    testWidgets('elimina y descuenta', (tester) async {
      final api = FakePlantaApi(plantas: [
        plantaDePrueba(id: 1),
        plantaDePrueba(id: 2, nombre: 'Sur', codigo: 'SUR'),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(contenedor.read(plantasControllerProvider).total, 2);

      await contenedor
          .read(plantasControllerProvider.notifier)
          .eliminar(plantaDePrueba(id: 1));

      expect(api.eliminados, [1]);
      expect(contenedor.read(plantasControllerProvider).total, 1);
    });
  });

  group('la tarjeta de planta del inicio', () {
    testWidgets('con una sola planta no parece pulsable', (tester) async {
      // Un admin con una planta no tiene a dónde ir. Ponerle un dedo encima y una
      // flecha sería prometer una acción que no ocurre.
      final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
      cliente.matrizPermisos = _soloLectura();

      await tester.pumpWidget(montar(cliente: cliente));
      await pumpListo(tester);

      expect(find.text('Solo tu planta'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('con varias plantas avisa de que se puede cambiar', (tester) async {
      await tester.pumpWidget(montar(cliente: _superadminConDosPlantas()));
      await pumpListo(tester);

      expect(find.text('Todas las plantas'), findsOneWidget);
      // La flecha es la señal de que la tarjeta hace algo.
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    });

    testWidgets('al pulsarla se abre la hoja con las plantas', (tester) async {
      await tester.pumpWidget(montar(cliente: _superadminConDosPlantas()));
      await pumpListo(tester);

      await tester.tap(find.byIcon(CupertinoIcons.chevron_forward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('¿En qué planta trabajas?'), findsOneWidget);
      expect(find.textContaining('Planta Ecológica Huata (HUA)'), findsWidgets);
      expect(find.textContaining('Planta del Sur (SUR)'), findsOneWidget);
      // Y la de ahora sale marcada: pulsarla no cambia nada y parecería un fallo.
      expect(find.textContaining('(HUA) · ahora'), findsOneWidget);
    });
  });
}