import 'package:flutter/widgets.dart';

/// Puntos de quiebre de la interfaz: la app es móvil primero y se adapta a
/// pantallas anchas (navegador en PC, tablet horizontal).
class Breakpoints {
  Breakpoints._();

  /// Desde este ancho se considera una pantalla de escritorio: el panel del
  /// negocio muestra su menú lateral y las listas se ensanchan.
  static const double desktop = 960;

  /// Desde este ancho el contenido empieza a ensancharse.
  static const double wide = 700;

  /// Desde este ancho el contenido alcanza su ancho máximo.
  static const double extraWide = 1200;
}

extension ScreenSizeContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// ¿Pantalla de escritorio (ancha)?
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
}

/// Ancho máximo del contenido según el ancho disponible: en el móvil se queda
/// en [base]; en pantallas anchas crece hasta [base] × 1.5 para aprovechar el
/// espacio sin estirar el contenido demasiado.
double adaptiveMaxWidth(double base, double screenWidth) {
  if (screenWidth >= Breakpoints.extraWide) return base * 1.5;
  if (screenWidth >= Breakpoints.wide) {
    final t = (screenWidth - Breakpoints.wide) / (Breakpoints.extraWide - Breakpoints.wide);
    return base * (1 + 0.5 * t);
  }
  return base;
}
