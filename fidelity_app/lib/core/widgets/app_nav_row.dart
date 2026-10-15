import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';

/// Fila con forma de píldora que lleva a otra pantalla o acción
/// (p. ej. "Cambiar contraseña", "Ajustar mi campaña").
class AppNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AppNavRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const double _radius = 36;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(icon, size: 24, color: AppColors.black),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body(size: 17, weight: FontWeight.w300),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 32,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
