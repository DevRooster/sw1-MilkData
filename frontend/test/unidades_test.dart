// Pruebas del módulo Unidades y del lanzador que lo ofrece.
//
// El lanzador es la pieza que más puede mentir: si enseña un módulo que la API
// va a rechazar con 403, el usuario toca y se le dice que no. Por eso aquí se
// prueba, para cada rol, que lo que se ve y lo que la API dejaría abierto
// coinciden.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/unidades/domain/unidad.dart';
import 'package:milkdata_app/features/unidades/presentation/lista_unidades_page.dart';
import 'package:milkdata_app/features/unidades/presentation/providers/unidades_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_token_storage.dart';
import 'helpers/fake_unidad_api.dart';

/// Monta la app con los dobles, incluido el de unidades.
///
/// El `FakeAuthApi` se crea aquí con una sesión de ejemplo: sin ella la app se
/// queda en el login y no hay lanzador que probar.
Widget montar({
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
      unidadApiProvider.overrideWithValue(unidades ?? FakeUnidadApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'unidades': ['read', 'write'],
        'usuarios': ['read', 'write'],
      },
    );

/// Un laboratorio: lee calidad y no toca unidades.
///
/// Sale de la matriz real, no de un invento: `laboratorio` no tiene `unidades` en
/// `role-permissions.config`, así que la API le respondería 403.
Permisos _laboratorio() => const Permisos(
      rol: 'laboratorio',
      plantaId: 1,
      recursos: {
        'calidad': ['read', 'write'],
        'recolecciones': ['read'],
      },
    );

/// Deja que la app termine de cargar la sesión y los permisos.
Future<void> entrar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Abre un módulo desde el lanzador.
///
/// 600 ms y no 400: abrir un módulo empuja una ruta con su transición, y la
/// transición de Cupertino dura justo 400 ms. Con 400, el toque siguiente podía
/// caer con la pantalla todavía moviéndose.
Future<void> abrirModulo(WidgetTester tester, String titulo) async {
  await tester.tap(find.text(titulo));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Unidades a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await entrar(tester);

      expect(find.text('Unidades'), findsOneWidget);
    });

    testWidgets('no enseña Unidades a un laboratorio', (tester) async {
      // El módulo no aparece. No es que falle al abrirlo: es que no hay nada
      // que abrir, porque la API tampoco lo dejaría.
      await tester.pumpWidget(montar(permisos: _laboratorio()));
      await entrar(tester);

      expect(find.text('Unidades'), findsNothing);
      // El título de sección se pinta en mayúsculas.
      expect(find.text('MÓDULOS'), findsOneWidget);
    });

    testWidgets('cada módulo se decide por separado', (tester) async {
      // Este rol lee unidades pero no usuarios. Que aparezcan o no los dos no es
      // cosa del mismo botón.
      await tester.pumpWidget(montar(
        permisos: const Permisos(
          rol: 'operador',
          plantaId: 1,
          recursos: {
            'unidades': ['read'],
            'calidad': ['read', 'write'],
          },
        ),
      ));
      await entrar(tester);

      expect(find.text('Unidades'), findsOneWidget);
      expect(find.text('Usuarios'), findsNothing);
    });

    testWidgets('un rol que solo lee no ve el botón de alta', (tester) async {
      await tester.pumpWidget(montar(
        unidades: FakeUnidadApi(unidades: [unidadDePrueba()]),
        permisos: const Permisos(
          rol: 'operador',
          plantaId: 1,
          recursos: {
            'unidades': ['read'],
          },
        ),
      ));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      expect(find.text('Unidad Furgón 01'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.add), findsNothing);
    });
  });

  group('la lista de unidades', () {
    testWidgets('enseña las unidades que devuelve la API', (tester) async {
      await tester.pumpWidget(montar(
        unidades: FakeUnidadApi(unidades: [
          unidadDePrueba(id: 1, nombre: 'Unidad Furgón 01'),
          unidadDePrueba(id: 2, nombre: 'Unidad Motocarga 07', tipo: 'motocarga', capacidad: 300),
        ]),
      ));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      expect(find.text('Unidad Furgón 01'), findsOneWidget);
      expect(find.text('Unidad Motocarga 07'), findsOneWidget);
    });

    testWidgets('el selector de tipo ofrece Todos como opción de verdad', (tester) async {
      await tester.pumpWidget(montar(
        unidades: FakeUnidadApi(unidades: [unidadDePrueba()]),
      ));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      await tester.tap(find.text('Todos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Si "Todos" solo fuera el texto que se ve sin selección, y no una opción
      // de la hoja, en cuanto se eligiera un tipo el filtro sería una puerta de
      // sentido único. Es la razón de que el filtro por rol estuviera atascado.
      // "Todos" sale dos veces en pantalla: en el campo, que muestra lo elegido, y en
      // la hoja, que es lo que importa aquí. Por eso se busca solo dentro de la
      // rueda.
      final rueda = find.byType(CupertinoPicker);
      expect(find.descendant(of: rueda, matching: find.text('Todos')), findsOneWidget);
      expect(find.descendant(of: rueda, matching: find.text('Furgón')), findsOneWidget);
      expect(find.descendant(of: rueda, matching: find.text('Motocarga')), findsOneWidget);
    });

    testWidgets('el filtro por tipo quita filas y la X lo deshace', (tester) async {
      final api = FakeUnidadApi(unidades: [
        unidadDePrueba(id: 1, nombre: 'Furgón 01'),
        unidadDePrueba(id: 2, nombre: 'Motocarga 07', tipo: 'motocarga', capacidad: 300),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // Sin filtro no hay X: un botón de limpiar que no limpia nada.
      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
      expect(find.text('Furgón 01'), findsOneWidget);
      expect(find.text('Motocarga 07'), findsOneWidget);

      // El filtro lo pone el controlador. Se hace así y no arrastrando la rueda
      // porque la rueda del `CupertinoPicker` asienta por física y en una prueba
      // depende de cómo se reparta el movimiento: el mismo arrastre puede dejar
      // la opción en un sitio o en otro. Lo que importa aquí es que el filtro
      // llegue al servidor y que la X lo quite, y eso no cambia por cómo se
      // seleccionó la opción.
      await contenedor.read(unidadesControllerProvider.notifier)
          .filtrarPorTipo(TipoUnidad.motocarga);
      await pumpListo(tester);

      // Viaja como parámetro y no se aplica en la pantalla: si se filtrara aquí,
      // la lista mentiría sobre lo que devuelve el servidor.
      expect(api.ultimaConsulta?.tipo, 'motocarga');
      expect(find.text('Motocarga 07'), findsOneWidget);
      expect(find.text('Furgón 01'), findsNothing);

      // Y la X lo quita, sin abrir la hoja. Con un filtro puesto hay dos X: la que
      // vacía todos los filtros, junto al buscador, y la del selector de tipo.
      // Se toca la primera, que es la de limpiar todo.
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill).first);
      await pumpListo(tester);

      expect(api.ultimaConsulta?.tipo, isNull);
      expect(find.text('Furgón 01'), findsOneWidget);
      expect(find.text('Motocarga 07'), findsOneWidget);
    });

    testWidgets('la casilla de inactivas filtra por activo=false', (tester) async {
      final api = FakeUnidadApi(unidades: [
        unidadDePrueba(id: 1, nombre: 'Activa 01'),
        unidadDePrueba(id: 2, nombre: 'Inactiva 02', activo: false),
      ]);

      await tester.pumpWidget(montar(unidades: api));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      await tester.tap(find.text('Inactivas'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(api.ultimaConsulta?.activo, isFalse);
      expect(find.text('Inactiva 02'), findsOneWidget);
      expect(find.text('Activa 01'), findsNothing);
    });

    testWidgets('avisa distinto si no hay unidades o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(unidades: FakeUnidadApi()));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      expect(find.text('Esta planta todavía no tiene unidades.'), findsOneWidget);

      // Con un filtro puesto el mensaje cambia: son dos problemas distintos y la
      // pista para cada uno es otra.
      await tester.enterText(find.byType(CupertinoTextField).first, 'zzz');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Ninguna unidad coincide con el filtro.'), findsOneWidget);
    });
  });

  group('el formulario de unidades', () {
    testWidgets('no deja guardar sin nombre ni capacidad', (tester) async {
      final api = FakeUnidadApi();

      await tester.pumpWidget(montar(unidades: api));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await bajarHasta(tester, 'Crear unidad');
      await tester.tap(find.text('Crear unidad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await irAlPrincipio(tester);

      expect(find.text('Ponle un nombre a la unidad.'), findsOneWidget);
      expect(find.text('Indica cuántos litros transporta.'), findsOneWidget);
      // No se llegó a llamar a la API: la validación es de cliente y el error va
      // junto al campo, no en un aviso arriba.
      expect(api.creados, isEmpty);
    });

    testWidgets('crea la unidad con lo que se escribió', (tester) async {
      final api = FakeUnidadApi();

      await tester.pumpWidget(montar(unidades: api));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Unidad Furgón 09');
      await tester.enterText(find.byType(CupertinoTextField).at(1), '1500');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear unidad');
      await tester.tap(find.text('Crear unidad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(api.creados, hasLength(1));
      expect(find.text('Unidad Furgón 09'), findsOneWidget);
    });

    testWidgets('rechaza una capacidad que no es un número', (tester) async {
      final api = FakeUnidadApi();

      await tester.pumpWidget(montar(unidades: api));
      await entrar(tester);
      await abrirModulo(tester, 'Unidades');

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.byType(CupertinoTextField).at(0), 'Unidad 10');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'muchos');
      await tester.pump(const Duration(milliseconds: 300));

      await bajarHasta(tester, 'Crear unidad');
      await tester.tap(find.text('Crear unidad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await irAlPrincipio(tester);

      expect(find.text('Eso no es un número.'), findsOneWidget);
      expect(api.creados, isEmpty);
    });
  });
}

/// Monta solo la página de unidades, con su propio contenedor de providers.
///
/// Permite hablar con el controlador desde el propio test, sin pasar por un
/// gesto: la rueda del selector no es determinista en pruebas y lo que importa
/// es qué llega al servidor, no cómo se escogió la opción.
Future<ProviderContainer> pumpPagina(
  WidgetTester tester,
  FakeUnidadApi unidades,
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
      unidadApiProvider.overrideWithValue(unidades),
    ],
  );
  addTearDown(contenedor.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      // `CupertinoApp` y no la página a pelo: sin ella no hay `Directionality` ni
      // tema, y la pantalla no construye.
      child: const CupertinoApp(home: UnidadesPage()),
    ),
  );

  return contenedor;
}

/// Deja que la carga del controlador termine.
Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Elige una opción del selector desplegable.
///
/// La rueda no salta a la opción con tocar su etiqueta: hay que desplazarla
/// hasta que llegue al centro y confirmar con "Listo", que es lo que hace una
/// persona. `itemExtent` es 34 y la lista es [Todos, Furgón, Motocarga], así que
/// para llegar a Motocarga desde Todos son dos tirones.
Future<void> elegirEnSelector(WidgetTester tester, String etiqueta) async {
  await tester.tap(find.text('Todos'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // Un tirón por posición, con la rueda asentada entre medias. Un solo arrastre
  // de 68 píxeles no landing donde debería: el `CupertinoPicker` asienta por
  // física y el resultado depende de cómo se reparta el movimiento. Ir de uno en
  // uno es lo que hace una persona y no deja sitio a la duda.
  for (var posicion = 0; posicion < 2; posicion += 1) {
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -34));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  await tester.tap(find.text('Listo'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Sube la lista hasta arriba.
///
/// Hace falta después de guardar sin éxito: el aviso de error sale junto al
/// campo, arriba, y si se ha bajado hasta el botón el error queda fuera de
/// pantalla.
Future<void> irAlPrincipio(WidgetTester tester) async {
  for (var intento = 0; intento < 6; intento += 1) {
    await tester.drag(find.byType(ListView).last, const Offset(0, 260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Baja la lista hasta que se vea un texto, y lo devuelve.
///
/// El formulario es un `ListView`, que solo construye lo que se ve. El botón de
/// guardar queda por debajo del borde, así que no está en el árbol: sin esto,
/// `tap` fallaría con "Found 0 widgets".
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