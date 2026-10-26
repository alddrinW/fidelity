import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';

/// Pantalla completa para cuando el cliente ya tiene un escaneo esperando la
/// aprobación del local: Fido espera con un reloj de arena y se le explica
/// cuándo sumará su punto. Al volver, el escáner sigue listo.
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
                    constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'ESPERANDO\nAL LOCAL',
                            textAlign: TextAlign.center,
                            style: AppTypography.display(size: 64).copyWith(height: 1.05),
                          ),
                        ).animate().fadeIn().slideY(begin: -0.2),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(size: 17, weight: FontWeight.w300),
                        ).animate(delay: 150.ms).fadeIn(),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.pink,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.black, width: 1.2),
                          ),
                          child: Text(
                            'Cuando el local lo apruebe, sumarás tu punto.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(size: 15, weight: FontWeight.w500),
                          ),
                        ).animate(delay: 250.ms).fadeIn(),
                        const SizedBox(height: 24),
                        const FidoCooldownBanner().animate(delay: 150.ms).fadeIn().scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 600.ms,
                              curve: const Cubic(0.34, 1.56, 0.64, 1),
                            ),
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
                    tooltip: 'Entendido',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
