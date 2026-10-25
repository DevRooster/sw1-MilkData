import 'package:dio/dio.dart';
import 'package:milkdata_app/core/error/app_exception.dart';
import 'package:milkdata_app/features/auth/data/auth_api.dart';
import 'package:milkdata_app/features/auth/domain/permisos.dart';
import 'package:milkdata_app/features/auth/domain/planta.dart';
import 'package:milkdata_app/features/auth/domain/sesion.dart';

/// `AuthApi` de mentira: responde lo que el test le pida, sin tocar la red.
///
/// Se hereda de la clase real para no duplicar su constructor ni sus tipos.
class FakeAuthApi extends AuthApi {
  FakeAuthApi({this.sesionARetornar, this.errorALanzar, this.demora = Duration.zero})
      : super(_dioFalso());

  final Sesion? sesionARetornar;
  final AppException? errorALanzar;
  final Duration demora;

  /// Plantas que devuelve `GET /auth/plantas`.
  ///
  /// La pantalla de la consola pide esa lista al abrirse. Sin esto, el método
  /// heredado haría una petición real y dejaría un timer vivo, que hace fallar
  /// el test con "A Timer is still pending".
  List<Planta> plantas = const [];

  /// Veces que se llamó a `POST /auth/logout`.
  ///
  /// Permite comprobar que la app avisa al servidor antes de borrar el token,
  /// que es el orden correcto: si se borrara primero, la petición saldría sin
  /// cabecera y el servidor respondería 401 en vez de confirmar el cierre.
  int logouts = 0;

  /// Veces que se llamó a `GET /auth/perfil`.
  ///
  /// Sirve para comprobar que el perfil se pide solo al iniciar sesión, sin
  /// que nadie pulse un botón.
  int perfiles = 0;

  /// Veces que se llamó a `GET /auth/plantas`.
  int plantasPeticiones = 0;

  /// Ids de planta a los que se pidió cambiar de sesión, en orden.
  List<int?> cambiosPlanta = [];

  /// Planta sobre la que está la sesión ahora, como hace el backend: el token
  /// manda, no la fila del usuario.
  int? plantaDeSesion;

  /// Permisos que devuelve `GET /auth/permisos`.
  ///
  /// Por defecto, un admin con todo: es lo que necesitan los tests que no van
  /// de permisos. Se llama `matrizPermisos` y no `permisos` porque el método
  /// heredado que devuelve esto ya se llama así, y un campo y un método con el
  /// mismo nombre en la misma clase no compilan.
  Permisos matrizPermisos = const Permisos(
    rol: 'admin',
    superadmin: false,
    plantaId: 1,
    recursos: <String, List<String>>{
      'plantas': ['read'],
      'proveedores': ['read', 'write'],
      'unidades': ['read', 'write'],
      'zonas': ['read', 'write'],
      'rutas': ['read', 'write'],
      'recorridos': ['read', 'write'],
      'recolecciones': ['read', 'write'],
      'calidad': ['read', 'write'],
      'notificaciones': ['read', 'write'],
      'asistencias': ['read', 'write'],
      'productos': ['read', 'write'],
      'reportes': ['read', 'write'],
      'usuarios': ['read', 'write'],
    },
  );

  /// Veces que se llamó a `GET /auth/permisos`.
  int permisosPeticiones = 0;

  @override
  Future<Permisos> permisos() async {
    permisosPeticiones += 1;
    return matrizPermisos;
  }

  @override
  Future<({String token, Planta planta})> cambiarPlanta({int? plantaId, String? codigo}) async {
    cambiosPlanta.add(plantaId);

    final pedida = plantas.firstWhere(
      (p) => plantaId != null ? p.id == plantaId : p.codigo == codigo,
      orElse: () => plantas.isEmpty
          ? const Planta(id: 0, nombre: 'Desconocida', codigo: '?')
          : plantas.first,
    );

    plantaDeSesion = pedida.id;

    // Guardar el token es cosa del repositorio, no de la API: así se comprueba
    // en el test que la app lo haga.
    return (token: 'token-de-${pedida.codigo}', planta: pedida);
  }

  @override
  Future<void> cerrarSesionRemota() async {
    logouts += 1;
  }

  /// Número de veces que se intentó iniciar sesión.
  int llamadas = 0;

  static Dio _dioFalso() => Dio(BaseOptions(baseUrl: 'http://localhost'));

  @override
  Future<Sesion> login({required String email, required String password}) async {
    llamadas += 1;

    if (demora > Duration.zero) {
      await Future<void>.delayed(demora);
    }

    final error = errorALanzar;
    if (error != null) {
      throw error;
    }

    final sesion = sesionARetornar;
    if (sesion == null) {
      throw const ServerException('La API no devolvió un token de sesión.');
    }

    return sesion;
  }

  @override
  Future<UsuarioSesion> perfil() async {
    perfiles += 1;
    final sesion = sesionARetornar;
    if (sesion == null) {
      throw const UnauthorizedException();
    }

    // Si se cambió de planta, el perfil devuelve la de la sesión, igual que el
    // backend. Sin esto el usuario seguiría viendo su planta de origen y el
    // selector nunca marcaría el cambio.
    final plantaId = plantaDeSesion;
    if (plantaId == null) {
      return sesion.usuario;
    }

    return UsuarioSesion(
      id: sesion.usuario.id,
      nombre: sesion.usuario.nombre,
      apellido: sesion.usuario.apellido,
      email: sesion.usuario.email,
      rol: sesion.usuario.rol,
      plantaId: plantaId,
    );
  }

  @override
  Future<PlantasDisponibles> plantasDisponibles() async {
    plantasPeticiones += 1;
    return PlantasDisponibles(
      alcance: plantas.length > 1 ? AlcancePlantas.todas : AlcancePlantas.propia,
      plantas: plantas,
      total: plantas.length,
    );
  }
}

/// Sesión de ejemplo para las pruebas.
Sesion sesionDePrueba({
  String token = 'token-de-prueba',
  String email = 'admin@milkdata.com',
  String rol = 'admin',
  int plantaId = 1,
  String? nombrePlanta = 'Planta Ecológica Huata',
}) {
  return Sesion(
    token: token,
    usuario: UsuarioSesion(
      id: 1,
      nombre: 'Ana',
      apellido: 'Prueba',
      email: email,
      rol: Rol(id: 1, nombre: rol, nivel: 5),
      plantaId: plantaId,
      // El nombre va porque **la sesión es la única fuente** de la planta: un
      // recolector no tiene permiso de `plantas: read` y no puede pedirla
      // por aparte. Por eso el backend la anida en el login.
      plantaNombre: nombrePlanta,
    ),
  );
}
