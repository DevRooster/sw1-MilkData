import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda y recupera el token de sesión.
///
/// Usa el Keystore de Android y el Keychain de iOS, que cifran el contenido.
/// Un JWT en `shared_preferences` quedaría en texto plano en el archivo, y ese
/// archivo lo puede leer cualquiera con acceso al dispositivo.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            // En la version 11 el cifrado por defecto ya es AES-GCM con
            // envoltorio de clave RSA en el Keystore, y requiere API 23 o
            // superior. No hace falta pedir nada extra.
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  /// Clave interna. Prefijada para no chocar con otras libs de la app.
  static const String _clave = 'milkdata_token';

  Future<String?> leer() async {
    try {
      return await _storage.read(key: _clave);
    } catch (_) {
      // Si el almacén no responde, se trata como "sin sesión" en lugar de
      // tumbar la app al arrancar.
      return null;
    }
  }

  Future<void> guardar(String token) async {
    await _storage.write(key: _clave, value: token);
  }

  Future<void> borrar() async {
    try {
      await _storage.delete(key: _clave);
    } catch (_) {
      // Borrar una sesión que ya no existe no es un error que interese.
    }
  }

  /// Si hay un token guardado, sin tocar la red.
  Future<bool> haySesion() async => (await leer()) != null;
}