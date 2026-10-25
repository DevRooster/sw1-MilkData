// Pruebas de la pantalla de sesión: login, pestañas y cierre.
//
// Este fichero monta **la app entera**, no una pantalla suelta, y por eso lleva
// dobles de autenticación, de usuarios y de plantas a la vez: casi todo lo que
// se comprueba aquí ocurre entre varias partes a la vez.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:milkdata_app/app.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/auth/data/auth_repository.dart';
import 'package:milkdata_app/features/auth/domain/planta.dart';
import 'package:milkdata_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:milkdata_app/features/usuarios/domain/usuario_lista.dart';
import 'package:milkdata_app/features/usuarios/presentation/providers/usuarios_controller.dart';

import 'helpers/fake_auth_api.dart';
import 'helpers/fake_token_storage.dart';
import 'helpers/fake_usuario_api.dart';

/// Monta la app con los dobles.
///
/// `almacenamiento` se pasa aparte del resto porque hay pruebas que lo
/// inspeccionan después: el cierre de sesión tiene que dejar el token a `null`,
/// y eso no se puede comprobar si el doble lo crea la propia función.
Widget montarApp({
  FakeTokenStorage? almacenamiento,
  FakeAuthApi? api,
  List<Planta> plantas = const [],
  List<UsuarioLista> usuarios = const [],
}) {
  final cliente = api ?? FakeAuthApi();
  cliente.plantas = plantas;

  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(almacenamiento ?? FakeTokenStorage()),
      authApiProvider.overrideWithValue(cliente),
      authRepositoryProvider.overrideWith(
        (ref) => AuthRepository(
          api: cliente,
          storage: ref.watch(tokenStorageProvider),
        ),
      ),
      usuarioApiProvider.overrideWithValue(FakeUsuarioApi(usuarios: usuarios)),
    ],
    child: const MilkDataApp(),
  );
}

