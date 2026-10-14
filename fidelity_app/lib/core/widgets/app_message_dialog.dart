import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Diálogo de mensaje con el estilo de marca: icono en halo rosa, título
/// Anton, texto y botón principal negro. Opcionalmente un botón secundario.
///
/// Los botones cierran el diálogo antes de ejecutar su acción.
class AppMessageDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? hint;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppMessageDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.hint,
    this.primaryLabel = 'Entendido',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.pink,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.black),
          ),
          const SizedBox(height: 20),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 16, weight: FontWeight.w400),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPrimaryButton(
              label: primaryLabel,
              onPressed: () {
                navigator.pop();
                onPrimary?.call();
              },
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 4),
              AppTextAction(
                label: secondaryLabel!,
                onPressed: () {
                  navigator.pop();
                  onSecondary?.call();
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}
