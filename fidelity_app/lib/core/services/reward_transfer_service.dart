import 'api_client.dart';

/// Servicio para transferir premios entre usuarios.
class RewardTransferService {
  final ApiClient _api = ApiClient();

  RewardTransferService([dynamic _]);

  /// Busca un usuario por email.
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _api.get('users/search', queryParams: {'q': normalizedEmail});
      if (response is List && response.isNotEmpty) {
        final match = response.firstWhere(
          (u) => u['email']?.toString().toLowerCase() == normalizedEmail,
          orElse: () => null,
        );
        if (match != null) {
          return {
            'id': match['id'],
            'email': match['email'],
            'full_name': match['fullName'] ?? match['full_name'],
            'role': match['role'] ?? 'client',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Transfiere un premio a otro usuario por email.
  Future<void> transferReward(String rewardId, String toEmail) async {
    final normalizedEmail = toEmail.trim().toLowerCase();
    try {
      await _api.post('rewards/transfer', body: {
        'rewardId': rewardId,
        'toEmail': normalizedEmail,
      });
    } on ApiException catch (e) {
      throw TransferException('ERROR', e.message);
    } catch (e) {
      throw TransferException('ERROR', 'Error al transferir: $e');
    }
  }
}

class TransferException implements Exception {
  final String code;
  final String message;

  TransferException(this.code, this.message);

  @override
  String toString() => message;
}
