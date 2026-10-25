// Pruebas del campo de hora y de las reglas que lo rodean.
//
// Lo que se comprueba aquí son las **funciones**, no la rueda. Arrastrar un
// `CupertinoPicker` en una prueba no es determinista —depende de la inercia y de
// los frames—, y una prueba que depende de eso acaba verde por casualidad y roja
// sin razón. La rueda en sí se comprueba en el móvil; las reglas que la rodean,
// que son las que se rompen, se comprueban aquí.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/shared/widgets/app_time_field.dart';

void main() {
  group('partirHora', () {
    test('descompone una hora larga', () {
      expect(partirHora('06:30:00'), (6, 30));
    });

    test('también acepta una hora corta', () {
      expect(partirHora('06:30'), (6, 30));
    });

    test('devuelve null si no hay hora, en vez de un cero', () {
      // Un `(0, 0)` silencioso pondría las doce de la noche en un campo que
      // debía estar vacío, y eso se vería al guardar.
      expect(partirHora(null), isNull);
      expect(partirHora(''), isNull);
    });

    test('devuelve null si no la entiende', () {
      expect(partirHora('mañana'), isNull);
      expect(partirHora('6'), isNull);
    });

    test('recorta lo que se sale de rango en vez de romperse', () {
      // `25:00` no es una hora, pero viene de una base de datos ajena y no puede
      // hacer que la pantalla lance. Se muestra 23:00 y ya.
      expect(partirHora('25:00:00'), (23, 0));
      expect(partirHora('06:75:00'), (6, 59));
    });
  });

  group('horaLegible', () {
    test('quita los segundos', () {
      expect(horaLegible('06:30:00'), '06:30');
    });

    test('rellena con ceros a la izquierda', () {
      // `6:30` de una base sin ceros se leería como "6 y pico" en pantalla.
      expect(horaLegible('6:30:00'), '06:30');
    });

    test('devuelve vacío si no hay nada', () {
      expect(horaLegible(null), '');
      expect(horaLegible(''), '');
    });
  });

  group('horaLarga', () {
    test('añade los segundos que guarda la base', () {
      expect(horaLarga('06:30'), '06:30:00');
      expect(horaLarga('06:30:00'), '06:30:00');
    });

    test('devuelve null si no hay hora, porque null es "sin hora"', () {
      expect(horaLarga(null), isNull);
      expect(horaLarga(''), isNull);
      expect(horaLarga('   '), isNull);
    });
  });

  group('minutosDesdeMedianoche', () {
    test('cuenta los minutos', () {
      expect(minutosDesdeMedianoche('06:00:00'), 360);
      expect(minutosDesdeMedianoche('00:00:00'), 0);
    });
  });

  group('errorDeRangoHoras', () {
    test('no se queja si la final es posterior', () {
      expect(errorDeRangoHoras('06:00:00', '11:00:00'), isNull);
    });

    // Este caso es el que una comparación de cadenas no habría cogido:
    // "10:00" > "9:00" como texto, pero 10:00 es posterior a 9:00.
    test('compara por minutos, no por texto', () {
      expect(errorDeRangoHoras('09:00:00', '10:00:00'), isNull);
    });

    test('avisa si la final es anterior', () {
      expect(
        errorDeRangoHoras('11:00:00', '06:00:00'),
        'La hora final debe ser posterior a la inicial.',
      );
    });

    test('avisa si son la misma hora', () {
      // Empezar a las 6 y acabar a las 6 no es un recorrido de cero minutos: es
      // una hora mal puesta, y dejarlo pasar daría una ruta sin duración.
      expect(errorDeRangoHoras('06:00:00', '06:00:00'), isNotNull);
    });

    test('no se queja si falta una de las dos', () {
      // La rueda permite no poner hora, y eso no es un error: el horario es
      // opcional en la ruta y en la zona.
      expect(errorDeRangoHoras('06:00:00', null), isNull);
      expect(errorDeRangoHoras(null, '11:00:00'), isNull);
      expect(errorDeRangoHoras(null, null), isNull);
    });
  });

  group('el campo en pantalla', () {
    testWidgets('enseña la hora puesta en corto, no con segundos', (tester) async {
      await tester.pumpWidget(const CupertinoApp(
        home: CupertinoPageScaffold(
          child: AppTimeField(
            etiqueta: 'HORA INICIO',
            valor: '06:30:00',
            onChanged: _ignorar,
          ),
        ),
      ));

      // `06:30`, no `06:30:00`: los segundos nunca se escriben ni se leen, y
      // verlos a la derecha de la caja da la sensación de estar midiendo algo
      // que no se mide.
      expect(find.text('06:30'), findsOneWidget);
      // El chevron doble es lo que dice "esto se gira, no se escribe".
      expect(find.byIcon(CupertinoIcons.chevron_up_chevron_down), findsOneWidget);
      // Y no hay ningún campo de texto: si lo hubiera, se podría teclear una
      // hora y volvería el problema que este widget vino a quitar.
      expect(find.byType(CupertinoTextField), findsNothing);
    });

    testWidgets('sin hora enseñe el texto de vacío, no un cero', (tester) async {
      await tester.pumpWidget(const CupertinoApp(
        home: CupertinoPageScaffold(
          child: AppTimeField(
            etiqueta: 'HORA INICIO',
            valor: null,
            onChanged: _ignorar,
          ),
        ),
      ));

      // Si enseñara "00:00" nadie distinguiría "no hay hora" de "medianoche".
      expect(find.text('Elige una hora'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
    });

    testWidgets('la X quita la hora', (tester) async {
      String? recibido = 'algo';

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: AppTimeField(
            etiqueta: 'HORA INICIO',
            valor: '06:30:00',
            onChanged: (v) => recibido = v,
          ),
        ),
      ));

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();

      // `null` y no cadena vacía: en el formulario `null` es lo que significa
      // "sin hora", y una cadena vacía se mandaría al servidor como texto.
      expect(recibido, isNull);
    });

    testWidgets('tocar abre la hoja con las dos ruedas', (tester) async {
      await tester.pumpWidget(const CupertinoApp(
        home: CupertinoPageScaffold(
          child: AppTimeField(
            etiqueta: 'HORA INICIO',
            valor: null,
            onChanged: _ignorar,
          ),
        ),
      ));

      expect(find.text('Listo'), findsNothing);

      await tester.tap(find.text('Elige una hora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      // Dos ruedas: horas y minutos. No se comprueba qué filas se ven porque
      // `CupertinoPicker` construye solo las que están en pantalla, y eso no es
      // una regla sino un detalle de su implementación.
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
    });

    testWidgets('cancelar deja la hora como estaba', (tester) async {
      var llamadas = 0;

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: AppTimeField(
            etiqueta: 'HORA INICIO',
            valor: '06:30:00',
            onChanged: (_) => llamadas++,
          ),
        ),
      ));

      await tester.tap(find.text('06:30'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancelar'));
      // La hoja modal se cierra con una transición propia, más larga que un
      // `pump`: con un solo frame el `Listo` sigue en el árbol y la prueba
      // mediría la animación, no el resultado.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Si cancelar avisara igual que listo, un toque mal hecho cambiaría la
      // hora sin querer y no habría vuelta atrás.
      expect(llamadas, 0);
      expect(find.text('Listo'), findsNothing);
    });
  });
}

/// Un `onChanged` que no hace nada, para los casos que solo miran la pantalla.
void _ignorar(String? _) {}
