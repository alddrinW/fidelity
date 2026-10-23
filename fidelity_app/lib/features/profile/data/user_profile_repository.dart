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
        'birth_date': response['birthDate'] ?? response['birth_date'],
        'avatar_url': response['avatarUrl'] ?? response['avatar_url'],
        'role': response['role'] ?? 'client',
      };
    }
    return null;
  }

  /// Actualiza nombre, teléfono y, si se indica, la foto de perfil.
  /// [avatarDataUri] es la imagen como data URI base64 (ver `image_source.dart`).
  /// [birthDate] es `AAAA-MM-DD`; el texto vacío borra la fecha guardada y
  /// null la deja como está.
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    String? avatarDataUri,
    String? birthDate,
  }) async {
    await _api.put('users/profile', body: {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      if (birthDate != null) 'birthDate': birthDate,
      if (avatarDataUri != null) 'avatarUrl': avatarDataUri,
    });
  }

  Future<void> deleteAccount(String userId) async {
    await _api.delete('users/account');
  }

  /// Cambia la contraseña. El backend exige la actual para confirmar que
  /// quien lo pide es el dueño de la cuenta.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.put('users/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
