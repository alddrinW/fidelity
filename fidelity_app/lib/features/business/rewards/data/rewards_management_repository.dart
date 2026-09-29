import '../../../../core/services/api_client.dart';

class RewardsManagementRepository {
  final ApiClient _api = ApiClient();

  RewardsManagementRepository();

  Future<List<Map<String, dynamic>>> getRewards(String businessId) async {
    final response = await _api.get('rewards/business/$businessId');
    if (response is! List) return [];

    final rewards = response.map((item) {
      final raw = Map<String, dynamic>.from(item as Map);
      final user = raw['user'] as Map<String, dynamic>? ?? {};

      final isTransferred = raw['isTransferred'] == true || raw['is_transferred'] == true;
      final fromName = raw['fromName'] ?? raw['from_name'] ?? '';

      return {
        'id': raw['id'],
        'user_id': raw['userId'] ?? raw['user_id'],
        'business_id': raw['businessId'] ?? raw['business_id'],
        'loyalty_card_id': raw['loyaltyCardId'] ?? raw['loyalty_card_id'],
        'description': raw['description'] ?? raw['rewardDescription'] ?? raw['reward_description'] ?? 'Premio',
        'status': raw['status'],
        'points_used': raw['pointsUsed'] ?? raw['points_used'] ?? 10,
        'earned_at': raw['earnedAt'] ?? raw['earned_at'] ?? raw['createdAt'] ?? raw['created_at'],
        'claimed_at': raw['claimedAt'] ?? raw['claimed_at'],
        'is_transferred': isTransferred,
        'from_name': fromName,
        'display_name': user['fullName'] ?? user['full_name'] ?? 'USUARIO',
        'avatar_url': user['avatarUrl'] ?? user['avatar_url'],
      };
    }).toList();

    return rewards;
  }

  Future<void> updateRewardStatus(String rewardId, String status) async {
    await _api.patch('rewards/$rewardId/status', body: {
      'status': status,
    });
  }

  Future<void> transferReward(String rewardId, String toIdentifier) async {
    await _api.post('rewards/transfer', body: {
      'rewardId': rewardId,
      'toIdentifier': toIdentifier.trim(),
    });
  }
}
