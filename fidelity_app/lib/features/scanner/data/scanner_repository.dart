import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository();
});

class ScannerRepository {
  final ApiClient _api = ApiClient();

  ScannerRepository();

  Future<String> validateScan(String qrCode, String userId) async {
    final response = await _api.post('scans/validate', body: {
      'qr_code': qrCode.trim(),
    });

    if (response is Map<String, dynamic>) {
      return response['businessName']?.toString() ?? 'Local';
    }
    return 'Local';
  }
}
