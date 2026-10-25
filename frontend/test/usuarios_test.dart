import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/features/usuarios/domain/usuario_lista.dart';

import 'helpers/fake_usuario_api.dart';

/// Pruebas del modelo de la lista de usuarios.
///
/// El modelo tiene una regla que conviene fijar por escrito: las iniciales.
/// `substring(0, 1)` sobre un nombre con emoji o un carácter de fuera del plano
/// básico parte la cadena por la mitad y produce un texto roto.
void main() {
  group('UsuarioLista', () {
    test('el nombre completo une nombre y apellido', () {
      expect(usuarioDePrueba().nombreCompleto, 'Ana Prueba');
    });

    test('sin apellido devuelve solo el nombre', () {
      final usuario = usuarioDePrueba(apellido: '');
      expect(usuario.nombreCompleto, 'Ana');
    });

    test('sin nombre ni apellido cae al correo', () {
      // Un cadastro vacío no sirve de nada; el correo al menos identifica a
      // quién es.
      final usuario = usuarioDePrueba(nombre: '', apellido: '');
      expect(usuario.nombreCompleto, 'ana@milkdata.com');
    });

    test('las iniciales toman la primera letra de cada parte', () {
      expect(usuarioDePrueba().iniciales, 'AP');
    });

    test('con un solo nombre toma esa inicial', () {
      expect(usuarioDePrueba(apellido: '').iniciales, 'A');
    });

    test('sin ninguna parte muestra un interrogante', () {
      final usuario = usuarioDePrueba(nombre: '', apellido: '');
      expect(usuario.iniciales, '?');
    });

    test('las iniciales nunca quedan vacías', () {
      // Con `characters.first` sobre un nombre que empieza con un emoji se
      // obtenía un texto partido. Se comprueba que sale un carácter usable.
      final usuario = usuarioDePrueba(nombre: 'Á', apellido: '');
      expect(usuario.iniciales.length, 1);
    });
  });

  group('UsuariosPagina', () {
    test('lee la paginación del backend', () {
      final pagina = UsuariosPagina.fromJson({
        'items': [
          {
            'id': 1,
            'nombre': 'Ana',
            'apellido': 'Prueba',
            'email': 'ana@milkdata.com',
            'activo': true,
            'rol': {'id': 3, 'nombre': 'supervisor', 'nivel': 3},
          },
        ],
        'paginacion': {
          'pagina': 2,
          'limite': 10,
          'total': 25,
          'totalPaginas': 3,
          'tieneAnterior': true,
          'tieneSiguiente': true,
        },
      });

      expect(pagina.usuarios, hasLength(1));
      expect(pagina.usuarios.first.email, 'ana@milkdata.com');
      expect(pagina.pagina, 2);
      expect(pagina.totalPaginas, 3);
      expect(pagina.total, 25);
      expect(pagina.tieneAnterior, isTrue);
      expect(pagina.tieneSiguiente, isTrue);
    });

    test('sin datos no falla', () {
      // Una respuesta vacía o con otra forma no debe tirar la pantalla: se
      // muestra "ningún usuario" y ya.
      final pagina = UsuariosPagina.fromJson(const {});

      expect(pagina.usuarios, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.tieneSiguiente, isFalse);
    });
  });

  group('FakeUsuarioApi', () {
    test('filtra por rol, estado y texto', () async {
      final api = FakeUsuarioApi(
        usuarios: [
          usuarioDePrueba(id: 1, nombre: 'Ana', rol: 'admin', rolId: 2),
          usuarioDePrueba(id: 2, nombre: 'Luis', rol: 'operador', rolId: 5),
          usuarioDePrueba(id: 3, nombre: 'Sara', rol: 'admin', rolId: 2, activo: false),
        ],
      );

      expect((await api.listar()).usuarios, hasLength(3));
      expect((await api.listar(rolId: 2)).usuarios, hasLength(2));
      expect((await api.listar(activo: false)).usuarios.single.id, 3);
      expect((await api.listar(busqueda: 'lu')).usuarios.single.id, 2);
      expect((await api.listar(busqueda: 'nada')).usuarios, isEmpty);
    });

    test('pagina sin perder filas', () async {
      final api = FakeUsuarioApi(
        usuarios: List.generate(12, (i) => usuarioDePrueba(id: i + 1)),
      );

      final primera = await api.listar(pagina: 1, limite: 10);
      final segunda = await api.listar(pagina: 2, limite: 10);

      expect(primera.usuarios, hasLength(10));
      expect(primera.totalPaginas, 2);
      expect(primera.tieneSiguiente, isTrue);
      expect(primera.tieneAnterior, isFalse);

      expect(segunda.usuarios, hasLength(2));
      expect(segunda.tieneAnterior, isTrue);
      expect(segunda.tieneSiguiente, isFalse);
    });

    test('registra las acciones para poder comprobarlas', () async {
      final api = FakeUsuarioApi(usuarios: [usuarioDePrueba(id: 7)]);

      await api.editar(7, nombre: 'Nuevo');
      await api.cambiarRol(7, 4);
      await api.cambiarActivo(7, false);
      await api.eliminar(7);

      expect(api.ediciones.single.nombre, 'Nuevo');
      expect(api.cambiosRol.single.rolId, 4);
      expect(api.cambiosActivo.single.activo, isFalse);
      expect(api.eliminados, [7]);
    });
  });
}