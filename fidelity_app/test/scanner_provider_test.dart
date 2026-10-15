import 'package:fidelity_app/core/services/api_client.dart';
import 'package:fidelity_app/features/auth/data/auth_repository.dart';
import 'package:fidelity_app/features/scanner/data/scanner_repository.dart';
import 'package:fidelity_app/features/scanner/providers/scanner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends AuthRepository {
  @override
  AuthUser? get currentUser => AuthUser(
        id: 'u1',
        email: 'ana@example.com',
        fullName: 'Ana Perez',
        role: 'client',
        raw: const {},
      );
}

class _FakeScannerRepo extends ScannerRepository {
  final Future<ScanResult> Function() handler;
  _FakeScannerRepo(this.handler);

  @override
  Future<ScanResult> validateScan(String qrCode) => handler();
}

ProviderContainer _container(Future<ScanResult> Function() handler) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(_FakeAuth()),
    scannerRepositoryProvider.overrideWithValue(_FakeScannerRepo(handler)),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<ScannerState> _scan(ProviderContainer container) async {
  await container.read(scannerProvider.notifier).validateScan('FID-1');
  return container.read(scannerProvider);
}

void main() {
  group('ScanResult.fromJson', () {
    test('un escaneo recién hecho llega como pendiente', () {
      final result = ScanResult.fromJson({
        'success': true,
        'status': 'pending',
        'businessName': 'Café Central',
        'currentPoints': 2,
        'pointsRequired': 10,
        'rewardCompleted': false,
      });

      expect(result.isPending, isTrue);
      expect(result.businessName, 'Café Central');
      expect(result.currentPoints, 2);
      expect(result.rewardCompleted, isFalse);
    });

    test('sin estado no se considera pendiente', () {
      expect(ScanResult.fromJson({'businessName': 'X'}).isPending, isFalse);
    });
  });

  group('ScannerNotifier.validateScan', () {
    test('escaneo registrado: guarda el resultado pendiente', () async {
      final container = _container(() async =>
          const ScanResult(businessName: 'Café Central', isPending: true));

      final state = await _scan(container);

      expect(state.isProcessing, isFalse);
      expect(state.result?.isPending, isTrue);
      expect(state.error, isNull);
    });

    test('429: muestra el mensaje real del backend con el tiempo restante', () async {
      final container = _container(() async => throw ApiException(
            'Ya escaneaste en Café. Vuelve en 3h 0min',
            statusCode: 429,
          ));

      final state = await _scan(container);

      expect(state.cooldownMessage, contains('Vuelve en 3h'));
      expect(state.result, isNull);
    });

    test('409 pending_scan: avisa que ya hay un escaneo esperando aprobación', () async {
      final container = _container(() async => throw ApiException(
            'Ya tienes un escaneo pendiente en Café.',
            statusCode: 409,
            details: 'pending_scan',
          ));

      final state = await _scan(container);

      expect(state.pendingScanMessage, contains('escaneo pendiente'));
      expect(state.hasPendingReward, isFalse);
      expect(state.error, isNull);
    });

    test('409 pending_reward: avisa que hay un premio por reclamar', () async {
      final container = _container(() async => throw ApiException(
            'Tienes un premio pendiente en Café.',
            statusCode: 409,
            details: 'pending_reward',
          ));

      final state = await _scan(container);

      expect(state.hasPendingReward, isTrue);
      expect(state.pendingScanMessage, isNull);
    });

    test('otros errores se muestran tal cual', () async {
      final container = _container(
          () async => throw ApiException('QR invalido o negocio inactivo', statusCode: 404));

      final state = await _scan(container);

      expect(state.error, 'QR invalido o negocio inactivo');
      expect(state.cooldownMessage, isNull);
    });
  });
}
