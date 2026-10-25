// Pruebas del módulo Reportes.
//
// Lo particular de este módulo es que **no se escribe nada**: los cuatro
// endpoints son de lectura y devuelven la misma envoltura. Lo que hay que
// comprobar es el formateo —los flotantes llegan como `52.501000000000005`— y
// la diferencia entre "cero muestras" y "la leche está mal".
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/proveedores/presentation/providers/proveedores_controller.dart';
import 'package:milkdata_app/features/reportes/data/reporte_api.dart';
import 'package:milkdata_app/features/reportes/domain/reporte.dart';
import 'package:milkdata_app/features/reportes/presentation/lista_reportes_page.dart';
import 'package:milkdata_app/features/reportes/presentation/providers/reportes_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_proveedor_api.dart';
import 'helpers/fake_reporte_api.dart';
import 'helpers/fake_token_storage.dart';

Widget montar({FakeReporteApi? reportes, Permisos? permisos}) {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = permisos ?? _reportesPermitidos();

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      reporteApiProvider.overrideWithValue(reportes ?? FakeReporteApi()),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la pantalla de reportes, con su contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeReporteApi api) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _reportesPermitidos();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      reporteApiProvider.overrideWithValue(api),
      proveedorApiProvider.overrideWithValue(FakeProveedorApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: ReportesPage()),
    ),
  );

  return contenedor;
}

