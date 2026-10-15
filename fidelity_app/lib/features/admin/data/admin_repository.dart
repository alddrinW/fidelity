import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

/// Métricas del panel. El backend responde con objetos anidados
/// (`businesses: {total, inactive}`...); [fromJson] las aplana.
class AdminDashboardStats {
  final int clients;
  final int businesses;
  final int inactiveBusinesses;
  final int scans;
  final int pendingScans;
  final int rewards;
  final int pendingRewards;
  final int claimedRewards;

  /// Pagos de registro que esperan validación del administrador.
  final int openPayments;

  /// Sugerencias y reclamos sin resolver.
  final int openFeedback;

  const AdminDashboardStats({
    this.clients = 0,
    this.businesses = 0,
    this.inactiveBusinesses = 0,
    this.scans = 0,
    this.pendingScans = 0,
    this.rewards = 0,
    this.pendingRewards = 0,
    this.claimedRewards = 0,
    this.openPayments = 0,
    this.openFeedback = 0,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    int read(String group, String key) {
      final section = json[group];
      if (section is! Map) return 0;
      return (section[key] as num?)?.toInt() ?? 0;
    }

    return AdminDashboardStats(
      clients: read('users', 'clients'),
      businesses: read('businesses', 'total'),
      inactiveBusinesses: read('businesses', 'inactive'),
      scans: read('scans', 'total'),
      pendingScans: read('scans', 'pending'),
      rewards: read('rewards', 'total'),
      pendingRewards: read('rewards', 'pending'),
      claimedRewards: read('rewards', 'claimed'),
      openPayments: read('payments', 'open'),
      openFeedback: read('feedback', 'open'),
    );
  }
}

class AdminRepository {
  final ApiClient _api = ApiClient();

  AdminRepository();

  Future<AdminDashboardStats> getDashboardStats() async {
    final response = await _api.get('admin/stats');
    if (response is Map<String, dynamic>) {
      return AdminDashboardStats.fromJson(response);
    }
    return const AdminDashboardStats();
  }

  Future<List<Map<String, dynamic>>> getUsers({String? role, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _api.get('admin/users', queryParams: queryParams);
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _api.patch('admin/users/$userId/role', body: {'role': role});
  }

  Future<List<Map<String, dynamic>>> getBusinesses({bool all = true}) async {
    final response = await _api.get('businesses', queryParams: {'all': all ? 'true' : 'false'});
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<void> toggleBusinessStatus(String businessId, bool isActive) async {
    await _api.patch('businesses/$businessId/status', body: {'isActive': isActive});
  }

  Future<List<Map<String, dynamic>>> getActivity({int limit = 50}) async {
    final response = await _api.get('admin/activity', queryParams: {'limit': limit.toString()});
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTransfers({String? businessId}) async {
    final queryParams = <String, dynamic>{};
    if (businessId != null && businessId.isNotEmpty) {
      queryParams['businessId'] = businessId;
    }
    final response = await _api.get('rewards/transfers', queryParams: queryParams);
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<Map<String, dynamic>> getQrStats(String qrId) async {
    final response = await _api.get('qr-codes/$qrId/stats');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }
}
