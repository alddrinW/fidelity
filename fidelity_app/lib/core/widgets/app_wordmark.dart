import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Logotipo tipográfico "FIDELITY" (sin mascota).
class AppWordmark extends StatelessWidget {
  final double size;
  final Color color;

  const AppWordmark({super.key, this.size = 72, this.color = AppColors.black});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fidelity',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'FIDELITY',
          style: AppTypography.display(size: size, color: color)
              .copyWith(letterSpacing: 1, height: 1),
        ),
      ),
    );
  }
}
