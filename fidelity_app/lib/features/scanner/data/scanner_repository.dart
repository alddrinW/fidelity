import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository();
});

/// Resultado de un escaneo válido, tal como lo devuelve `POST scans/validate`.
class ScanResult {
  final String? businessId;
  final String businessName;
  final int? currentPoints;
  final int? pointsRequired;
  final bool rewardCompleted;
  final String? rewardDescription;

  /// El escaneo quedó registrado pero el negocio aún debe aprobarlo; el punto
  /// se suma recién al aprobarse.
  final bool isPending;

  const ScanResult({
    this.businessId,
    required this.businessName,
    this.currentPoints,
    this.pointsRequired,
    this.rewardCompleted = false,
    this.rewardDescription,
    this.isPending = false,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      businessId: json['businessId']?.toString(),
      businessName: json['businessName']?.toString() ?? 'Local',
      currentPoints: (json['currentPoints'] as num?)?.toInt(),
      pointsRequired: (json['pointsRequired'] as num?)?.toInt(),
      rewardCompleted: json['rewardCompleted'] == true,
      rewardDescription: json['rewardDescription']?.toString(),
      isPending: json['status'] == 'pending',
    );
  }
}

class ScannerRepository {
  final ApiClient _api = ApiClient();

  ScannerRepository();

  Future<ScanResult> validateScan(String qrCode) async {
    final response = await _api.post('scans/validate', body: {
      'qr_code': qrCode.trim(),
    });

    if (response is Map<String, dynamic>) {
      return ScanResult.fromJson(response);
    }
    return const ScanResult(businessName: 'Local');
  }
}
