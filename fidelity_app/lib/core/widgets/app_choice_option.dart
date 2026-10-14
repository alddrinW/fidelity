import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Opción grande seleccionable (icono + etiqueta espaciada). La opción
/// elegida se resalta con un halo rosa detrás del icono.
class AppChoiceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppChoiceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        // El estado seleccionado ya lo marca el halo rosa; sin resaltado gris.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: selected ? AppColors.pink : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 112, color: AppColors.black),
              ),
              const SizedBox(height: 8),
              Text(
                label.toUpperCase(),
                style: AppTypography.label(size: 20, tracking: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
