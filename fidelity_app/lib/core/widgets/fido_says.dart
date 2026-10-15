import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';
import 'fido_mascot.dart';

/// Fido con un globo de diálogo: lo usan los asistentes guiados (pago,
/// buzón de sugerencias...) para hablarle al usuario.
class FidoSays extends StatelessWidget {
  final String message;
  final double fidoHeight;

  /// Fido celebrando (brazos arriba) en lugar de su pose neutra.
  final bool celebrating;

  const FidoSays({
    super.key,
    required this.message,
    this.fidoHeight = 96,
    this.celebrating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FidoMascot(
          mood: celebrating ? FidoMood.celebrate : FidoMood.calm,
          height: fidoHeight,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.pink,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Text(
              message,
              style: AppTypography.body(size: 16, weight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}
