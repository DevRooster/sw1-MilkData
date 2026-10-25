import 'package:flutter/cupertino.dart';

/// Estilo visual de la app: apariencia de iPhone.
///
/// Se usa `CupertinoThemeData` en vez de `ThemeData` para que los controles
/// nativos (campos, botones, selectores) tengan el aspecto y el comportamiento
/// de iOS, incluido el gesto de volver deslizando desde el borde.
class AppTheme {
  const AppTheme._();

  /// Verde de la marca, usado en acentos y acciones principales.
  static const Color verde = Color(0xFF2E7D32);

  static const CupertinoThemeData datos = CupertinoThemeData(
    primaryColor: verde,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Color(0xFFF2F2F7),
    textTheme: CupertinoTextThemeData(
      primaryColor: verde,
      // `CupertinoTabBar` pinta la etiqueta de la pestaña inactiva con
      // `tabLabelTextStyle` y la de la activa haciendo `DefaultTextStyle.merge`
      // sobre ella. El merge produce un estilo con `inherit: false` mientras el
      // original suele venir con `inherit: true`, y al interpolar entre ambos en
      // la animación del cambio de pestaña revienta con "Failed to interpolate
      // TextStyles with different inherit values".
      //
      // Declararlo aquí con `inherit: false` deja los dos estilos del mismo lado
      // y la animación funciona. Es un detalle del framework, no de la pantalla,
      // pero sin esto el fallo aparece dentro de `CupertinoTabView`.
      tabLabelTextStyle: TextStyle(
        inherit: false,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: CupertinoColors.label,
      ),
      navTitleTextStyle: TextStyle(
        // `inherit: false` por el mismo motivo que `tabLabelTextStyle`: la
        // animación de la transición de página interpola el estilo del título
        // de la barra con el que Cupertino deriva al fusionarlo, y si uno
        // hereda y el otro no, el `lerp` falla. Salía al rutina porque hasta
        // ahora ninguna pantalla se empujaba con una barra de navegación: los
        // módulos vivían en pestañas y no había transición que animar.
        inherit: false,
        color: CupertinoColors.label,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Espaciados usados en toda la app, para que las pantallas se vean parecidas
/// sin tener que inventar números en cada una.
class Espaciado {
  const Espaciado._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Altura estándar de los campos de texto.
  static const double altoCampo = 50;

  /// Radio de las esquinas redondeadas, al estilo de iOS.
  static const double radio = 12;
}