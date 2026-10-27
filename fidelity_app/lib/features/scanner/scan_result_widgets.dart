import 'package:flutter/material.dart' hide Text;

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// El botón blanco con borde negro de las pantallas rosas (p. ej. "VER MI PREMIO").
class ScanWhiteButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ScanWhiteButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          side: const BorderSide(color: AppColors.black, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            style: AppTypography.label(size: 16, tracking: 6, color: AppColors.black),
          ),
        ),
      ),
    );
  }
}

/// La caja negra del premio: lo que ganó el cliente, en grande.
class ScanPrizeBox extends StatelessWidget {
  final String prize;

  const ScanPrizeBox({super.key, required this.prize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Text('TU PREMIO', style: AppTypography.label(size: 11, tracking: 5, color: AppColors.pink)),
          const SizedBox(height: 6),
          Text(
            prize.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display(size: 26, color: AppColors.white).copyWith(height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// "Suele tardar unos minutos": una pastilla con un reloj, para calmar la espera.
class ScanWaitChip extends StatelessWidget {
  const ScanWaitChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Suele tardar unos minutos', style: AppTypography.body(size: 15, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
