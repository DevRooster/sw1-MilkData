import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Punto de entrada.
///
/// `ProviderScope` envuelve toda la app: es lo que da acceso a los providers de
/// Riverpod. Si se olvida, la primera pantalla que use `ref` falla.
void main() {
  runApp(const ProviderScope(child: MilkDataApp()));
}