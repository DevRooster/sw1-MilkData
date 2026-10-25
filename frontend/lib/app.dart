import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/perfil_page.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/home/presentation/home_page.dart';

/// Menú principal con las pestañas, al estilo de iOS.
///
/// Solo hay dos pestañas: **Inicio** y **Perfil**. Los módulos ya no son
/// pestañas, se abren desde el lanzador de Inicio.
///
/// Fue una decisión, no una quoia: con once módulos, una barra de pestañas no
/// cabe ni se lee en un teléfono. Y una barra que cambia con cada módulo obliga
/// a reescribir `app.dart` once, que es justo la deuda que había que evitar
/// antes de empezar.
///
/// `CupertinoTabScaffold` se encarga de la barra inferior y de conservar el
/// estado de cada pestaña: al volver a Inicio, la pantalla sigue donde estaba en
/// lugar de reiniciarse.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.92),
        activeColor: AppTheme.verde,
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Perfil',
          ),
        ],
      ),
      // `CupertinoTabView` por pestaña: cada una tiene su propio Navigator, y
      // así una pantalla abierta desde Inicio no borra el historial de Perfil.
      tabBuilder: (context, indice) {
        return switch (indice) {
          0 => const CupertinoTabView(builder: _conInicio),
          _ => const CupertinoTabView(builder: _conPerfil),
        };
      },
    );
  }

  static Widget _conInicio(BuildContext context) => const HomePage();

  static Widget _conPerfil(BuildContext context) => const PerfilPage();
}

/// Raíz de la aplicación.
///
/// Usa `CupertinoApp` para el aspecto de iPhone. El `home` se decide por el
/// estado de autenticación, así que no hay que navegar a mano: iniciar sesión
/// cambia la pantalla y cerrar sesión también.
class MilkDataApp extends StatelessWidget {
  const MilkDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'MilkData',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.datos,
      home: _AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según el estado de la sesión.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(authControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (estado) {
        // Mientras se lee el almacén cifrado se muestra un spinner, para no
        // convertir al usuario al login si ya tenía sesión.
        AuthDesconocido() => const _Cargando(key: ValueKey('cargando')),
        Autenticado() => const AppShell(key: ValueKey('shell')),
        SinSesion() => const _Login(key: ValueKey('login')),
      },
    );
  }
}

/// Indicador de carga a pantalla completa.
class _Cargando extends StatelessWidget {
  const _Cargando({super.key});

  @override
  Widget build(BuildContext context) {
    // No puede ser `const`: el fondo del tema se resuelve en tiempo de
    // ejecución, así que no es una expresión constante.
    return const CupertinoPageScaffold(
      backgroundColor: Color(0xFFF2F2F7),
      child: Center(child: CupertinoActivityIndicator(radius: 14)),
    );
  }
}

/// Login envuelto solo para darle su `key` en el `AnimatedSwitcher`: sin ella
/// la transición entre login y menú no se animaría.
class _Login extends StatelessWidget {
  const _Login({super.key});

  @override
  Widget build(BuildContext context) => const LoginPage();
}