import '../../../core/services/api_client.dart';

class MyCardsRepository {
  final ApiClient _api = ApiClient();

  MyCardsRepository();

  String get currentUserId => _api.currentUser?['id']?.toString() ?? '';

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _api.get('users/profile');
      if (response is Map<String, dynamic>) {
        return {
          'full_name': response['fullName'] ?? response['full_name'] ?? '',
          'avatar_url': response['avatarUrl'] ?? response['avatar_url'],
          'email': response['email'],
          'phone': response['phone'],
        };
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getLoyaltyCards() async {
    final response = await _api.get('loyalty-cards/my-cards');
    if (response is! List) return [];

    final cards = response.map((item) {
      final raw = Map<String, dynamic>.from(item as Map);
      final business = raw['business'] as Map<String, dynamic>? ?? {};
      final category = business['categoryRef'] as Map<String, dynamic>? ?? {};

      return {
        'id': raw['id'],
        'user_id': raw['userId'] ?? raw['user_id'],
        'business_id': raw['businessId'] ?? raw['business_id'],
        'current_points': raw['currentPoints'] ?? raw['current_points'] ?? 0,
        'total_points_lifetime': raw['totalPointsLifetime'] ?? raw['total_points_lifetime'] ?? 0,
        'rewards_claimed': raw['rewardsClaimed'] ?? raw['rewards_claimed'] ?? 0,
        'last_scan_at': raw['lastScanAt'] ?? raw['last_scan_at'],
        'created_at': raw['createdAt'] ?? raw['created_at'],
        'updated_at': raw['updatedAt'] ?? raw['updated_at'],
        'businesses': {
          'id': business['id'],
          'name': business['name'],
          'category_id': business['categoryId'] ?? business['category_id'],
          'business_categories': {
            'name': category['name'] ?? '',
          },
          'reward_description': business['rewardDescription'] ?? business['reward_description'] ?? '',
          'reward_long_description': business['rewardLongDescription'] ?? business['reward_long_description'] ?? '',
          'points_required': business['pointsRequired'] ?? business['points_required'] ?? 10,
          'logo_url': business['logoUrl'] ?? business['logo_url'],
        },
        'pending_scans': (raw['pendingScans'] as num?)?.toInt() ?? 0,
        'rewards': raw['rewards'] ?? [],
      };
    }).toList();

    return cards;
  }
}
