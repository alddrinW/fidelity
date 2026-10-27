import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import 'scan_result_widgets.dart';

/// Pantalla completa para cuando el cliente ya tiene un escaneo esperando la
/// aprobación del local: Fido triste espera con él, se le dice que le avisaremos
/// y se le calma con "Suele tardar unos minutos". Al volver, el escáner sigue listo.
class ScanWaitingScreen extends StatelessWidget {
  /// Lo que dijo el servidor (por ejemplo, en qué local está esperando).
  final String message;

  const ScanWaitingScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
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
                        const FidoMascot(mood: FidoMood.sad, height: 190).animate().fadeIn().scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 600.ms,
                              curve: const Cubic(0.34, 1.56, 0.64, 1),
                            ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(
                            'ESPERANDO\nAL LOCAL',
                            textAlign: TextAlign.center,
                            style: AppTypography.display(size: 52).copyWith(height: 1.05),
                          ),
                        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(size: 17, weight: FontWeight.w300),
                        ).animate(delay: 200.ms).fadeIn(),
                        const SizedBox(height: 16),
                        const ScanWaitChip().animate(delay: 300.ms).fadeIn(),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                child: AppPrimaryButton(
                  label: 'Entendido',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
