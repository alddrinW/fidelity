import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class ProfileRepository {
  final ApiClient _api = ApiClient();

  ProfileRepository();

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await _api.get('users/profile/$userId');
      if (response is Map<String, dynamic>) {
        return {
          'id': response['id'],
          'full_name': response['fullName'] ?? response['full_name'],
          'email': response['email'],
          'phone': response['phone'],
          'avatar_url': response['avatarUrl'] ?? response['avatar_url'],
          'role': response['role'] ?? 'client',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    await _api.put('users/profile', body: {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
    });
  }
}
