// Reproduce el fallo que el usuario vio en el móvil: al abrir el desplegable de
// RUTA en "Nuevo recorrido", la hoja sale en blanco.
//
// No lo reproduzco en las pruebas de Recorridos porque ahí `FakeRutaApi` devuelve
// la lista ya hecha y todo pasa bien. Lo que falla es **la rueda del desplegable**,
// que es un widget compartido por toda la app, así que va aquí y sola.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milkdata_app/shared/widgets/app_selector.dart';

void main() {
  group('el desplegable, que es compartido por toda la app', () {
    testWidgets('abre una hoja con las cuatro rutas', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: AppSelector(
                etiqueta: 'RUTA',
                valor: '',
                vacio: 'Elige la ruta',
                items: const [
                  SelectorItem(id: '1', etiqueta: 'Ruta Norte'),
                  SelectorItem(id: '2', etiqueta: 'Ruta Sur'),
                  SelectorItem(id: '3', etiqueta: 'Ruta Este'),
                  SelectorItem(id: '4', etiqueta: 'Ruta Oeste'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elige la ruta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // El fallo que se vio: la hoja abría y no se veía **nada** dentro.
      expect(find.text('Ruta Norte'), findsOneWidget);
      expect(find.text('Ruta Sur'), findsOneWidget);
      expect(find.text('Ruta Este'), findsOneWidget);
      expect(find.text('Ruta Oeste'), findsOneWidget);
    });

    testWidgets('las cuatro se ven de verdad, no solo existen en el arbol', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: AppSelector(
                etiqueta: 'RUTA',
                valor: '',
                vacio: 'Elige la ruta',
                items: const [
                  SelectorItem(id: '1', etiqueta: 'Ruta Norte'),
                  SelectorItem(id: '2', etiqueta: 'Ruta Sur'),
                  SelectorItem(id: '3', etiqueta: 'Ruta Este'),
                  SelectorItem(id: '4', etiqueta: 'Ruta Oeste'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elige la ruta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // `findsOneWidget` encuentra el widget aunque esté **fuera de la pantalla**.
      // Esto es lo que faltaba: lo que importa es que se ven.
      expect(find.text('Ruta Norte').hitTestable(), findsOneWidget);
      expect(find.text('Ruta Sur').hitTestable(), findsOneWidget);
    });

    testWidgets('sin opciones no abre una hoja en blanco', (tester) async {
      // **Este es el fallo que vio el usuario.** En una planta recién creada no
      // hay rutas, y al tocar el selector se abría una hoja con una rueda sin
      // nada: una pantalla vacía que parece rota en lugar de "aquí no hay nada".
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: AppSelector(
                etiqueta: 'RUTA',
                valor: '',
                vacio: 'No hay rutas',
                items: const <SelectorItem>[],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('No hay rutas'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // No se abre nada: ni la hoja, ni la rueda, ni un "Listo" que no lleva a
      // ninguna parte.
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(find.text('Listo'), findsNothing);
      // Y el campo sigue explicando por qué está vacío.
      expect(find.text('No hay rutas'), findsOneWidget);
    });

    testWidgets('con una sola opcion tambien se ve', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: AppSelector(
                etiqueta: 'RUTA',
                valor: '',
                vacio: 'Elige la ruta',
                items: const [SelectorItem(id: '5', etiqueta: 'Ruta Norte')],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elige la ruta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ruta Norte').hitTestable(), findsOneWidget);
    });
  });
}
