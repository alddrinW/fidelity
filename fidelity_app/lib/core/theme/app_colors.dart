import 'package:flutter/material.dart';

/// Paleta oficial "Pop-Minimalist" de Fidelity, tomada de los mockups y del
/// manual de marca (blanco, negro y rosa). Valores rosa medidos sobre los
/// mockups de `docs/designs`.
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// Rosa de marca: domo de la mascota, botones circulares de avance.
  static const Color pink = Color(0xFFFEBFDC);

  /// Relleno neutro de placeholders (avatar, logo de negocio).
  static const Color surfaceMuted = Color(0xFFF5F5F5);
  static const Color placeholderIcon = Color(0xFFAAAAAA);

  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF666666);

  static const Color border = black;
  static const Color error = Color(0xFFFF4949);
  static const Color success = Color(0xFF76D672);
}
