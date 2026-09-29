import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

class AdminRepository {
  final ApiClient _api = ApiClient();

  AdminRepository();

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.get('admin/stats');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
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