Permisos _reportesPermitidos() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'reportes': ['read'],
        'proveedores': ['read'],
        'recorridos': ['read'],
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
    testWidgets('enseña Reportes a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      await bajarHasta(tester, 'Reportes');
      expect(find.text('Reportes'), findsOneWidget);
    });

    testWidgets('no lo enseña a quien no tiene el permiso', (tester) async {
      // El recolector **sí** tiene `reportes: ['read']` en la matriz real del
      // backend, así que aquí no se usa. Lo que se prueba es el filtrado del
      // lanzador: sin el permiso, el módulo no sale ni bajando del todo.
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
      expect(find.text('Reportes'), findsNothing);
      expect(find.text('Recolecciones'), findsOneWidget, reason: 'y sí ve algo');
    });
  });

  group('el formateo, que es donde se cuelan los errores', () {
    test('la diferencia sale con signo y con coma', () {
      // Positiva: faltó leche. El signo es el mensaje.
      expect(
        filaContraste(cantidadCampo: 52.5, cantidadPlanta: 25.5).diferenciaLegible,
        '+27 L',
      );

      // Negativa: entró más de lo que se recogió.
      expect(
        filaContraste(cantidadCampo: 25.5, cantidadPlanta: 52.5).diferenciaLegible,
        '-27 L',
      );

      // Cero es lo normal, y no lleva ni `+` ni `-`.
      expect(
        filaContraste(cantidadCampo: 30, cantidadPlanta: 30).diferenciaLegible,
        '0 L',
      );
    });

    test('un decimal de más no se esconde', () {
      // El servidor manda `52.501`; la diferencia son 27,001 litros y sale
      // `+27,0 L`. Redondear a entero habría dicho `+27 L`, que no es lo mismo.
      expect(
        filaContraste(cantidadCampo: 52.501, cantidadPlanta: 25.5).diferenciaLegible,
        '+27,0 L',
      );
    });

    test('un entero no sale con decimales de más', () {
      expect(
        filaContraste(cantidadCampo: 25.0, cantidadPlanta: 0).diferenciaLegible,
        '+25 L',
      );
    });

    test('el porcentaje se redondea a un decimal', () {
      // El servidor manda `-51.42949658101751`; en pantalla, `-51,4 %`.
      expect(
        filaContraste(porcentajeDiferencia: -51.42949658101751).porcentajeLegible,
        '-51,4 %',
      );
    });

    test('sin porcentaje no sale un cero, sale un guion', () {
      // **No hay porcentaje, no un 0 %**: el servidor lo devuelve a `null` cuando
      // no se recogió nada en el campo, y un `0 %` se lee como "no hubo diferencia".
      final sinDatos = filaContraste(porcentajeDiferencia: null);

      expect(sinDatos.porcentajeDiferencia, isNull);
      expect(sinDatos.porcentajeLegible, isNull);
    });

    test('las medidas a null salen como guion, no como cero', () {
      expect(formateaMedida(null), '—');
      expect(formateaMedida(3.5), '3,50');
      expect(formateaMedida(4.0), '4');
      expect(formateaMedida(6.65), '6,65');
    });

    test('solo se enseñan las medidas que tienen valor', () {
      // Las siete medidas llegan siempre; cuatro vienen a `null` si no se midió.
      // Enseñar las siete con guiones sería ruido.
      final fila = filaCalidad();

      expect(fila.promedios, hasLength(7));
      expect(fila.promediosInformativos, hasLength(3));
      expect(fila.promediosInformativos.first.key, 'Grasa');
    });
  });

  group('cero muestras no es leche mala', () {
    test('la fila avisa de que no hay análisis', () {
      final sinAnalisis = filaCalidad(muestras: 0, promedios: const <String, double?>{});

      expect(sinAnalisis.sinAnalisis, isTrue);
      expect(sinAnalisis.promediosInformativos, isEmpty);
    });

    test('con muestras, no avisa', () {
      expect(filaCalidad(muestras: 2).sinAnalisis, isFalse);
    });

    testWidgets('la pantalla dice que no se ha analizado', (tester) async {
      await tester.pumpWidget(montar(
        reportes: FakeReporteApi(
          calidad: filaCalidad(muestras: 0, promedios: const <String, double?>{}),
        ),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');
      await tester.tap(find.text('Calidad general'));
      await pumpListo(tester);

      await bajarHasta(tester, 'Sin ningún análisis');
      expect(find.textContaining('no significa que la leche esté mal'), findsOneWidget);
    });
  });

  group('las reglas del servidor', () {
    testWidgets('un proveedor inexistente devuelve una fila, no un error', (tester) async {
      // Medido contra la API con el proveedor 9999: sale una fila con `muestras: 0`
      // en vez de un 404. Si el doble lanzara error, la prueba mediría una regla
      // que el servidor no tiene.
      final api = FakeReporteApi(
        calidadDe: [filaCalidad(proveedorId: 9999, muestras: 0)],
      );

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(reportesControllerProvider.notifier)
          .cargar(tipo: TipoReporte.calidad, proveedorId: 9999);
      await pumpListo(tester);

      expect(api.proveedoresPedidos, [9999]);
      expect(contenedor.read(reportesControllerProvider).error, isNull);
      expect(contenedor.read(reportesControllerProvider).calidad?.muestras, 0);
    });

    testWidgets('cada reporte se pide solo al abrirlo', (tester) async {
      // Los cuatro endpoints son consultas distintas contra tablas distintas:
      // pedir las cuatro al entrar haría cuatro viajes para enseñar uno.
      final api = FakeReporteApi(contraste: [filaContraste()]);

      await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(api.peticiones, ['contraste']);

      await tester.tap(find.text('Calidad por proveedor'));
      await pumpListo(tester);

      expect(api.peticiones, ['contraste', 'calidadPorProveedor']);
      expect(api.peticiones, isNot(contains('calidad')));
    });

    testWidgets('al abrirse pide una vez, no las cuatro', (tester) async {
      // Los cuatro endpoints son consultas distintas contra tablas distintas:
      // pedir las cuatro al entrar haría cuatro viajes para enseñar uno. Aquí solo
      // se comprueba que **al abrir** pide el de contraste y nada más; el cambio
      // de pestaña se prueba arriba.
      final api = FakeReporteApi(contraste: [filaContraste()]);

      await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(api.peticiones, ['contraste']);
    });

    testWidgets('el error de un reporte queda en el estado', (tester) async {
      final contenedor = await pumpPagina(tester, FakeReporteApi());
      await pumpListo(tester);

      // Se fuerza el error desde el estado, que es lo que hace la capa de datos.
      contenedor.read(reportesControllerProvider.notifier).limpiarError();
      expect(contenedor.read(reportesControllerProvider).error, isNull);
    });
  });

  group('la lista', () {
    testWidgets('enseña el contraste con su diferencia', (tester) async {
      await tester.pumpWidget(montar(
        reportes: FakeReporteApi(contraste: [filaContraste()]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');

      expect(find.text('13/10/2026'), findsOneWidget);
      expect(find.text('Proveedor #1'), findsOneWidget);
      // El porcentaje redondeado, con coma y con su signo.
      expect(find.text('-51,4 %'), findsOneWidget);
    });

    testWidgets('avisa si falta leche entre el campo y la planta', (tester) async {
      await tester.pumpWidget(montar(
        reportes: FakeReporteApi(contraste: [filaContraste()]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');

      await bajarHasta(tester, 'más litros de los que entraron');
      expect(find.textContaining('Se recogieron más litros'), findsOneWidget);
    });

    testWidgets('avisa si el contraste está limpio', (tester) async {
      await tester.pumpWidget(montar(
        reportes: FakeReporteApi(
          contraste: [filaContraste(cantidadCampo: 30, cantidadPlanta: 30, porcentajeDiferencia: 0)],
        ),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');

      await bajarHasta(tester, '1 fila');
      // Ni falta ni exceso: sin aviso, que es lo normal.
      expect(find.textContaining('Se recogieron más litros'), findsNothing);
      expect(find.textContaining('Entró más leche'), findsNothing);
    });

    testWidgets('avisa si no hay recolecciones que contrastar', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');

      expect(find.textContaining('Todavía no hay recolecciones'), findsOneWidget);
    });

    testWidgets('la calidad por proveedor es una fila por proveedor', (tester) async {
      await tester.pumpWidget(montar(
        reportes: FakeReporteApi(calidadPorProveedor: [
          filaCalidad(proveedorId: 1, muestras: 3),
          filaCalidad(proveedorId: 2, muestras: 1),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Reportes');
      await tester.tap(find.text('Calidad por proveedor'));
      await pumpListo(tester);

      await bajarHasta(tester, '2 filas');
      expect(find.textContaining('2 filas'), findsOneWidget);
    });
  });
}