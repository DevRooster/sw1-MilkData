// Pruebas de los avisos locales del dispositivo.
//
// Lo que se prueba aquí es la **decisión**, no el plugin: qué avisos se avisan, a
// qué canal van y por qué no se repite nada. El plugin necesita un móvil de
// verdad, así que detrás hay una interfaz —`PublicaAvisos`— que aquí se sustituye
// por un doble que solo apunta lo que se le ha pedido.
//
// La parte que se rompe de verdad en el mundo no es "publicar una notificación":
// es avisar de lo mismo tres veces seguidas, o avisar de los cuarenta avisos
// históricos la primera vez que se abre la app. Eso es justo lo que va aquí.
import 'package:flutter_test/flutter_test.dart';
import 'package:milkdata_app/features/notificaciones/data/avisos_locales.dart';
import 'package:milkdata_app/features/notificaciones/domain/avisos.dart';
import 'package:milkdata_app/features/notificaciones/domain/notificacion.dart';

import 'helpers/fake_notificacion_api.dart';

/// Apunta lo publicado en vez de enseñarlo.
class PublicaFalsa implements PublicaAvisos {
  final List<({int id, String tipo, String canal, bool importante})> publicados = [];

  @override
  Future<void> publicar(dynamic notificacion, Canal canal) async {
    publicados.add((
      id: notificacion.id as int,
      tipo: notificacion.tipo as String,
      canal: canal.id,
      importante: canal.importante,
    ));
  }
}

/// Una marca que se puede manipulate a mano.
class MarcaFalsa implements MarcaDeAvisos {
  MarcaFalsa([this.guardada]);

  int? guardada;

  @override
  Future<int?> leer() async => guardada;

  @override
  Future<void> guardar(int id) async => guardada = id;
}

