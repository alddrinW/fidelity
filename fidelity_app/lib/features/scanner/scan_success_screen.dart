import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fido_mascot.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../cards/providers/my_cards_provider.dart';
import '../feedback/widgets/feedback_sheet.dart';
import 'data/scanner_repository.dart';
import '../../core/l10n/tr_text.dart';

/// Pantalla de cierre de un escaneo válido: Fido celebra y se informa el
/// progreso real devuelto por el backend.
class ScanSuccessScreen extends ConsumerStatefulWidget {
  final ScanResult result;

  const ScanSuccessScreen({super.key, required this.result});

  @override
  ConsumerState<ScanSuccessScreen> createState() => _ScanSuccessScreenState();
}

class _ScanSuccessScreenState extends ConsumerState<ScanSuccessScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    // Un punto sumado o un premio se celebra; un escaneo pendiente solo espera.
    if (!widget.result.isPending) {
      _confetti.play();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// El título grande: lo que pasó con el escaneo.
  String get _title {
    final r = widget.result;
    if (r.isPending) return 'ESPERANDO\nAL LOCAL';
    if (r.rewardCompleted) return '¡PREMIO\nGANADO!';
    return '¡PUNTO\nSUMADO!';
  }

  String get _summary {
    final r = widget.result;
    if (r.isPending) {
      return 'Tu escaneo en ${r.businessName} quedó pendiente. '
          'Cuando el local lo apruebe, sumarás tu punto.';
    }
    if (r.rewardCompleted) {
      final prize = r.rewardDescription;
      return prize == null || prize.isEmpty
          ? 'Ganaste un premio en ${r.businessName}. Acércate al local para reclamarlo.'
          : 'Ganaste $prize en ${r.businessName}. Acércate al local para reclamarlo.';
    }
    final points = r.currentPoints;
    final required = r.pointsRequired;
    if (points != null && required != null) {
      return 'Sumaste un punto en ${r.businessName}. Llevas $points de $required.';
    }
    return 'Sumaste un punto en ${r.businessName}.';
  }

  /// Los puntitos de avance solo se muestran con un punto ya sumado.
  bool get _showProgress {
    final r = widget.result;
    if (r.isPending || r.pointsRequired == null) return false;
    return r.rewardCompleted || r.currentPoints != null;
  }

  /// Frase de ánimo de Fido según cómo terminó el escaneo.
  String get _cheer {
    final r = widget.result;
    if (r.rewardCompleted) return '¡Lo lograste! Fido salta de la emoción';
    if (r.isPending) return '¡Buen trabajo! Fido ya avisó al local';
    return '¡Eso es! Cada punto te acerca a tu premio';
  }

  /// Buzón de Fido: el cliente califica la atención recién recibida.
  Future<void> _openFeedback() async {
    final businessId = widget.result.businessId;
    if (businessId == null) return;
    await showFeedbackSheet(
      context,
      businessId: businessId,
      businessName: widget.result.businessName,
    );
  }

  void _finish() {
    // La tarjeta ya se actualiza por tiempo real; esto cubre el caso en que
    // el socket no esté conectado.
    ref.read(myCardsProvider.notifier).refreshCards(silent: true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              AppResponsiveBody(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.sizeOf(context).height * 0.7,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  _title,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.display(size: 64)
                                      .copyWith(height: 1.05),
                                ),
                              ).animate().fadeIn().slideY(begin: -0.2),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.pink,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.black, width: 1.2),
                                ),
                                child: Text(
                                  _cheer,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body(size: 15, weight: FontWeight.w500),
                                ),
                              ).animate(delay: 100.ms).fadeIn(),
                              const SizedBox(height: 12),
                              Text(
                                _summary,
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  size: 17,
                                  weight: FontWeight.w300,
                                ),
                              ).animate(delay: 200.ms).fadeIn(),
                              if (_showProgress) ...[
                                const SizedBox(height: 16),
                                ScanProgressDots(
                                  done: widget.result.rewardCompleted
                                      ? widget.result.pointsRequired!
                                      : widget.result.currentPoints!,
                                  total: widget.result.pointsRequired!,
                                ).animate(delay: 300.ms).fadeIn(),
                              ],
                              if (widget.result.businessId != null)
                                AppTextAction(
                                  label: 'Califica la atención',
                                  onPressed: _openFeedback,
                                ).animate(delay: 400.ms).fadeIn(),
                              const SizedBox(height: 8),
                              (widget.result.isPending
                                      ? const FidoCooldownBanner()
                                      : FidoMascot(
                                          mood: widget.result.rewardCompleted
                                              ? FidoMood.euphoric
                                              : FidoMood.celebrate,
                                          width: (MediaQuery.sizeOf(context).width * 0.8)
                                              .clamp(220.0, 340.0),
                                        ))
                                  .animate(delay: 150.ms)
                                  .scale(
                                    begin: const Offset(0.6, 0.6),
                                    duration: 700.ms,
                                    curve: const Cubic(0.34, 1.56, 0.64, 1),
                                  )
                                  .fadeIn(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 32, 32),
                        child: AppCircleButton(
                          dark: true,
                          tooltip: 'Volver al inicio',
                          onPressed: _finish,
                        ),
                      ),
                    ),
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
          ),
        ),
      ),
    );
  }
}

/// Un punto por cada sello de la tarjeta; los ganados van rosas con visto y el
/// último se llena con un pequeño salto. Con muchos sellos, una barra.
class ScanProgressDots extends StatelessWidget {
  final int done;
  final int total;

  const ScanProgressDots({super.key, required this.done, required this.total});

  static const int maxDots = 12;

  @override
  Widget build(BuildContext context) {
    final count = total < 1 ? 1 : total;
    final filled = done.clamp(0, count);

    if (count > maxDots) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: filled / count,
          minHeight: 14,
          backgroundColor: AppColors.surfaceMuted,
          color: AppColors.pink,
        ),
      );
    }

    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: '$filled de $count',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < count; i++)
            _dot(i < filled, i == filled - 1 && !still)
        ],
      ),
    );
  }

  Widget _dot(bool on, bool newest) {
    final dot = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: on ? AppColors.pink : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: on ? const Icon(Icons.check_rounded, size: 16, color: AppColors.black) : null,
    );
    if (!newest) return dot;
    // El sello recién ganado entra con un salto elástico.
    return dot.animate(delay: 500.ms).scale(
          begin: const Offset(0.2, 0.2),
          duration: 600.ms,
          curve: Curves.elasticOut,
        );
  }
}
