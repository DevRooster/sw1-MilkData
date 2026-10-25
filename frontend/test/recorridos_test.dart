// Pruebas del módulo Recorridos.
//
// Este módulo es el primero con una máquina de estados de verdad, así que la
// mayoría de lo que se comprueba son **transiciones y qué botones existen**.
// El motivo es concreto: un botón que el servidor rechaza con un 400 es peor que
// no tenerlo, y eso solo se evita si la pantalla y el servidor comparten las
// mismas reglas.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/shared/widgets/app_button.dart';import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/recorridos/domain/recorrido.dart';
import 'package:milkdata_app/features/recorridos/presentation/lista_recorridos_page.dart';
import 'package:milkdata_app/features/recorridos/presentation/providers/recorridos_controller.dart';
import 'package:milkdata_app/features/rutas/presentation/providers/rutas_controller.dart';
import 'package:milkdata_app/features/unidades/presentation/providers/unidades_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_recorrido_api.dart';
import 'helpers/fake_ruta_api.dart';
import 'helpers/fake_token_storage.dart';
import 'helpers/fake_unidad_api.dart';

/// Monta la app con los dobles.
Widget montar({
  FakeRecorridoApi? recorridos,
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
      recorridoApiProvider.overrideWithValue(recorridos ?? FakeRecorridoApi()),
      rutaApiProvider.overrideWithValue(FakeRutaApi()),
      unidadApiProvider.overrideWithValue(FakeUnidadApi()),
    ],
    child: const MilkDataApp(),
  );
}

/// Monta solo la página de recorridos, con su propio contenedor de providers.
Future<ProviderContainer> pumpPagina(WidgetTester tester, FakeRecorridoApi recorridos) async {
  final cliente = FakeAuthApi(sesionARetornar: sesionDePrueba());
  cliente.matrizPermisos = _todoPermitido();

  final contenedor = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage(token: 'token-guardado')),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(api: cliente, storage: ref.watch(tokenStorageProvider)),
      ),
      recorridoApiProvider.overrideWithValue(recorridos),
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
      child: const CupertinoApp(home: RecorridosPage()),
    ),
  );

  return contenedor;
}

/// Un admin con todo: el caso normal de los tests que no van de permisos.
Permisos _todoPermitido() => const Permisos(
      rol: 'admin',
      plantaId: 1,
      recursos: {
        'recorridos': ['read', 'write'],
        'rutas': ['read', 'write'],
        'unidades': ['read', 'write'],
        'proveedores': ['read', 'write'],
      },
    );

