import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Persona del equipo de un negocio (rol Aprobador).
class TeamMember {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? phone;

  const TeamMember({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'].toString(),
        userId: json['userId']?.toString() ?? '',
        fullName: (json['fullName'] ?? json['full_name'] ?? '').toString(),
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString(),
      );

  /// Nombre para mostrar: el nombre completo o, si falta, el correo.
  String get displayName => fullName.trim().isEmpty ? email : fullName;
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) => TeamRepository());

class TeamRepository {
  final ApiClient _api = ApiClient();

  Future<List<TeamMember>> list(String businessId) async {
    final response = await _api.get('businesses/$businessId/members');
    if (response is! List) return [];
    return response
        .map((m) => TeamMember.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Asigna el rol Aprobador a una persona ya registrada, por su correo.
  Future<TeamMember> add(String businessId, String email) async {
    final response = await _api.post(
      'businesses/$businessId/members',
      body: {'email': email.trim()},
    );
    return TeamMember.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> remove(String businessId, String userId) async {
    await _api.delete('businesses/$businessId/members/$userId');
  }
}
