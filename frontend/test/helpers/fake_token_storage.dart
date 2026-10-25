import 'package:milkdata_app/core/storage/token_storage.dart';

/// Almacén de token en memoria, para las pruebas.
///
/// Sustituye al cifrado real del sistema: en un test no hay Keystore, y
/// `flutter_secure_storage` necesita un canal de plataforma que no existe ahí.
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage({this.token});

  /// Token "guardado". `null` simula una app sin sesión.
  String? token;

  @override
  Future<String?> leer() async => token;

  @override
  Future<void> guardar(String nuevo) async => token = nuevo;

  @override
  Future<void> borrar() async => token = null;

  @override
  Future<bool> haySesion() async => token != null;
}