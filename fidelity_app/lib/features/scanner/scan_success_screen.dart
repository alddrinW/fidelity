import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
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
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
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
                                  'ESCANEO\nEXITOSO',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.display(size: 64)
                                      .copyWith(height: 1.05),
                                ),
                              ).animate().fadeIn().slideY(begin: -0.2),
                              const SizedBox(height: 12),
                              Text(
                                _summary,
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  size: 17,
                                  weight: FontWeight.w300,
                                ),
                              ).animate(delay: 200.ms).fadeIn(),
                              if (widget.result.businessId != null)
                                AppTextAction(
                                  label: 'Califica la atención',
                                  onPressed: _openFeedback,
                                ).animate(delay: 400.ms).fadeIn(),
                              const SizedBox(height: 8),
                              Image.asset(
                                'assets/images/fido_celebra.png',
                                width: (MediaQuery.sizeOf(context).width * 0.8)
                                    .clamp(220.0, 340.0),
                                fit: BoxFit.contain,
                                semanticLabel: 'Fido celebrando',
                              )
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