void main() {
  group('los canales', () {
    test('cada tipo tiene el suyo, y solo adulteración interrumpe', () {
      final canales = Canal.todos();

      expect(canales, hasLength(3));
      expect(canalPorId(canales, Notificacion.adulteracion).importante, isTrue);
      expect(canalPorId(canales, Notificacion.reunion).importante, isFalse);
      expect(canalPorId(canales, Notificacion.capacitacion).importante, isFalse);
    });

    test('los tres ids son distintos, o dos avisos acabarían en el mismo canal', () {
      final ids = Canal.todos().map((c) => c.id).toSet();
      expect(ids, hasLength(3));
    });

    test('un tipo desconocido no rompe: cae en el canal de la redireccion', () {
      // Si el servidor añadiera un cuarto tipo mañana, el aviso tiene que salir
      // en algún lado y no reventar la carga.
      final canal = Canal.deTipo('NUEVO');
      expect(canal.id, 'capacitacion');
    });
  });

  group('qué avisos se avisan', () {
    test('la primera vez no se avisa de nada', () {
      // Sin marca guardada todo parece nuevo, y al instalar la app el móvil
      // recibiría de golpe todos los avisos históricos.
      final resultado = calculaNuevos(
        [
          notificacionDePrueba(id: 9),
          notificacionDePrueba(id: 8),
        ],
        ultimaMarcada: 0,
        esPrimeraVez: true,
      );

      expect(resultado.nuevos, isEmpty);
      // Pero la marca sí avanza: la siguiente vez ya no es la primera.
      expect(resultado.marca, 9);
    });

    test('después de la primera vez, avisa de los nuevos sin leer', () {
      final resultado = calculaNuevos(
        [
          notificacionDePrueba(id: 12, leida: false),
          notificacionDePrueba(id: 11, leida: false),
          notificacionDePrueba(id: 10, leida: false),
        ],
        ultimaMarcada: 9,
        esPrimeraVez: false,
      );

      expect(resultado.nuevos.map((n) => n.id), [12, 11, 10]);
      expect(resultado.marca, 12);
    });

    test('no avisa de lo que ya está leído', () {
      // Un aviso que la persona ya leyó en la app no necesita salir en la barra
      // del móvil: sería ruido de lo que ya sabe.
      final resultado = calculaNuevos(
        [
          notificacionDePrueba(id: 12, leida: true),
          notificacionDePrueba(id: 11, leida: false),
        ],
        ultimaMarcada: 9,
        esPrimeraVez: false,
      );

      expect(resultado.nuevos.map((n) => n.id), [11]);
    });

    test('no avisa de lo que ya estaba marcado', () {
      final resultado = calculaNuevos(
        [
          notificacionDePrueba(id: 12, leida: false),
          notificacionDePrueba(id: 8, leida: false),
        ],
        ultimaMarcada: 10,
        esPrimeraVez: false,
      );

      expect(resultado.nuevos.map((n) => n.id), [12]);
    });

    test('avisa del más nuevo al más viejo', () {
      // El último que sale en la barra del móvil tiene que ser el más reciente:
      // es el que se lee primero.
      final resultado = calculaNuevos(
        [
          notificacionDePrueba(id: 11, leida: false),
          notificacionDePrueba(id: 14, leida: false),
          notificacionDePrueba(id: 12, leida: false),
        ],
        ultimaMarcada: 9,
        esPrimeraVez: false,
      );

      expect(resultado.nuevos.map((n) => n.id), [14, 12, 11]);
    });

    test('con una semana de retraso no salen cuarenta avisos, sino cinco', () {
      final muchos = List.generate(40, (i) => notificacionDePrueba(id: 50 - i, leida: false));

      final resultado = calculaNuevos(muchos, ultimaMarcada: 0, esPrimeraVez: false);

      expect(resultado.nuevos, hasLength(maximoDeAvisos));
      // Y son los cinco más nuevos.
      expect(resultado.nuevos.first.id, 50);
      expect(resultado.nuevos.last.id, 46);
      // La marca salta al mayor de todos, no al del último avisado: si no, los
      // que se saltaron pedirían aviso para siempre.
      expect(resultado.marca, 50);
    });

    test('una lista vacía no mueve la marca', () {
      final resultado = calculaNuevos(
        const [],
        ultimaMarcada: 7,
        esPrimeraVez: false,
      );

      expect(resultado.nuevos, isEmpty);
      expect(resultado.marca, 7, reason: 'sin avisos no hay por dónde avanzar');
    });
  });

  group('la marca avanza y no se pierde', () {
    test('avisa una vez y no repite en la siguiente carga', () async {
      final publica = PublicaFalsa();
      final marca = MarcaFalsa();
      final avisos = AvisosLocales(marca: marca, publica: publica);

      final lista = [
        notificacionDePrueba(id: 12, leida: false),
        notificacionDePrueba(id: 11, leida: false),
      ];

      // Primera vez: solo deja constancia.
      expect(await avisos.avisar(lista), 0);
      expect(marca.guardada, 12);

      // Segunda vez: ya hay marca, así que avisa de lo nuevo.
      expect(await avisos.avisar(lista), 0, reason: 'no hay nada más nuevo');

      marca.guardada = 10;
      expect(await avisos.avisar(lista), 2);
      expect(publica.publicados.map((p) => p.id), [12, 11]);

      // Y a la siguiente, sin nada nuevo, callado otra vez.
      expect(await avisos.avisar(lista), 0);
      expect(publica.publicados, hasLength(2));
    });

    test('cada aviso sale por el canal de su tipo', () async {
      final publica = PublicaFalsa();
      final marca = MarcaFalsa(5);
      final avisos = AvisosLocales(marca: marca, publica: publica);

      await avisos.avisar([
        notificacionDePrueba(id: 8, tipo: Notificacion.adulteracion, leida: false),
        notificacionDePrueba(id: 7, tipo: Notificacion.reunion, leida: false),
        notificacionDePrueba(id: 6, tipo: Notificacion.capacitacion, leida: false),
      ]);

      expect(publica.publicados.map((p) => p.canal), ['adulteracion', 'reunion', 'capacitacion']);
      // Y solo el de adulteración interrumpe.
      expect(publica.publicados.map((p) => p.importante), [true, false, false]);
    });

    test('un aviso de adulteración se avisa aunque la lista venga filtrada', () async {
      // El filtro no es cosa del servicio de avisos: si el usuario ha puesto
      // "solo adulteración", los avisos de reunión ni siquiera llegan a la lista.
      final publica = PublicaFalsa();
      final marca = MarcaFalsa(1);

      await AvisosLocales(marca: marca, publica: publica).avisar([
        notificacionDePrueba(id: 5, tipo: Notificacion.adulteracion, leida: false),
      ]);

      expect(publica.publicados, hasLength(1));
    });
  });
}

/// Busca un canal por su id.
Canal canalPorId(List<Canal> canales, String id) =>
    canales.firstWhere((c) => c.id == id);