Future<void> pumpListo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> abrirModulo(WidgetTester tester, String titulo) async {
  await tester.tap(find.text(titulo));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Baja la lista hasta que se vea un texto, buscando por **fragmento**.
Future<void> bajarHasta(WidgetTester tester, String etiqueta) async {
  // `hitTestable` y no `find`: un `ListView` construye tambien lo que queda
  // fuera de pantalla, y `find` lo contaria como encontrado.
  //
  // Y `textContaining` y no `text`: casi todo lo que se busca desde aqui son
  // frases enteras, y una coincidencia exacta no las encontraria nunca.
  for (var intento = 0; intento < 12; intento += 1) {
    if (find.textContaining(etiqueta).hitTestable().evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  fail('No se encontro el texto buscado bajando del todo.');
}

void main() {
  group('el lanzador de Inicio', () {
    testWidgets('enseña Recorridos a quien tiene permiso', (tester) async {
      await tester.pumpWidget(montar());
      await pumpListo(tester);

      expect(find.text('Recorridos'), findsOneWidget);
    });

    testWidgets('no lo enseña a un laboratorio', (tester) async {
      // `laboratorio` no tiene `recorridos` en la matriz del servidor.
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

      expect(find.text('Recorridos'), findsNothing);
    });
  });

  group('la máquina de estados', () {
    // Estas pruebas van contra el dominio, sin montar nada. Es lo que permite
    // que la regla se lea de un vistazo y no esté escondida en un `build`.
    test('un planificado puede iniciarse, no finalizarse ni atenderse', () {
      final r = recorridoDePrueba(estado: EstadoRecorrido.planificado);

      expect(r.puedeIniciar, isTrue);
      expect(r.puedeFinalizar, isFalse);
      expect(r.puedeAtenderParadas, isFalse);
      // Cancelar vale desde casi cualquier estado.
      expect(r.puedeCancelar, isTrue);
    });

    test('uno en ruta puede finalizarse y atender, pero no iniciarse', () {
      final r = recorridoDePrueba(estado: EstadoRecorrido.enRuta);

      expect(r.puedeIniciar, isFalse);
      expect(r.puedeFinalizar, isTrue);
      expect(r.puedeAtenderParadas, isTrue);
      expect(r.puedeCancelar, isTrue);
    });

    test('un finalizado no admite nada, ni cancelar', () {
      final r = recorridoDePrueba(estado: EstadoRecorrido.finalizado);

      expect(r.puedeIniciar, isFalse);
      expect(r.puedeFinalizar, isFalse);
      expect(r.puedeAtenderParadas, isFalse);
      // El único estado del que no se puede salir.
      expect(r.puedeCancelar, isFalse);
    });

    test('un cancelado no se puede volver a iniciar', () {
      // `iniciar` solo admite `PLANIFICADO` en el servidor, así que un recorrido
      // cancelado se queda ahí: es el registro de que se suspendió. La primera
      // versión de esta prueba decía que se podía reiniciar; el servidor dice
      // que no.
      final r = recorridoDePrueba(estado: EstadoRecorrido.cancelado);

      expect(r.puedeIniciar, isFalse);
      expect(r.puedeFinalizar, isFalse);
      expect(r.puedeAtenderParadas, isFalse);
      expect(r.puedeCancelar, isTrue);
    });

    test('un estado desconocido no rompe la pantalla', () {
      // Si el servidor añadiera un estado mañana, `from` cae en planificado y la
      // lista se sigue viendo en vez de quedarse en blanco.
      expect(EstadoRecorrido.desde('NUEVO_ESTADO'), EstadoRecorrido.planificado);
      expect(EstadoRecorrido.desde(null), EstadoRecorrido.planificado);
    });
  });

  group('la lista de recorridos', () {
    testWidgets('enseña los recorridos con su estado', (tester) async {
      await tester.pumpWidget(montar(
        recorridos: FakeRecorridoApi(recorridos: [
          recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado),
          recorridoDePrueba(id: 2, estado: EstadoRecorrido.enRuta),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Recorridos');

      expect(find.text('Ruta Norte'), findsNWidgets(2));
      expect(find.text('planificado'), findsOneWidget);
      expect(find.text('en ruta'), findsOneWidget);
    });

    testWidgets('la fecha se lee como día/mes/año', (tester) async {
      await tester.pumpWidget(montar(
        recorridos: FakeRecorridoApi(recorridos: [
          recorridoDePrueba(id: 1, fecha: '2026-10-13'),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Recorridos');

      // `2026-10-13` no lo lee nadie de un vistazo; `13/10/2026` sí. Y el
      // placeholder del filtro de día también es `2026-10-13`, así que la
      // comprobación mira solo dentro de las filas y no en la barra de filtros.
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.textContaining('13/10/2026'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el filtro de estado viaja como el texto del servidor', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado),
        recorridoDePrueba(id: 2, estado: EstadoRecorrido.enRuta),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(recorridosControllerProvider.notifier)
          .filtrarPorEstado(EstadoRecorrido.enRuta);
      await pumpListo(tester);

      // `EN_RUTA`, no `enRuta`: el enumerado es de la app y el servidor no lo
      // conoce. Mandar el nombre de Dart daría un 400.
      expect(api.ultimaConsulta?.estado, 'EN_RUTA');
    });

    testWidgets('avisa si no hay recorridos o si el filtro no encaja', (tester) async {
      await tester.pumpWidget(montar(recorridos: FakeRecorridoApi()));
      await pumpListo(tester);
      await abrirModulo(tester, 'Recorridos');

      expect(find.text('Esta planta todavía no tiene recorridos.'), findsOneWidget);

      await buscarEnElFiltro(tester, 'zzz');
      expect(find.text('Ningún recorrido coincide con el filtro.'), findsOneWidget);
    });

    testWidgets('en marcha avisa de que no se puede editar', (tester) async {
      await tester.pumpWidget(montar(
        recorridos: FakeRecorridoApi(recorridos: [
          recorridoDePrueba(id: 1, estado: EstadoRecorrido.enRuta),
        ]),
      ));
      await pumpListo(tester);
      await abrirModulo(tester, 'Recorridos');

      // Un recorrido en marcha tiene las paradas selladas: cambiarle la ruta
      // dejaría esas paradas apuntando a una ruta que ya no es la suya.
      expect(find.text('Editar'), findsNothing);
      expect(find.textContaining('no se edita'), findsOneWidget);
    });
  });

  group('el ciclo de vida', () {
    testWidgets('iniciar sella las paradas de la ruta', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado, rutaId: 1),
      ])
        ..conParadasDeRuta(1, [
          paradaRecorridoDePrueba(id: 1, orden: 1),
          paradaRecorridoDePrueba(id: 2, orden: 2, nombreProveedor: 'María', apellidoProveedor: 'Gómez'),
        ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      // Antes de iniciar no hay paradas: se sellan al arrancar, no al crear.
      await contenedor.read(recorridosControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await contenedor
          .read(recorridosControllerProvider.notifier)
          .iniciar(recorridoDePrueba(id: 1));
      await pumpListo(tester);

      final actualizado = await api.ver(1);
      expect(actualizado.estado, EstadoRecorrido.enRuta);
      expect(actualizado.paradas, hasLength(2));
      expect(actualizado.paradas.every((p) => p.pendiente), isTrue);
      // Y la hora real la pone el servidor, no la app.
      expect(actualizado.horaInicioReal, '06:00:00');
    });

    testWidgets('finalizar pasa las pendientes a omitidas', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.enRuta, paradas: [
          paradaRecorridoDePrueba(id: 1, estado: EstadoRecorrido.atendida, orden: 1),
          paradaRecorridoDePrueba(id: 2, estado: EstadoRecorrido.pendiente, orden: 2),
        ]),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor
          .read(recorridosControllerProvider.notifier)
          .finalizar(recorridoDePrueba(id: 1, estado: EstadoRecorrido.enRuta));
      await pumpListo(tester);

      final actualizado = await api.ver(1);
      expect(actualizado.estado, EstadoRecorrido.finalizado);
      // La atendida se queda; la pendiente no desaparece, pasa a omitida: es lo
      // que hace que el reporte cuadre.
      expect(actualizado.paradas[0].atendida, isTrue);
      expect(actualizado.paradas[1].omitida, isTrue);
    });

    testWidgets('un doble toque en iniciar no manda dos peticiones', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final controller = contenedor.read(recorridosControllerProvider.notifier);

      // Dos llamadas sin esperar la primera entre medias: es lo que pasa al
      // tocar dos veces seguidas un botón que tarda.
      final primera = controller.iniciar(recorridoDePrueba(id: 1));
      final segunda = controller.iniciar(recorridoDePrueba(id: 1));
      await pumpListo(tester);
      await primera;
      await segunda;

      expect(api.transiciones.where((t) => t.startsWith('iniciar')), hasLength(1));
    });

    testWidgets('no deja finalizar lo que no está en marcha', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(recorridosControllerProvider.notifier)
          .finalizar(recorridoDePrueba(id: 1));

      expect(ok, isFalse);
      expect(api.transiciones, isEmpty);
      // Y el error queda en el estado para que la pantalla lo pueda enseñar en
      // vez de tragárselo.
      expect(contenedor.read(recorridosControllerProvider).error, isNotNull);
    });

    testWidgets('no deja cancelar un finalizado', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.finalizado),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      final ok = await contenedor
          .read(recorridosControllerProvider.notifier)
          .cancelar(recorridoDePrueba(id: 1, estado: EstadoRecorrido.finalizado));

      expect(ok, isFalse);
      expect(api.transiciones, isEmpty);
    });
  });

  group('el detalle y las paradas', () {
    testWidgets('un planificado sin paradas avisa de que se sellan al iniciar',
        (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.planificado),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(recorridosControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Ruta Norte').hitTestable().first);
      await pumpListo(tester);
      await bajarHasta(tester, 'Se sellan al iniciarlo');

      // El aviso dice por que no hay paradas: no es que falten, es que se
      // copian al iniciar. Vive al final del formulario, asi que hay que
      // bajar hasta el con ajarHasta, y no con un arrastre a mano.
      expect(find.textContaining('Se sellan al iniciarlo'), findsOneWidget);
    });

    testWidgets('solo un recorrido en marcha tiene botón de atender', (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.enRuta, paradas: [
          paradaRecorridoDePrueba(id: 1, orden: 1),
          paradaRecorridoDePrueba(id: 2, orden: 2, nombreProveedor: 'María'),
        ]),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(recorridosControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Ruta Norte').hitTestable().first);
      await pumpListo(tester);

      expect(find.text('Atender'), findsNWidgets(2));
    });

    testWidgets('un finalizado avisa de que las pendientes quedaron omitidas',
        (tester) async {
      final api = FakeRecorridoApi(recorridos: [
        recorridoDePrueba(id: 1, estado: EstadoRecorrido.finalizado, paradas: [
          paradaRecorridoDePrueba(id: 1, estado: EstadoRecorrido.atendida, orden: 1),
          paradaRecorridoDePrueba(id: 2, estado: EstadoRecorrido.omitida, orden: 2),
        ]),
      ]);

      final contenedor = await pumpPagina(tester, api);
      await pumpListo(tester);

      await contenedor.read(recorridosControllerProvider.notifier).cargar();
      await pumpListo(tester);

      await tester.tap(find.text('Ruta Norte').hitTestable().first);
      await pumpListo(tester);

      expect(find.text('atendida'), findsOneWidget);
      expect(find.text('omitida'), findsOneWidget);
      // Y no hay botón de atender: ya no se puede.
      expect(find.text('Atender'), findsNothing);
    });
  });
}

/// Escribe en el filtro de búsqueda y deja que la pantalla se repinte.
Future<void> buscarEnElFiltro(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(CupertinoTextField).first, texto);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
