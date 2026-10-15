import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/l10n/tr_text.dart';

/// Métrica del negocio: número grande, etiqueta y un icono. Si recibe [onTap]
/// muestra una flecha y abre el detalle.
class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AppTypography.label(size: 12, tracking: 3)),
                const SizedBox(height: 4),
                Text(value, style: AppTypography.display(size: 44))
                    .animate()
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      duration: 500.ms,
                      curve: const Cubic(0.34, 1.56, 0.64, 1),
                    ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: AppColors.black),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 28),
          ],
        ],
      ),
    );
  }
}
