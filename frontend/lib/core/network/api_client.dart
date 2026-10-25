import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Crea el cliente HTTP con la configuración de la app.
///
/// Se construye por inyección desde Riverpod, no como singleton global: así
/// una prueba puede inyectar un `Dio` apuntando a otro servidor.
Dio crearApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      contentType: Headers.jsonContentType,
      // El backend responde 4xx y 5xx con un cuerpo JSON que la app sabe leer,
      // así que no se lanzan automáticamente: los mapea `error_mapper`.
      validateStatus: (status) => status != null && status < 400,
    ),
  );
}