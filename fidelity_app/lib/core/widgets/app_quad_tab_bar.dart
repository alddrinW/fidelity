import 'package:flutter/material.dart' hide Text;

import '../l10n/tr_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Cuatro secciones en un cuadrado dividido en cuatro partes (2 × 2): cada
/// parte lleva su ícono y su nombre, y la activa va en negro. Sirve de menú
/// cuando hay cuatro secciones (siempre cuatro: ni más ni menos) y no caben como pastillas en un teléfono.
class AppQuadTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final List<IconData> icons;

  /// Contador opcional por sección (mismo orden que [labels]); se muestra como
  /// un círculo rosa si es mayor que 0.
  final List<int>? badges;

  /// Alto de cada fila del cuadrado.
  final double cellHeight;

  const AppQuadTabBar({
    super.key,
    required this.controller,
    required this.labels,
    required this.icons,
    this.badges,
    this.cellHeight = 76,
  });

  static const double _line = 1.2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: controller.animation ?? controller,
        builder: (context, _) {
          final selected = controller.index;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.black, width: _line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28 - _line),
              child: Column(
                children: [
                  _row(0, selected),
                  Container(height: _line, color: AppColors.black),
                  _row(2, selected),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(int first, int selected) {
    return SizedBox(
      height: cellHeight,
      child: Row(
        children: [
          Expanded(child: _cell(first, selected)),
          Container(width: _line, color: AppColors.black),
          Expanded(child: _cell(first + 1, selected)),
        ],
      ),
    );
  }

  Widget _cell(int index, int selected) {
    final isSelected = index == selected;
    final badge = (badges != null && index < badges!.length) ? badges![index] : 0;
    final foreground = isSelected ? AppColors.white : AppColors.black;

    return Semantics(
      button: true,
      selected: isSelected,
      label: badge > 0 ? '${labels[index]}, $badge pendientes' : labels[index],
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: isSelected ? AppColors.black : AppColors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icons[index], size: 26, color: foreground),
                    if (badge > 0)
                      Positioned(
                        top: -6,
                        right: -14,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.pink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            textAlign: TextAlign.center,
                            style: AppTypography.label(size: 10, tracking: 0, color: AppColors.black),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index].toUpperCase(),
                  maxLines: 1,
                  style: AppTypography.label(size: 12, tracking: 2, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