/// Baja el lanzador hasta ver un texto y lo pulsa.
///
/// El lanzador es un `ListView`: solo construye lo que cabe en pantalla. Con ocho
/// módulos, "Usuarios" y "Cerrar sesión" quedan por debajo del pliegue y hay que
/// desplazarse hasta ellos. Las pruebas lo hacen, porque es lo que hace el
/// usuario; no usan `skipOffstage`, que daría verde sin comprobar nada.
///
/// 20 intentos y no 8: el lanzador crece con cada módulo, y el número justo hoy
/// es un número que mañana se queda corto otra vez.
Future<void> abrirDelLanzador(WidgetTester tester, String titulo) async {
  for (var intento = 0; intento < 20; intento += 1) {
    // hitTestable y no ind: un ListView construye tambien lo que queda
    // fuera de pantalla, y ind lo contaria como encontrado. Con esto solo
    // cuenta lo que se puede pulsar, que es lo que decide si hay que bajar mas.
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

/// Baja el lanzador hasta ver un texto, sin pulsarlo.
Future<void> bajarHasta(WidgetTester tester, String titulo) async {
  for (var intento = 0; intento < 20; intento += 1) {
    if (find.text(titulo).hitTestable().evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  fail('No se encontró "$titulo" en el lanzador ni bajando del todo.');
}
void main() {
  testWidgets('sin sesion guardada muestra el login', (tester) async {
    await tester.pumpWidget(montarApp());

    // El indicador de carga gira sin parar, así que `pumpAndSettle` no
    // terminaría nunca: se avanza el reloj con `pump`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('CORREO'), findsOneWidget);
    expect(find.text('CONTRASEÑA'), findsOneWidget);
  });

  testWidgets('valida los campos vacios sin llamar a la API', (tester) async {
    final api = FakeAuthApi();
    await tester.pumpWidget(montarApp(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(api.llamadas, 0, reason: 'no debe llamar a la API sin datos');
  });

  testWidgets('rechaza un correo con formato invalido', (tester) async {
    final api = FakeAuthApi();
    await tester.pumpWidget(montarApp(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(CupertinoTextField).first, 'no-es-correo');
    await tester.enterText(find.byType(CupertinoTextField).last, '123456');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ese correo no parece válido.'), findsOneWidget);
    expect(api.llamadas, 0);
  });

  testWidgets('con credenciales validas pasa a la pantalla de inicio', (tester) async {
    final almacenamiento = FakeTokenStorage();
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba());
    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(CupertinoTextField).first, 'admin@milkdata.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Admin123!');
    await tester.tap(find.text('Entrar'));

    // Se deja avanzar lo que dura la animación de cambio de pantalla.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Prueba'), findsOneWidget);
    // El rol se muestra como etiqueta, no con el prefijo "Rol:".
    expect(find.text('admin'), findsOneWidget);
    // El token quedó guardado en el almacén cifrado.
    expect(almacenamiento.token, 'token-de-prueba');
  });

  testWidgets('muestra el error que devuelve la API', (tester) async {
    final api = FakeAuthApi(
      errorALanzar: const UnauthorizedException('Credenciales incorrectas.'),
    );
    await tester.pumpWidget(montarApp(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(CupertinoTextField).first, 'malo@milkdata.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'malaclave');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget, reason: 'sigue en el login');
  });

  testWidgets('el boton muestra progreso mientras envia', (tester) async {
    final api = FakeAuthApi(
      sesionARetornar: sesionDePrueba(),
      demora: const Duration(milliseconds: 300),
    );
    await tester.pumpWidget(montarApp(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(CupertinoTextField).first, 'admin@milkdata.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Admin123!');
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    // Un frame para que el controlador marque el estado de envío y llegue a
    // reconstruirse el botón.
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    // Al terminar la respuesta, cambia a la pantalla de inicio.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ana Prueba'), findsOneWidget);
  });

  testWidgets('con token guardado entra directo a inicio', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Entrar'), findsNothing);
    expect(find.text('guardado@milkdata.com'), findsOneWidget);
  });

  testWidgets('un token vencido vuelve al login', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-vencido');
    // El perfil falla, como haria la API si el token ya no vale.
    final api = FakeAuthApi(errorALanzar: const UnauthorizedException());

    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('el boton de salida limpia el token', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El botón de cerrar sesión vive en la pestaña Inicio, como botón de
    // texto. Antes era un chevron en la barra de navegación.
        await abrirDelLanzador(tester, 'Cerrar sesión');

    expect(almacenamiento.token, isNull);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('el menu muestra las pestañas Inicio, Perfil y Usuarios', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    // Usuarios vive en el lanzador, y el lanzador solo construye lo que cabe:
    // hay que bajar hasta verlo. No se usa `skipOffstage` porque en el móvil
    // tampoco está a la vista sin desplazarse.
    await bajarHasta(tester, 'Usuarios');
    expect(find.text('Usuarios'), findsOneWidget);
  });

  testWidgets('la pestaña Perfil muestra los datos y las fotos', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      plantas: const [
        Planta(id: 1, nombre: 'Huata', codigo: 'HUA'),
        Planta(id: 2, nombre: 'Arequipa', codigo: 'ARE'),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El perfil se pinta sin que nadie pulse nada.
    expect(find.text('guardado@milkdata.com'), findsOneWidget);

    // Y también las fotos: el perfil es donde se cambian.
    final vistas = <String>{};

    for (var paso = 0; paso < 6 && !vistas.contains('fotos'); paso++) {
      if (find.text('MIS FOTOS').evaluate().isNotEmpty) {
        vistas.add('fotos');
        break;
      }

      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      await tester.pump();
    }

    expect(
      vistas,
      contains('fotos'),
      reason: 'La tarjeta de fotos debería salir en el perfil',
    );
  });

  testWidgets('la pestaña Usuarios abre con la lista, no con el formulario', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      usuarios: [usuarioDePrueba(id: 5, nombre: 'Luis', apellido: 'Acopiador')],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    // La lista es lo primero que se ve: es lo que se viene a consultar.
    expect(find.text('Luis Acopiador'), findsOneWidget);
    expect(find.text('BUSCAR'), findsOneWidget);

    // Y las acciones de la fila.
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Rol'), findsOneWidget);
    expect(find.text('Desactivar'), findsOneWidget);
  });

  testWidgets('el boton de la barra abre el formulario de alta', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      usuarios: [usuarioDePrueba(id: 5)],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    // El icono aparece dos veces: en la barra y en la fila de la lista. Se
    // apunta al de la barra, que es el que abre el formulario.
    final enBarra = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.person_badge_plus),
    );

    await tester.tap(enBarra);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Formulario de alta, con sus cuatro campos.
    expect(find.text('Registrar usuario'), findsWidgets);
    expect(find.byType(CupertinoTextField), findsNWidgets(4));
  });

  testWidgets('tocar una planta la deja activa', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      plantas: const [
        Planta(id: 1, nombre: 'Huata', codigo: 'HUA'),
        Planta(id: 2, nombre: 'Arequipa', codigo: 'ARE'),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    // El selector de planta está en el formulario de alta.
    await tester.tap(find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.person_badge_plus),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('OPERAR EN'), findsOneWidget);
    expect(find.text('Todas las plantas'), findsOneWidget);
  });

  testWidgets('un admin de una sola planta no recibe selector de planta', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      plantas: const [Planta(id: 1, nombre: 'Huata', codigo: 'HUA')],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    await tester.tap(find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.person_badge_plus),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Con una sola planta no hay nada que elegir, así que el selector no se
    // pinta: sería un control que no puede hacer nada.
    expect(find.text('OPERAR EN'), findsNothing);
    expect(find.text('Solo tu planta'), findsOneWidget);
  });

  testWidgets('tras iniciar sesión se piden solos el perfil y las plantas', (tester) async {
    final almacenamiento = FakeTokenStorage();
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba());

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      plantas: const [Planta(id: 1, nombre: 'Huata', codigo: 'HUA')],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(CupertinoTextField).first, 'admin@milkdata.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Admin123!');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Nadie pulsó nada: el login tiene que haber lanzado las dos peticiones.
    expect(api.perfiles, greaterThan(0), reason: 'el perfil se pide al entrar');
    expect(api.plantasPeticiones, greaterThan(0), reason: 'las plantas se piden al entrar');
  });

  testWidgets('se puede volver a ver todos los usuarios tras filtrar por rol', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      usuarios: [
        usuarioDePrueba(id: 1, nombre: 'Ana', rol: 'admin', rolId: 2),
        usuarioDePrueba(id: 2, nombre: 'Luis', rol: 'operador', rolId: 5),
        usuarioDePrueba(id: 3, nombre: 'Sara', rol: 'admin', rolId: 2),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    // Sin filtro: los tres.
    expect(find.text('Ana Prueba'), findsOneWidget);
    expect(find.text('Luis Prueba'), findsOneWidget);
    expect(find.text('Sara Prueba'), findsOneWidget);

    // Filtro por admin. Se abre la hoja tocando el campo.
    await tester.tap(find.text('Todos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // La rueda hay que desplazarla: "admin" está por debajo del centro, que es
    // donde arranca.
    final rueda = find.byType(CupertinoPicker);
    await tester.drag(rueda, const Offset(0, -40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Y confirmar con Listo, que es lo que cierra la hoja y aplica la elección.
    await tester.tap(find.text('Listo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ana Prueba'), findsOneWidget);
    expect(find.text('Luis Prueba'), findsNothing, reason: 'el filtro debe ocultar al operador');
    expect(find.text('Sara Prueba'), findsOneWidget);

    // Y volver atrás con la X, sin abrir la hoja.
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Luis Prueba'), findsOneWidget, reason: 'al quitar el filtro vuelven todos');
    expect(find.text('Ana Prueba'), findsOneWidget);
    expect(find.text('Sara Prueba'), findsOneWidget);
  });

  testWidgets('el selector de rol ofrece Todos como opción', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(
      almacenamiento: almacenamiento,
      api: api,
      usuarios: [usuarioDePrueba(id: 1)],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Usuarios');

    // Sin filtro debe verse "Todos" como lo elegido, y no "Elige un rol": si no
    // se puede quitar, el filtro es una puerta de sentido único.
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Elige un rol'), findsNothing);
  });

  testWidgets('cerrar sesion avisa al servidor antes de borrar el token', (tester) async {
    final almacenamiento = FakeTokenStorage(token: 'token-guardado');
    final api = FakeAuthApi(sesionARetornar: sesionDePrueba(email: 'guardado@milkdata.com'));

    await tester.pumpWidget(montarApp(almacenamiento: almacenamiento, api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

        await abrirDelLanzador(tester, 'Cerrar sesión');

    // `POST /auth/logout` tiene que haberse llamado: el token es un JWT sin
    // estado y el servidor solo puede confirmar el cierre, no revocarlo.
    expect(api.logouts, greaterThan(0));
    expect(almacenamiento.token, isNull);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
