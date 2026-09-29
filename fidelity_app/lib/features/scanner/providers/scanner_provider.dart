import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../data/scanner_repository.dart';

class ScannerState {
  final bool isProcessing;
  final String? error;
  final String? cooldownHours;
  final bool hasPendingReward;
  final String? successBusinessName;

  ScannerState({
    this.isProcessing = false,
    this.error,
    this.cooldownHours,
    this.hasPendingReward = false,
    this.successBusinessName,
  });

  ScannerState copyWith({
    bool? isProcessing,
    String? error,
    String? cooldownHours,
    bool? hasPendingReward,
    String? successBusinessName,
  }) {
    return ScannerState(
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      cooldownHours: cooldownHours,
      hasPendingReward: hasPendingReward ?? false,
      successBusinessName: successBusinessName,
    );
  }

  ScannerState clearMessages() {
    return ScannerState(
      isProcessing: isProcessing,
      error: null,
      cooldownHours: null,
      hasPendingReward: false,
      successBusinessName: null,
    );
  }
}

class ScannerNotifier extends Notifier<ScannerState> {
  @override
  ScannerState build() {
    return ScannerState();
  }

  void reset() {
    state = state.clearMessages();
  }

  Future<void> validateScan(String qrCode) async {
    if (state.isProcessing) return;

    state = state.copyWith(isProcessing: true).clearMessages();

    try {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final businessName = await ref.read(scannerRepositoryProvider).validateScan(qrCode, userId);

      state = state.copyWith(
        isProcessing: false,
        successBusinessName: businessName,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 429 || e.message.toLowerCase().contains('cooldown') || e.message.toLowerCase().contains('espera')) {
        state = state.copyWith(
          isProcessing: false,
          error: e.message,
          cooldownHours: '4',
        );
      } else if (e.message.contains('PENDING_REWARD') || e.message.toLowerCase().contains('premio pendiente')) {
        state = state.copyWith(
          isProcessing: false,
          hasPendingReward: true,
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
    }
  }
}

final scannerProvider = NotifierProvider<ScannerNotifier, ScannerState>(() {
  return ScannerNotifier();
});
