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
      
      // Si el rol es negocio, buscamos su negocio asociado para guardar business_id
      if (userData['role'] == 'business') {
        try {
          await _api.setSession(token, userData);
          final businesses = await _api.get('businesses/my-businesses');
          if (businesses is List && businesses.isNotEmpty) {
            userData['business_id'] = businesses.first['id'];
          }
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
        
        if (current['role'] == 'business') {
          final businesses = await _api.get('businesses/my-businesses');
          if (businesses is List && businesses.isNotEmpty) {
            current['business_id'] = businesses.first['id'];
          }
        }
        
        await _api.updateUser(current);
        _authStateController.add(AuthUser.fromJson(current));
      }
    } catch (e) {
      debugPrint('Error refrescando perfil: $e');
    }
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
