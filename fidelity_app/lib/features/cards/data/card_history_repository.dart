import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final cardHistoryRepositoryProvider = Provider<CardHistoryRepository>((ref) {
  return CardHistoryRepository();
});

class CardHistoryRepository {
  final ApiClient _api = ApiClient();

  CardHistoryRepository();

  Future<List<List<Map<String, dynamic>>>> fetchHistory(String cardId, String businessId, DateTimeRange? range) async {
    final response = await _api.get('loyalty-cards/$cardId/history');
    if (response is! Map<String, dynamic>) {
      return [[], []];
    }

    final card = response['card'] as Map<String, dynamic>? ?? {};
    final business = card['business'] as Map<String, dynamic>? ?? {};
    final businessName = business['name'] ?? '';
    final rewardDesc = business['rewardDescription'] ?? business['reward_description'] ?? '';

    final rawScans = (response['scans'] as List?) ?? [];
    final scans = rawScans.map((s) {
      final raw = Map<String, dynamic>.from(s as Map);
      return {
        'id': raw['id'],
        'scanned_at': raw['scannedAt'] ?? raw['scanned_at'],
        'status': raw['status'],
        // Sin QR el punto lo otorgó el negocio a mano (regalo).
        'qr_code_id': raw['qrCodeId'] ?? raw['qr_code_id'],
        'points_awarded': raw['pointsAwarded'] ?? raw['points_awarded'] ?? 1,
        'businesses': {
          'name': businessName,
        },
      };
    }).where((s) {
      if (range == null) return true;
      final dt = DateTime.tryParse(s['scanned_at']?.toString() ?? '');
      if (dt == null) return true;
      return dt.isAfter(range.start.toUtc()) && dt.isBefore(range.end.add(const Duration(days: 1)).toUtc());
    }).toList();

    final rawRewards = (response['rewards'] as List?) ?? [];
    final rewards = rawRewards.map((r) {
      final raw = Map<String, dynamic>.from(r as Map);
      return {
        'id': raw['id'],
        'description': raw['description'] ?? rewardDesc,
        'status': raw['status'],
        'earned_at': raw['earnedAt'] ?? raw['earned_at'] ?? raw['createdAt'] ?? raw['created_at'],
        'claimed_at': raw['claimedAt'] ?? raw['claimed_at'],
        'businesses': {
          'name': businessName,
          'reward_description': rewardDesc,
        },
      };
    }).where((r) {
      if (range == null) return true;
      final dt = DateTime.tryParse(r['earned_at']?.toString() ?? '');
      if (dt == null) return true;
      return dt.isAfter(range.start.toUtc()) && dt.isBefore(range.end.add(const Duration(days: 1)).toUtc());
    }).toList();

    return [
      scans,
      rewards,
    ];
  }
}
