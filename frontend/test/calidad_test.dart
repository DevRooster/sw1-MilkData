// Pruebas del módulo Calidad.
//
// La mayoría de lo que se comprueba aquí sale de **una** regla: una recolección
// solo admite un análisis, porque `recoleccionId` es único en la base. Es la
// razón por la que este módulo existe como módulo aparte, y por la que su
// desplegable tiene que filtrar en vez de dejar que el servidor rechace.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/calidad/domain/control_calidad.dart';
import 'package:milkdata_app/features/calidad/presentation/lista_calidad_page.dart';
import 'package:milkdata_app/features/calidad/presentation/providers/calidad_controller.dart';
import 'package:milkdata_app/features/recolecciones/presentation/providers/recolecciones_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_calidad_api.dart';
import 'helpers/fake_recoleccion_api.dart';
import 'helpers/fake_token_storage.dart';

/// Monta la app entera con los dobles.
Widget montar({
  FakeCalidadApi? calidad,
  Permisos? permisos,
  List<ControlCalidad> controles = const <ControlCalidad>[],
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
      calidadApiProvider.overrideWithValue(calidad ?? FakeCalidadApi(controles: controles)),
      recoleccionApiProvider.overrideWithValue(FakeRecoleccionApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de calidad, con su propio contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeCalidadApi calidad) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      calidadApiProvider.overrideWithValue(calidad),
      recoleccionApiProvider.overrideWithValue(FakeRecoleccionApi()),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality`
      // ni tema, y la pantalla no construye.
      child: const CupertinoApp(home: CalidadPage()),
    ),
  );

  return contenedor;
}

/// Un laboratorio con todo: el caso normal de las pruebas que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'laboratorio',
      plantaId: 1,
      recursos: {
        'calidad': ['read', 'write'],
        'recolecciones': ['read'],
        'rutas': ['read'],
        'unidades': ['read'],
        'proveedores': ['read'],
      },
    );

Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Abre un módulo del lanzador, bajando hasta encontrarlo.
///
/// El lanzador es un `ListView`: solo construye lo que cabe en pantalla. Con nueve
/// módulos, Calidad queda por debajo del pliegue, y sin desplazarse no existe
/// para `find`. La prueba lo baja porque es lo que hace el usuario de verdad, en
/// vez de saltárselo con `skipOffstage`, que daría verde sin comprobar nada.
///
/// `hitTestable` y no `find` a secas: un `ListView` construye también lo que
/// queda fuera de pantalla, y `find` lo contaría como encontrado cuando en
/// realidad no se puede pulsar ahí.
Future<void> abrirModulo(WidgetTester tester, String titulo) async {
  for (var intento = 0; intento < 20; intento += 1) {
    final finder = find.text(titulo).hitTestable();

    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pump();
      // Abrir un módulo empuja una ruta con su transición, y la transición de
      // Cupertino dura 400 ms.
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
///
/// Para comprobar que algo **existe** en una lista más larga que la pantalla: el
/// `ListView` solo construye lo visible, así que un módulo que queda al final no
/// sale en `find` hasta que se desplaza.
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

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Calidad a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      // Calidad es el noveno módulo, así que hay que bajar: en el móvil tampoco
      // se ve sin desplazarse.
      await bajarHasta(tester, 'Calidad');
      expect(find.text('Calidad'), findsOneWidget);
    });

    testWidgets('no lo enseña a un recolector sin permiso de calidad', (tester) async {
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

      expect(find.text('Calidad'), findsNothing);
    });
  });

  group('la regla de una recolección, un análisis', () {
    // Esta es la prueba que justifica el módulo. Va contra el doble, que reparte
    // la misma regla que el servidor; comprobarla contra el servidor de verdad
    // está en las pruebas de integración del backend.
    testWidgets('no deja registrar dos análisis de la misma recolección', (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, recoleccionId: 4),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(calidadControllerProvider.notifier).crear(
        recoleccionId: 4,
        usuarioId: 1,
      );

      expect(ok, isFalse);
      // Y se sabe **por qué**: la recolección ocupada es la 4, no una cualquiera.
      expect(api.rechazadosPorUnico, contains(4));
      // El error queda en el estado para que la pantalla lo pueda enseñar en vez
      // de tragárselo.
      expect(contenedor.read(calidadControllerProvider).error, isNotNull);
    });

    testWidgets('sí deja analizar una recolección que está libre', (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, recoleccionId: 4),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor.read(calidadControllerProvider.notifier).crear(
        recoleccionId: 5,
        usuarioId: 1,
      );

      expect(ok, isTrue);
      expect(api.rechazadosPorUnico, isEmpty);
      expect(api.creados, hasLength(1));
    });

    testWidgets('tampoco deja mover un análisis a una recolección ocupada',
        (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, recoleccionId: 4),
        controlDePrueba(id: 2, recoleccionId: 7),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // El 2 está sobre la 7; moverlo a la 4, que ya tiene el 1, se rechaza.
      final ok = await contenedor
          .read(calidadControllerProvider.notifier)
          .editar(controlDePrueba(id: 2, recoleccionId: 7), recoleccionId: 4);

      expect(ok, isFalse);
      expect(api.rechazadosPorUnico, contains(4));
    });

    testWidgets('el desplegable solo ofrece recolecciones sin analizar', (tester) async {
      // La 1 y la 3 ya tienen análisis; la 2 no. El desplegable tiene que salir
      // solo con la 2, y esto es lo que evita el 400 del final del formulario.
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, recoleccionId: 1),
        controlDePrueba(id: 2, recoleccionId: 3),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final libres = await contenedor.read(recoleccionesParaAnalizarProvider.future);

      expect(libres.map((r) => r.id), isNot(contains(1)));
      expect(libres.map((r) => r.id), isNot(contains(3)));
      // Y la que sí está libre sale.
      expect(libres.map((r) => r.id), contains(2));
    });
  });

  group('el modelo', () {
    // Sin montar nada: la regla se lee de un vistazo y no está escondida en un
    // `build`.
    test('un control puro y uno adulterado se distinguen', () {
      expect(controlDePrueba(resultado: ControlCalidad.pura).esPura, isTrue);
      expect(controlDePrueba(resultado: ControlCalidad.pura).esAdulterada, isFalse);
      expect(
        controlDePrueba(resultado: ControlCalidad.adulterada).esAdulterada,
        isTrue,
      );
    });

    test('un veredicto sin mediciones se sabe, y se cuenta como cero', () {
      // Por defecto el doble de las pruebas no trae ninguna: es un caso real, no
      // una rareza de la prueba.
      final sinNada = controlDePrueba();
      expect(sinNada.tieneMedidas, isFalse);
      expect(sinNada.cuantasMedidas, 0);

      final conDos = controlDePrueba(grasa: 3.8, ph: 6.7);
      expect(conDos.tieneMedidas, isTrue);
      expect(conDos.cuantasMedidas, 2);
      // Y solo salen las que tienen valor, no las siete con huecos.
      expect(conDos.medidasInformativas.map((m) => m.key), ['Grasa', 'pH']);
    });

    test('los números se leen con coma y sin ceros de más', () {
      // La base devuelve 3.8000000001; en pantalla tiene que ser "3,8".
      expect(ControlCalidad.formatea(3.8), '3,8');
      expect(ControlCalidad.formatea(4.0), '4');
      expect(ControlCalidad.formatea(0.0), '0');
    });

    test('un resultado desconocido no rompe la pantalla', () {
      // Si el servidor añadiera un tercer veredicto mañana, la lista se sigue
      // viendo en vez de quedarse en blanco.
      final control = ControlCalidad.fromJson(const <String, dynamic>{
        'id': 1,
        'recoleccionId': 1,
        'usuarioId': 1,
        'resultado': 'NUEVO',
      });

      expect(control.esPura, isFalse);
      expect(control.esAdulterada, isFalse);
      // Y tampoco revienta al pedir las medidas.
      expect(control.medidas, hasLength(7));
    });
  });

  group('la lista de controles', () {
    testWidgets('enseña los controles con su veredicto', (tester) async {
      await tester.pumpWidget(montar(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.pura, grasa: 3.8, litros: 25),
        controlDePrueba(id: 2, resultado: ControlCalidad.adulterada, aguaAnadida: 0.4),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Calidad');

      expect(find.text('pura'), findsOneWidget);
      expect(find.text('adulterada'), findsOneWidget);
      // Con litros: "25 L · recolección del 2026-10-13".
      expect(find.textContaining('25 L'), findsOneWidget);
    });

    testWidgets('avisa de un veredicto sin mediciones', (tester) async {
      await tester.pumpWidget(montar(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.pura),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Calidad');

      // Siete campos en blanco parecerían un fallo de la pantalla; el aviso dice
      // que es que así se guardó.
      expect(find.textContaining('Sin mediciones'), findsOneWidget);
    });

    testWidgets('el filtro viaja como el texto del ENUM, no como el de Dart',
        (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.pura),
        controlDePrueba(id: 2, resultado: ControlCalidad.adulterada),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(calidadControllerProvider.notifier)
          .filtrarPorResultado(ControlCalidad.adulterada);
      await pumpListo(tester);

      // `adulterada`, el valor del ENUM de la base. No `esAdulterada`, que es el
      // getter de la app y el servidor no lo conoce.
      expect(api.ultimaConsulta?.resultado, 'adulterada');
    });

    testWidgets('volver a "todas" quita el filtro', (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.pura),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final controller = contenedor.read(calidadControllerProvider.notifier);

      await controller.filtrarPorResultado(ControlCalidad.adulterada);
      await pumpListo(tester);
      expect(api.ultimaConsulta?.resultado, 'adulterada');

      // El `null` de "todas" tiene que llegar de verdad: si no, el filtro se
      // queda puesto y la lista parece vacía sin explicación.
      await controller.filtrarPorResultado(null);
      await pumpListo(tester);
      expect(api.ultimaConsulta?.resultado, isNull);
    });

    testWidgets('avisa si no hay análisis o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);
      await abrirModulo(tester, 'Calidad');

      expect(find.textContaining('Todavía no se ha analizado'), findsOneWidget);
    });

    testWidgets('el resumen cuenta los adulterados de ESTA página', (tester) async {
      await tester.pumpWidget(montar(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.adulterada),
        controlDePrueba(id: 2, resultado: ControlCalidad.adulterada),
        controlDePrueba(id: 3, resultado: ControlCalidad.pura),
      ]));
      await pumpListo(tester);
      await abrirModulo(tester, 'Calidad');

      // El resumen es el último elemento de la lista, así que también queda por
      // debajo del pliegue con solo tres filas.
      await bajarHasta(tester, 'adulterados en esta página');
      expect(find.textContaining('2 de 3 adulterados en esta página'), findsOneWidget);
    });
  });

  group('borrar', () {
    testWidgets('elimina y descuenta del resumen', (tester) async {
      final api = FakeCalidadApi(controles: [
        controlDePrueba(id: 1, resultado: ControlCalidad.adulterada),
        controlDePrueba(id: 2, resultado: ControlCalidad.pura),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      expect(contenedor.read(calidadControllerProvider).adulterados, 1);

      await contenedor
          .read(calidadControllerProvider.notifier)
          .eliminar(controlDePrueba(id: 1, resultado: ControlCalidad.adulterada));
      await pumpListo(tester);

      expect(api.eliminados, [1]);
      // Si el contador no bajara, el resumen daría un adulterado que ya no está.
      expect(contenedor.read(calidadControllerProvider).adulterados, 0);
      expect(contenedor.read(calidadControllerProvider).controles, hasLength(1));
    });
  });
}
