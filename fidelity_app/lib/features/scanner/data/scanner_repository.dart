import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository();
});

/// Resultado de un escaneo válido, tal como lo devuelve `POST scans/validate`.
class ScanResult {
  final String businessName;
  final int? currentPoints;
  final int? pointsRequired;
  final bool rewardCompleted;
  final String? rewardDescription;

  const ScanResult({
    required this.businessName,
    this.currentPoints,
    this.pointsRequired,
    this.rewardCompleted = false,
    this.rewardDescription,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      businessName: json['businessName']?.toString() ?? 'Local',
      currentPoints: (json['currentPoints'] as num?)?.toInt(),
      pointsRequired: (json['pointsRequired'] as num?)?.toInt(),
      rewardCompleted: json['rewardCompleted'] == true,
      rewardDescription: json['rewardDescription']?.toString(),
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
