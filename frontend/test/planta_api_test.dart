// Pruebas de la capa de datos de Plantas, **sin dobles**.
//
// Estas existen por un motivo concreto: `FakePlantaApi` sobrescribe `listar`
// entero, así que el atajo se salta justo la línea que traduce la respuesta. El
// bug que grabaron —leer `cuerpo['items']` en vez de `cuerpo['data']['items']`—
// dejó la lista vacía con un 200 delante y ninguna prueba lo vio. El usuario lo
// vio en el móvil en un minuto.
//
// La lección: **un doble que reimplementa el método que quiere probar no prueba
// nada de ese método.** Aquí se mueve el Dio de verdad con un adaptador que
// devuelve el JSON exacto que devuelve el servidor, tomados de una respuesta
// real.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/plantas/data/planta_api.dart';

/// Respuesta real de `GET /plantas`, copiada tal cual de la API.
///
/// Lo importante es la **envoltura**: `items` está dentro de `data`, no en la
/// raíz. Ese un nivel es todo el bug.
const String _respuestaReal = '''
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "nombre": "Planta Ecológica Huata",
        "codigo": "HUA",
        "direccion": "Distrito de Huata",
        "imagen": null,
        "activo": true,
        "createdAt": "2026-10-12T18:44:57.000Z",
        "updatedAt": "2026-10-12T18:44:57.000Z"
      },
      {
        "id": 3,
        "nombre": "Huata",
        "codigo": "HUATA",
        "direccion": "Distrito de Huata",
        "imagen": null,
        "activo": true,
        "createdAt": "2026-10-15T20:02:37.000Z",
        "updatedAt": "2026-10-15T20:02:37.000Z"
      }
    ],
    "paginacion": {
      "pagina": 1,
      "limite": 50,
      "total": 2,
      "totalPaginas": 1,
      "tieneAnterior": false,
      "tieneSiguiente": false
    },
    "layerTrace": ["routes", "controller", "service", "repository"]
  },
  "message": null,
  "errors": []
}
''';

/// Respuesta real de `POST /plantas`, que devuelve el item dentro de `data`.
const String _altaReal = '''
{
  "success": true,
  "data": {
    "item": {
      "imagen": null,
      "activo": true,
      "id": 4,
      "nombre": "Planta del Norte",
      "direccion": "Carretera 5",
      "codigo": "NOR",
      "createdAt": "2026-10-15T20:10:00.000Z",
      "updatedAt": "2026-10-15T20:10:00.000Z"
    }
  },
  "message": null,
  "errors": []
}
''';

/// Un `Dio` de verdad, con la red sustituida por una respuesta fija.
///
/// Es un `HttpClientAdapter` a propósito: `Dio` sigue haciendo su trabajo normal
/// —serializar, meter el `Authorization`, envolver la respuesta— y solo se
/// cambia el paso de red, que es lo único que aquí no se quiere probar.
Dio dioQueResponde(String cuerpo, {int codigo = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));

  dio.httpClientAdapter = _AdaptadorFijo(
    body: cuerpo,
    statusCode: codigo,
  );

  return dio;
}

class _AdaptadorFijo implements HttpClientAdapter {
  _AdaptadorFijo({required this.body, required this.statusCode});

  final String body;
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('la capa de datos de Plantas, sin atajos', () {
    test('la lista se lee de data y no de la raíz', () async {
      // El bug: leer `cuerpo['items']` da `null` y devuelve una lista vacía **con
      // un 200 delante**, así que la pantalla dice que no hay plantas.
      final api = PlantaApi(dioQueResponde(_respuestaReal));

      final plantas = await api.listar();

      expect(plantas, hasLength(2));
      expect(plantas.first.nombre, 'Planta Ecológica Huata');
      expect(plantas.first.codigo, 'HUA');
      expect(plantas.first.activo, isTrue);
      expect(plantas[1].codigo, 'HUATA');
    });

    test('el alta se lee de data.item', () async {
      final api = PlantaApi(dioQueResponde(_altaReal, codigo: 201));

      final planta = await api.crear(
        nombre: 'Planta del Norte',
        codigo: 'NOR',
        direccion: 'Carretera 5',
      );

      expect(planta.id, 4);
      expect(planta.nombre, 'Planta del Norte');
      expect(planta.direccion, 'Carretera 5');
    });

    test('un cuerpo sin items no rompe, devuelve vacío', () async {
      // Una respuesta rara no puede reventar la pantalla con una excepción sin
      // explicar; devuelve lo que haya, que en este caso es nada.
      final api = PlantaApi(dioQueResponde('{"success":true,"data":{}}'));

      expect(await api.listar(), isEmpty);
    });

    test('un 403 se lanza como excepción, no como lista vacía', () async {
      // **Este es el otro lado del fallo original.** Con el aviso de error en la
      // pantalla, un 403 dice "no tienes permiso"; sin él, diría "no hay plantas".
      final api = PlantaApi(dioQueResponde(
        '{"success":false,"message":"No tienes permiso","errors":[]}',
        codigo: 403,
      ));

      await expectLater(
        api.listar(),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}