import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/fido_mascot.dart';
import '../data/games_repository.dart';

/// El final de una partida: si ganó, Fido celebra con confeti y se muestra el
/// código de su gift card; si no, Fido lo anima a seguir.
class GameResultView extends StatefulWidget {
  final GamePlay play;
  final VoidCallback onClose;

  /// Abre "Mis regalos" (solo si ganó una gift card).
  final VoidCallback? onOpenGifts;

  const GameResultView({super.key, required this.play, required this.onClose, this.onOpenGifts});

  @override
  State<GameResultView> createState() => _GameResultViewState();
}

class _GameResultViewState extends State<GameResultView> {
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.play.isWon) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final play = widget.play;
    final won = play.isWon;
    final code = play.claimCode;

    final title = won ? '¡GANASTE!' : 'ESTA VEZ NO';
    final message = won
        ? (code != null
            ? 'Tu premio: ${play.prizeLabel ?? 'una gift card'}. Ya está en Mis regalos.'
            : 'Ganaste, pero este premio ya lo tenías.')
        : 'Fido dice: ¡la próxima será! Usaste tus ${play.maxAttempts} intentos.';

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          child: Column(
            children: [
              FidoMascot(mood: won ? FidoMood.euphoric : FidoMood.sad, height: 170),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: AppTypography.display(size: 48))
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 16, weight: FontWeight.w300),
              ),
              if (play.game == GameKey.flappy && play.score != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Pasaste ${play.score} ${play.score == 1 ? 'tubo' : 'tubos'}.',
                  style: AppTypography.body(size: 15, weight: FontWeight.w500),
                ),
              ],
              if (won && code != null) ...[
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    children: [
                      Text('TU CÓDIGO', style: AppTypography.label(size: 12, tracking: 4)),
                      const SizedBox(height: 6),
                      SelectableText(code, style: AppTypography.display(size: 34)),
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado')),
                            );
                          }
                        },
                        child: const Text('Copiar código'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (won && code != null && widget.onOpenGifts != null) ...[
                AppPrimaryButton(label: 'Ver mi regalo', onPressed: widget.onOpenGifts),
                const SizedBox(height: 8),
              ],
              AppTextAction(label: 'Cerrar', onPressed: widget.onClose),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          maxBlastForce: 18,
          minBlastForce: 6,
          gravity: 0.25,
          shouldLoop: false,
          colors: const [AppColors.pink, AppColors.black],
        ),
      ],
    );
  }
}
