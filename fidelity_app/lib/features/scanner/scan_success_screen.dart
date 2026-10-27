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
import '../cards/card_history_screen.dart';
import 'data/scanner_repository.dart';
import 'scan_result_widgets.dart';
import '../../core/l10n/tr_text.dart';

/// Pantalla de cierre de un escaneo, con el diseño de Fido:
/// - **Punto sumado** (fondo rosa): el local, el avance en puntitos y *VER MI TARJETA*.
/// - **Tarjeta completa** (fondo rosa): el premio en una caja negra y *VER MI PREMIO*.
/// - **Esperando al local** (fondo blanco, Fido triste): el escaneo quedó pendiente y *ENTENDIDO*.
/// Se informa el progreso real que devolvió el backend.
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

  ScanResult get _r => widget.result;

  /// El título grande: lo que pasó con el escaneo.
  String get _title {
    if (_r.isPending) return 'ESPERANDO\nAL LOCAL';
    if (_r.rewardCompleted) return '¡COMPLETASTE\nTU TARJETA!';
    return '¡PUNTO\nSUMADO!';
  }

  /// El premio que ganó, o `null` si el local no lo describió.
  String? get _prize {
    final prize = _r.rewardDescription?.trim();
    return prize == null || prize.isEmpty ? null : prize;
  }

  /// Los puntitos solo se muestran con un punto ya sumado (no con el premio ni la espera).
  bool get _showProgress =>
      !_r.isPending && !_r.rewardCompleted && _r.pointsRequired != null && _r.currentPoints != null;

  /// Buzón de Fido: el cliente califica la atención recién recibida.
  Future<void> _openFeedback() async {
    final businessId = _r.businessId;
    if (businessId == null) return;
    await showFeedbackSheet(context, businessId: businessId, businessName: _r.businessName);
  }

  void _finish() {
    // La tarjeta ya se actualiza por tiempo real; esto cubre el caso en que
    // el socket no esté conectado.
    ref.read(myCardsProvider.notifier).refreshCards(silent: true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Vuelve al inicio y abre la tarjeta de este local (en su pestaña de premios).
  Future<void> _openCard() async {
    final navigator = Navigator.of(context);
    final businessId = _r.businessId;
    await ref.read(myCardsProvider.notifier).refreshCards(silent: true);
    final cards = ref.read(myCardsProvider).cards;
    final card = cards.where((c) => (c['businesses'] as Map?)?['id']?.toString() == businessId).firstOrNull;
    navigator.popUntil((route) => route.isFirst);
    if (card == null || businessId == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => CardHistoryScreen(
          loyaltyCardId: card['id'].toString(),
          businessId: businessId,
          businessName: _r.businessName,
          initialTabIndex: CardHistoryScreen.rewardsTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _r.isPending;
    final completed = _r.rewardCompleted;
    final prize = _prize;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        // Rosa al celebrar; blanco mientras espera.
        backgroundColor: pending ? AppColors.white : AppColors.pink,
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
                          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FidoMascot(
                                mood: pending
                                    ? FidoMood.sad
                                    : completed
                                        ? FidoMood.euphoric
                                        : FidoMood.celebrate,
                                height: 190,
                              )
                                  .animate()
                                  .scale(
                                    begin: const Offset(0.6, 0.6),
                                    duration: 700.ms,
                                    curve: const Cubic(0.34, 1.56, 0.64, 1),
                                  )
                                  .fadeIn(),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  _title,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.display(size: 52).copyWith(height: 1.05),
                                ),
                              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                              const SizedBox(height: 12),
                              if (pending) ...[
                                Text(
                                  'Tu escaneo en ${_r.businessName} está pendiente. Te avisaremos cuando lo aprueben.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body(size: 17, weight: FontWeight.w300),
                                ).animate(delay: 200.ms).fadeIn(),
                                const SizedBox(height: 16),
                                const ScanWaitChip().animate(delay: 300.ms).fadeIn(),
                              ] else if (completed) ...[
                                Text(
                                  prize == null
                                      ? 'Ganaste un premio en ${_r.businessName}. Pídelo en el local mostrando tu premio.'
                                      : '$prize en ${_r.businessName}. Pídelo en el local mostrando tu premio.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body(size: 17, weight: FontWeight.w300),
                                ).animate(delay: 200.ms).fadeIn(),
                                const SizedBox(height: 18),
                                ScanPrizeBox(prize: prize ?? 'Premio ganado').animate(delay: 300.ms).fadeIn(),
                              ] else ...[
                                Text(
                                  _r.businessName,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body(size: 20, weight: FontWeight.w500),
                                ).animate(delay: 200.ms).fadeIn(),
                                if (_showProgress) ...[
                                  const SizedBox(height: 16),
                                  ScanProgressDots(
                                    done: _r.currentPoints!,
                                    total: _r.pointsRequired!,
                                    onPink: true,
                                  ).animate(delay: 300.ms).fadeIn(),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${_r.currentPoints} de ${_r.pointsRequired} puntos',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body(size: 15, weight: FontWeight.w400),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pending)
                            AppPrimaryButton(label: 'Entendido', onPressed: _finish)
                          else if (completed)
                            ScanWhiteButton(label: 'Ver mi premio', onPressed: _openCard)
                          else
                            AppPrimaryButton(label: 'Ver mi tarjeta', onPressed: _openCard),
                          if (_r.businessId != null) ...[
                            const SizedBox(height: 4),
                            AppTextAction(label: 'Califica la atención', onPressed: _openFeedback),
                          ],
                        ],
                      ),
                    ).animate(delay: 400.ms).fadeIn(),
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
                colors: const [AppColors.white, AppColors.black],
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

  /// Sobre un fondo rosa los puntos ganados van negros (si no, no se verían).
  final bool onPink;

  const ScanProgressDots({super.key, required this.done, required this.total, this.onPink = false});

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
          color: onPink ? AppColors.black : AppColors.pink,
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
        color: on ? (onPink ? AppColors.black : AppColors.pink) : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: on ? Icon(Icons.check_rounded, size: 16, color: onPink ? AppColors.white : AppColors.black) : null,
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
