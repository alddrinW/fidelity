import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';

enum AppChipStyle {
  /// Fondo rosa: estados informativos o pendientes ("NUEVO", "PENDIENTE").
  pink,

  /// Fondo negro: estados que piden atención o ya resueltos ("PREMIO LISTO").
  dark,

  /// Solo contorno: estados neutros o negativos ("RECHAZADO").
  outline,
}

/// Etiqueta de estado en forma de píldora.
class AppChip extends StatelessWidget {
  final String label;
  final AppChipStyle style;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    this.style = AppChipStyle.pink,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color? border) = switch (style) {
      AppChipStyle.pink => (AppColors.pink, AppColors.black, null),
      AppChipStyle.dark => (AppColors.black, AppColors.white, null),
      AppChipStyle.outline => (AppColors.white, AppColors.black, AppColors.black),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          // Flexible: si la etiqueta es larga, se acorta en vez de salirse.
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(size: 10, tracking: 1.5, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
