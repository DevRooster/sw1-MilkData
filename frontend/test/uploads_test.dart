import 'package:flutter_test/flutter_test.dart';
import 'package:milkdata_app/core/config/app_config.dart';
import 'package:milkdata_app/features/uploads/domain/imagen.dart';

void main() {
  group('ConfigImagenes', () {
    test('lee los limites que devuelve GET /uploads/api', () {
      final config = ConfigImagenes.fromJson(const {
        'limiteBytes': 5242880,
        'tipos': ['image/jpeg', 'image/png'],
        'recursos': ['usuario', 'producto'],
        'patron': '/uploads/<plantaId>/<recurso>/<uuid>.<ext>',
      });

      expect(config.limiteBytes, 5242880);
      expect(config.limiteMegaBytes, 5);
      expect(config.tipos, contains('image/png'));
      expect(config.recursos, contains('usuario'));
    });

    test('si la API no manda limites, usa un valor razonable', () {
      // Sin esto, un backend que cambie la forma de la respuesta dejaria a la
      // app sin poder validar nada.
      final config = ConfigImagenes.fromJson(const {});

      expect(config.limiteBytes, 5242880);
      expect(config.tipos, isEmpty);
    });

    test('admite solo los tipos que declara el servidor', () {
      final config = ConfigImagenes.fromJson(const {
        'tipos': ['image/jpeg', 'image/png'],
      });

      expect(config.admite('image/png'), isTrue);
      expect(config.admite('image/webp'), isFalse);
      expect(config.admite(null), isFalse);
    });
  });

  group('RecursoImagen', () {
    test('los valores son los que espera la API', () {
      // Si el backend espera otro nombre, el registro se actualiza pero la
      // columna queda vacia y no sale ningun error: el fallo seria invisible.
      expect(RecursoImagen.usuario.valor, 'usuario');
      expect(RecursoImagen.producto.valor, 'producto');
      expect(RecursoImagen.proveedor.valor, 'proveedor');
      expect(RecursoImagen.planta.valor, 'planta');
    });
  });

  group('urlDeImagen', () {
    test('antepone el servidor a una ruta relativa', () {
      final url = AppConfig.urlDeImagen('/uploads/1/usuario/abc.png');

      expect(url, '${AppConfig.apiBaseUrl}/uploads/1/usuario/abc.png');
    });

    test('deja intacta una URL absoluta', () {
      // La columna `imagen` tambien admite imagenes que la API no administra.
      const externa = 'https://cdn.ejemplo.com/foto.png';

      expect(AppConfig.urlDeImagen(externa), externa);
    });

    test('devuelve vacio si no hay imagen', () {
      // Sin esto, `Image.network` recibiría una URL mal formada y mostraría un
      // error en vez de un marcador.
      expect(AppConfig.urlDeImagen(null), '');
      expect(AppConfig.urlDeImagen(''), '');
    });
  });
}