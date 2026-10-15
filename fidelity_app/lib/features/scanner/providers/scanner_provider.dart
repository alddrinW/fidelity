import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../data/scanner_repository.dart';

/// Estado del escáner. Cada transición establece solo los campos que aplican:
/// `copyWith` NO conserva mensajes previos, de modo que un resultado se
/// consume una vez (ver [ScannerNotifier.reset]).
class ScannerState {
  final bool isProcessing;
  final String? error;

  /// Mensaje del backend con el tiempo restante cuando el local aún no
  /// permite otro escaneo (HTTP 429).
  final String? cooldownMessage;
  final bool hasPendingReward;

  /// Mensaje del backend cuando el cliente ya tiene un escaneo esperando la
  /// aprobación del negocio en ese local.
  final String? pendingScanMessage;
  final ScanResult? result;

  const ScannerState({
    this.isProcessing = false,
    this.error,
    this.cooldownMessage,
    this.hasPendingReward = false,
    this.pendingScanMessage,
    this.result,
  });

  ScannerState copyWith({
    bool? isProcessing,
    String? error,
    String? cooldownMessage,
    bool hasPendingReward = false,
    String? pendingScanMessage,
    ScanResult? result,
  }) {
    return ScannerState(
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      cooldownMessage: cooldownMessage,
      hasPendingReward: hasPendingReward,
      pendingScanMessage: pendingScanMessage,
      result: result,
    );
  }

  ScannerState clearMessages() => ScannerState(isProcessing: isProcessing);
}

class ScannerNotifier extends Notifier<ScannerState> {
  @override
  ScannerState build() => const ScannerState();

  void reset() {
    state = state.clearMessages();
  }

  Future<void> validateScan(String qrCode) async {
    if (state.isProcessing) return;

    state = state.copyWith(isProcessing: true);

    try {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final result = await ref.read(scannerRepositoryProvider).validateScan(qrCode);
      state = state.copyWith(isProcessing: false, result: result);
    } on ApiException catch (e) {
      final message = e.message.toLowerCase();
      if (e.statusCode == 429) {
        state = state.copyWith(isProcessing: false, cooldownMessage: e.message);
      } else if (e.details == 'pending_scan') {
        state = state.copyWith(isProcessing: false, pendingScanMessage: e.message);
      } else if (e.details == 'pending_reward' ||
          e.message.contains('PENDING_REWARD') ||
          message.contains('premio pendiente')) {
        state = state.copyWith(isProcessing: false, hasPendingReward: true);
      } else {
        state = state.copyWith(isProcessing: false, error: e.message);
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }
}

final scannerProvider = NotifierProvider<ScannerNotifier, ScannerState>(() {
  return ScannerNotifier();
});
