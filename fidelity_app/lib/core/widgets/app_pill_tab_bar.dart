import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';

/// Pestañas en forma de píldora: la activa va en negro y las demás con
/// contorno. Usa el [TabController] más cercano (p. ej. de un
/// `DefaultTabController`) y se desplaza si no caben todas.
class AppPillTabBar extends StatelessWidget {
  final List<String> labels;
  final TabController? controller;

  /// Contador opcional por pestaña (mismo orden que [labels]); se muestra
  /// como un círculo rosa si es mayor que 0. Útil para "pendientes".
  final List<int>? badges;

  const AppPillTabBar({
    super.key,
    required this.labels,
    this.controller,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);

    return SizedBox(
      height: 44,
      child: AnimatedBuilder(
        animation: tabController.animation ?? tabController,
        builder: (context, _) {
          final selected = tabController.index;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = index == selected;
              final badge = (badges != null && index < badges!.length) ? badges![index] : 0;
              return Semantics(
                button: true,
                selected: isSelected,
                label: badge > 0 ? '${labels[index]}, $badge pendientes' : labels[index],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => tabController.animateTo(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.black : AppColors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.black, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[index].toUpperCase(),
                          style: AppTypography.label(
                            size: 12,
                            tracking: 2,
                            color: isSelected ? AppColors.white : AppColors.black,
                          ),
                        ),
                        if (badge > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.pink,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge > 99 ? '99+' : '$badge',
                              textAlign: TextAlign.center,
                              style: AppTypography.label(
                                size: 10,
                                tracking: 0,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
