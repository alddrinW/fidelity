import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/push_notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? businessId;
  final bool isDemo;
  final Map<String, dynamic> raw;

  AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.businessId,
    this.isDemo = false,
    required this.raw,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      phone: json['phone']?.toString(),
      businessId: json['businessId']?.toString() ?? json['business_id']?.toString(),
      isDemo: json['isDemo'] == true || json['is_demo'] == true,
      raw: json,
    );
  }

  Map<String, dynamic>? get userMetadata => {
    'role': role,
    'full_name': fullName,
    'business_id': businessId,
    'avatar_url': avatarUrl,
    'phone': phone,
  };
}

class AuthRepository {
  final ApiClient _api = ApiClient();
  final _authStateController = StreamController<AuthUser?>.broadcast();

  AuthRepository();

  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  AuthUser? get currentUser {
    final userMap = _api.currentUser;
    if (userMap == null) return null;
    return AuthUser.fromJson(userMap);
  }

  bool get isAuthenticated => _api.isAuthenticated;
  dynamic get currentSession => isAuthenticated ? _api.token : null;

  Future<AuthUser> signIn({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    final response = await _api.post('auth/login', body: {
      'email': email.trim(),
      'password': password.trim(),
      if (fcmToken != null) 'fcmToken': fcmToken,
    });

    if (response is Map<String, dynamic>) {
      final token = response['accessToken']?.toString() ?? '';
      final userData = response['user'] as Map<String, dynamic>? ?? {};
      
      // Dueños y aprobadores trabajan sobre un negocio: guardamos cuál es
      // (business_id) para que el resto de la app sepa con cuál operar.
      if (isBusinessSide(userData['role']?.toString())) {
        try {
          await _api.setSession(token, userData);
          final businessId = await _resolveBusinessId(null);
          if (businessId != null) userData['business_id'] = businessId;
        } catch (_) {}
      }

      await _api.setSession(token, userData);
      final user = AuthUser.fromJson(userData);
      _authStateController.add(user);
      return user;
    }
    throw ApiException('Respuesta inesperada al iniciar sesion');
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'client',
    String? phone,
    String? avatarUrl,
    String? fcmToken,
  }) async {
    final response = await _api.post('auth/register', body: {
      'email': email.trim(),
      'password': password.trim(),
      'fullName': fullName.trim(),
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });

    if (response is Map<String, dynamic>) {
      final token = response['accessToken']?.toString() ?? '';
      final userData = response['user'] as Map<String, dynamic>? ?? {};
      await _api.setSession(token, userData);
      final user = AuthUser.fromJson(userData);
      _authStateController.add(user);
      return user;
    }
    throw ApiException('Respuesta inesperada al registrar usuario');
  }

  Future<void> signOut() async {
    try {
      await PushNotificationService.removeTokenFromDatabase();
    } catch (_) {}
    await _api.clearSession();
    _authStateController.add(null);
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      final response = await _api.get('auth/me');
      if (response is Map<String, dynamic>) {
        final current = Map<String, dynamic>.from(_api.currentUser ?? {});
        current.addAll(response);
        
        if (isBusinessSide(current['role']?.toString())) {
          // Se conserva el negocio elegido si sigue siendo válido.
          final businessId = await _resolveBusinessId(current['business_id']?.toString());
          if (businessId != null) current['business_id'] = businessId;
        }

        await _api.updateUser(current);
        _authStateController.add(AuthUser.fromJson(current));
      }
    } catch (e) {
      debugPrint('Error refrescando perfil: $e');
    }
  }

  /// Dueños y aprobadores: los roles que operan sobre un negocio.
  static bool isBusinessSide(String? role) => role == 'business' || role == 'approver';

  /// Negocios con los que trabaja el usuario (los suyos o aquellos donde es
  /// aprobador), tal como los devuelve el backend.
  Future<List<Map<String, dynamic>>> myBusinesses() async {
    final response = await _api.get('businesses/my-businesses');
    if (response is! List) return [];
    return response.map((b) => Map<String, dynamic>.from(b as Map)).toList();
  }

  /// Elige el negocio actual: el que ya estaba elegido si sigue en la lista;
  /// si no, el primero activo; y si ninguno está activo, el primero.
  static String? pickBusinessId(List<Map<String, dynamic>> businesses, String? currentId) {
    if (businesses.isEmpty) return null;
    if (currentId != null && businesses.any((b) => b['id']?.toString() == currentId)) {
      return currentId;
    }
    final active = businesses.where((b) => b['isActive'] == true || b['is_active'] == true);
    return (active.isNotEmpty ? active.first : businesses.first)['id']?.toString();
  }

  Future<String?> _resolveBusinessId(String? currentId) async {
    return pickBusinessId(await myBusinesses(), currentId);
  }

  /// Cambia el negocio con el que se trabaja y avisa a la sesión para que
  /// recargue todo lo que depende de él.
  Future<void> selectBusiness(String businessId) async {
    final current = Map<String, dynamic>.from(_api.currentUser ?? {});
    current['business_id'] = businessId;
    await _api.updateUser(current);
    _authStateController.add(AuthUser.fromJson(current));
  }

  Future<bool> isBusinessActive(String businessId) async {
    try {
      final response = await _api.get('businesses/$businessId');
      if (response is Map<String, dynamic>) {
        return response['isActive'] == true || response['is_active'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    await _api.post('auth/reset-password', body: {
      'email': email.trim(),
    });
  }
}
