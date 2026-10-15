import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import '../l10n/tr_text.dart';

/// Celebración a pantalla de diálogo (premio ganado, premio transferido): Fido
/// con los brazos arriba y confeti rosa y negro.
class GlobalCelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String iconType; // 'reward' or 'transfer'

  const GlobalCelebrationDialog({
    super.key,
    required this.title,
    required this.message,
    this.iconType = 'reward',
  });

  // Evita que se apilen varios diálogos de celebración a la vez (por ejemplo si
  // el push y el realtime disparan casi juntos). Solo se muestra uno.
  static bool _isOpen = false;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String iconType = 'reward',
  }) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => GlobalCelebrationDialog(
          title: title,
          message: message,
          iconType: iconType,
        ),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  State<GlobalCelebrationDialog> createState() => _GlobalCelebrationDialogState();
}

class _GlobalCelebrationDialogState extends State<GlobalCelebrationDialog> {
  late final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 24,
            maxBlastForce: 60,
            minBlastForce: 30,
            gravity: 0.15,
            colors: const [AppColors.pink, AppColors.black],
          ),
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/fido_celebra.png',
                  height: 170,
                  fit: BoxFit.contain,
                  semanticLabel: 'Fido celebrando',
                ).animate().scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 600.ms,
                      curve: const Cubic(0.34, 1.56, 0.64, 1),
                    ),
                const SizedBox(height: 16),
                Text(
                  widget.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 16, weight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        AppPrimaryButton(label: 'Entendido', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
