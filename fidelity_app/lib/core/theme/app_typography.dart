import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografías de marca.
///
/// El manual define TAN St. Canard (display), Futura (cuerpo) y
/// Anek Bangla Expanded (etiquetas). Al ser fuentes de pago o no disponibles
/// en Google Fonts se usan sus equivalentes abiertos: Anton, Jost y
/// Anek Latin con tracking amplio.
class AppTypography {
  AppTypography._();

  /// Títulos y números de impacto.
  static TextStyle display({double size = 36, Color color = AppColors.black}) {
    return GoogleFonts.anton(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      letterSpacing: 0.5,
      height: 1.1,
    );
  }

  /// Texto de interfaz, formularios y párrafos (estilo Futura ligera).
  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.black,
  }) {
    return GoogleFonts.jost(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );
  }

  /// Etiquetas, botones y encabezados de sección: extendida y espaciada.
  static TextStyle label({
    double size = 14,
    double tracking = 4,
    Color color = AppColors.black,
  }) {
    return GoogleFonts.anekLatin(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: tracking,
    );
  }
}
