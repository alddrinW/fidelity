import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';
import '../../../auth/data/auth_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardRepository {
  final ApiClient _api = ApiClient();

  DashboardRepository();

  Future<Map<String, dynamic>?> fetchBusiness(String userId) async {
    final response = await _api.get('businesses/my-businesses');
    if (response is List && response.isNotEmpty) {
      // El negocio elegido por el usuario (business_id); si no, el primero.
      final currentId = _api.currentUser?['business_id']?.toString();
      final list = response.map((b) => Map<String, dynamic>.from(b as Map)).toList();
      final pickedId = AuthRepository.pickBusinessId(list, currentId);
      final raw = list.firstWhere((b) => b['id']?.toString() == pickedId, orElse: () => list.first);
      return {
        'parent_id': raw['parentId'] ?? raw['parent_id'],
        'id': raw['id'],
        'owner_id': raw['ownerId'] ?? raw['owner_id'],
        'name': raw['name'],
        'description': raw['description'],
        'logo_url': raw['logoUrl'] ?? raw['logo_url'],
        'address': raw['address'],
        'phone': raw['phone'],
        'tax_id': raw['taxId'] ?? raw['tax_id'],
        'latitude': raw['latitude'],
        'longitude': raw['longitude'],
        'category_id': raw['categoryId'] ?? raw['category_id'],
        'reward_description': raw['rewardDescription'] ?? raw['reward_description'] ?? '',
        'reward_long_description': raw['rewardLongDescription'] ?? raw['reward_long_description'] ?? '',
        'points_required': raw['pointsRequired'] ?? raw['points_required'] ?? 10,
        'cooldown_hours': raw['cooldownHours'] ?? raw['cooldown_hours'] ?? 4,
        'is_active': raw['isActive'] ?? raw['is_active'] ?? true,
        'created_at': raw['createdAt'] ?? raw['created_at'],
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCustomers(String businessId) async {
    final response = await _api.get('loyalty-cards/business/$businessId');
    if (response is! List) return [];

    return response.map((item) {
      final raw = Map<String, dynamic>.from(item as Map);
      final user = raw['user'] as Map<String, dynamic>? ?? {};

      return {
        'id': raw['id'],
        'user_id': raw['userId'] ?? raw['user_id'],
        'business_id': raw['businessId'] ?? raw['business_id'],
        'current_points': raw['currentPoints'] ?? raw['current_points'] ?? 0,
        'total_points_lifetime': raw['totalPointsLifetime'] ?? raw['total_points_lifetime'] ?? 0,
        'rewards_claimed': raw['rewardsClaimed'] ?? raw['rewards_claimed'] ?? 0,
        'rewards_transferred': raw['rewardsTransferred'] ?? 0,
        'last_scan_at': raw['lastScanAt'] ?? raw['last_scan_at'],
        'updated_at': raw['updatedAt'] ?? raw['updated_at'],
        'profiles': {
          'id': user['id'],
          'full_name': user['fullName'] ?? user['full_name'] ?? 'Cliente',
          'avatar_url': user['avatarUrl'] ?? user['avatar_url'],
          'is_demo': user['isDemo'] ?? user['is_demo'] ?? false,
        },
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPendingScans(String businessId) async {
    final response = await _api.get('scans/business/$businessId', queryParams: {'status': 'pending'});
    if (response is! List) return [];

    return response.map((item) {
      final raw = Map<String, dynamic>.from(item as Map);
      final user = raw['user'] as Map<String, dynamic>? ?? {};

      return {
        'id': raw['id'],
        'user_id': raw['userId'] ?? raw['user_id'],
        'business_id': raw['businessId'] ?? raw['business_id'],
        'loyalty_card_id': raw['loyaltyCardId'] ?? raw['loyalty_card_id'],
        'scanned_at': raw['scannedAt'] ?? raw['scanned_at'],
        'status': raw['status'],
        'is_demo': raw['isDemo'] ?? raw['is_demo'] ?? false,
        'profiles': {
          'id': user['id'],
          'full_name': user['fullName'] ?? user['full_name'] ?? 'Cliente',
          'avatar_url': user['avatarUrl'] ?? user['avatar_url'],
          'is_demo': user['isDemo'] ?? user['is_demo'] ?? false,
        },
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPendingRewards(String businessId) async {
    final response = await _api.get('rewards/business/$businessId', queryParams: {'status': 'pending'});
    if (response is! List) return [];
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addManualPoints({
    required String userId,
    required String businessId,
    required int points,
  }) async {
    await _api.post('scans/manual-points', body: {
      'userId': userId,
      'businessId': businessId,
      'points': points,
    });
  }

  Future<bool> approveScan({
    required String scanId,
    required String loyaltyCardId,
  }) async {
    final response = await _api.patch('scans/$scanId/status', body: {
      'status': 'approved',
    });
    return response is Map && response['rewardCompleted'] == true;
  }

  Future<void> rejectScan(String scanId) async {
    await _api.patch('scans/$scanId/status', body: {
      'status': 'rejected',
    });
  }

  Future<void> redeemReward({
    required String userId,
    required String businessId,
    required String cardId,
    String? rewardId,
  }) async {
    if (rewardId != null && rewardId.isNotEmpty) {
      await _api.patch('rewards/$rewardId/status', body: {
        'status': 'claimed',
      });
    }
  }
}
