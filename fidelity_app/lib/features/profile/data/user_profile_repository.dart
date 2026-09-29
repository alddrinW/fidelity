import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_client.dart';

class UserProfileRepository {
  final ApiClient _api = ApiClient();

  UserProfileRepository();

  Future<Map<String, dynamic>?> getProfile([String? userId]) async {
    final endpoint = userId != null ? 'users/profile/$userId' : 'users/profile';
    final response = await _api.get(endpoint);
    if (response is Map<String, dynamic>) {
      return {
        'id': response['id'],
        'full_name': response['fullName'] ?? response['full_name'] ?? '',
        'email': response['email'] ?? '',
        'phone': response['phone'] ?? '',
        'avatar_url': response['avatarUrl'] ?? response['avatar_url'],
        'role': response['role'] ?? 'client',
      };
    }
    return null;
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    XFile? avatarFile,
  }) async {
    await _api.put('users/profile', body: {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
    });
  }

  Future<void> deleteAccount(String userId) async {
    await _api.delete('users/account');
  }

  Future<void> changePassword(String newPassword) async {
    await _api.put('users/profile', body: {
      'password': newPassword,
    });
  }
}
