import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/fido_mascot.dart';
import '../../core/widgets/fido_says.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'providers/scanner_provider.dart';
import 'scan_success_screen.dart';
import '../../core/l10n/tr_text.dart';

/// El backend responde "Ya escaneaste en X. Vuelve en 3h 20min"; Fido lo dice
/// con más calma. Si el mensaje no tiene ese formato, se muestra tal cual.
String friendlyCooldownMessage(String message) {
  final parsed = RegExp(r'^Ya escaneaste en (.+)\. Vuelve en (.+)$').firstMatch(message.trim());
  if (parsed == null) return message;
  return 'Tu próximo punto en ${parsed.group(1)} estará listo en ${parsed.group(2)}.';
}

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();

  static const _textShadow = [
    Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
  ];

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _showCooldownDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.hourglass_top_rounded,
        leading: const FidoCooldownBanner(),
        title: '¡Paciencia!',
        message: friendlyCooldownMessage(message),
        hint: 'Cada local tiene un tiempo de espera entre escaneos. '
            'Mientras tanto, puedes escanear en otros locales.',
        primaryLabel: 'Vale',
        onPrimary: cameraController.start,
      ),
    );
  }

  void _showPendingScanDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.pending_actions_rounded,
        title: 'Escaneo pendiente',
        message: message,
        hint: 'Cuando el local lo apruebe, sumarás tu punto.',
        primaryLabel: 'Entendido',
        onPrimary: cameraController.start,
      ),
    );
  }

  void _showPendingRewardDialog() {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.card_giftcard_rounded,
        title: 'Tienes un premio pendiente',
        message:
            'Reclámalo en este local antes de seguir acumulando puntos.',
        primaryLabel: 'Entendido',
        onPrimary: cameraController.start,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.qr_code_scanner_rounded,
        leading: const FidoMascot(mood: FidoMood.sad, height: 120),
        title: 'No se pudo escanear',
        message: message,
        primaryLabel: 'Reintentar',
        onPrimary: cameraController.start,
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            denied
                ? 'Necesitamos acceso a la cámara para escanear el código QR. '
                    'Actívalo en los permisos del dispositivo.'
                : 'No pudimos iniciar la cámara. Cierra esta pantalla e inténtalo de nuevo.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 17, color: AppColors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider);

    ref.listen<ScannerState>(scannerProvider, (previous, next) {
      if (previous?.isProcessing != true || next.isProcessing) return;

      final result = next.result;
      if (result != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ScanSuccessScreen(result: result)),
        );
      } else if (next.cooldownMessage != null) {
        _showCooldownDialog(next.cooldownMessage!);
      } else if (next.pendingScanMessage != null) {
        _showPendingScanDialog(next.pendingScanMessage!);
      } else if (next.hasPendingReward) {
        _showPendingRewardDialog();
      } else if (next.error != null) {
        _showErrorDialog(next.error!);
      }
      ref.read(scannerProvider.notifier).reset();
    });

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cameraController,
            errorBuilder: (context, error, child) => _buildCameraError(error),
            onDetect: (capture) {
              if (state.isProcessing) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  cameraController.stop();
                  ref.read(scannerProvider.notifier).validateScan(code);
                  break;
                }
              }
            },
          ),

          // Degradado superior para que el título se lea sobre cualquier imagen.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: AppResponsiveBody(
              maxWidth: 600,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ValueListenableBuilder<MobileScannerState>(
                      valueListenable: cameraController,
                      // Con la cámara en error el mensaje ocupa el lugar del marco.
                      builder: (context, scanner, _) => scanner.error != null
                          ? const SizedBox.shrink()
                          : Center(child: _buildViewfinder(context)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: FidoSays(
                      message: 'Apunta al código QR del local y yo me encargo del resto.',
                      fidoHeight: 64,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (state.isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.white),
                    const SizedBox(height: 24),
                    Text(
                      'VALIDANDO...',
                      style: AppTypography.display(
                        size: 24,
                        color: AppColors.white,
                      ).copyWith(letterSpacing: 2),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 1, end: 0.3),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: IconButton(
              tooltip: 'Volver',
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 40,
                color: AppColors.white,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'APUNTA BIEN',
                  style: AppTypography.display(
                    size: 48,
                    color: AppColors.white,
                  ).copyWith(shadows: _textShadow),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, scanner, _) {
                final on = scanner.torchState == TorchState.on;
                final available = scanner.torchState != TorchState.unavailable;
                return IconButton(
                  tooltip: on ? 'Apagar linterna' : 'Encender linterna',
                  icon: Icon(
                    on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    size: 28,
                    color: available ? AppColors.white : Colors.white38,
                  ),
                  onPressed: available ? cameraController.toggleTorch : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).width * 0.65).clamp(220.0, 320.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.white, width: 4),
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'ESCANEA EL CÓDIGO QR\nY POR FAVOR... APUNTA BIEN',
          textAlign: TextAlign.center,
          style: AppTypography.label(
            size: 15,
            tracking: 0.5,
            color: AppColors.white,
          ).copyWith(shadows: _textShadow),
        ),
      ],
    );
  }
}
