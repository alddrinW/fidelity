import 'package:flutter/material.dart' hide Text;

import '../../../../core/l10n/tr_text.dart';
import '../../../../core/l10n/translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fido_mascot.dart';

/// Un acceso directo de la guía de Fido.
class FidoGuideAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const FidoGuideAction({required this.label, required this.icon, required this.onTap});
}

/// Fido da la bienvenida al dueño en el encabezado de su panel y le ofrece
/// accesos directos (crear una campaña, revisar sus sucursales...). Se puede
/// cerrar con la X.
class FidoGuideStrip extends StatelessWidget {
  final String message;
  final List<FidoGuideAction> actions;
  final VoidCallback onDismiss;

  const FidoGuideStrip({
    super.key,
    required this.message,
    required this.actions,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.pink,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FidoMascot(mood: FidoMood.calm, height: 64),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: AppTypography.body(size: 14, weight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final action in actions)
                        ActionChip(
                          avatar: Icon(action.icon, size: 16, color: AppColors.black),
                          label: Text(action.label, style: AppTypography.label(size: 11, tracking: 1.5)),
                          backgroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.black, width: 1.2),
                          shape: const StadiumBorder(),
                          onPressed: action.onTap,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('Cerrar'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
