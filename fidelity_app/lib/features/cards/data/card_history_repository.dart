import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

final cardHistoryRepositoryProvider = Provider<CardHistoryRepository>((ref) {
  return CardHistoryRepository();
});

/// Lo que trae el historial de una tarjeta: sus escaneos, sus premios y la
/// ficha de la tarjeta.
class CardHistoryData {
  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> rewards;
  final Map<String, dynamic> card;

  const CardHistoryData({
    this.scans = const [],
    this.rewards = const [],
    this.card = const {},
  });
}

class CardHistoryRepository {
  final ApiClient _api = ApiClient();

  CardHistoryRepository();

  Future<CardHistoryData> fetchHistory(String cardId, String businessId, DateTimeRange? range) async {
    final response = await _api.get('loyalty-cards/$cardId/history');
    if (response is! Map<String, dynamic>) {
      return const CardHistoryData();
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

    return CardHistoryData(
      scans: scans,
      rewards: rewards,
      card: _cardInfo(card, response['fidely'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// La ficha de la tarjeta: con qué local es, su premio y cuánto lleva.
  Map<String, dynamic> _cardInfo(Map<String, dynamic> card, Map<String, dynamic> fidely) {
    final business = card['business'] as Map<String, dynamic>? ?? {};
    return {
      'name': business['name'] ?? '',
      'logo_url': business['logoUrl'] ?? business['logo_url'],
      'category': business['category'],
      'address': business['address'],
      'reward_description':
          business['rewardDescription'] ?? business['reward_description'] ?? '',
      'current_points': card['currentPoints'] ?? card['current_points'] ?? 0,
      'total_points': card['totalPointsLifetime'] ?? card['total_points_lifetime'] ?? 0,
      'rewards_claimed': card['rewardsClaimed'] ?? card['rewards_claimed'] ?? 0,
      'points_required': business['pointsRequired'] ?? business['points_required'] ?? 10,
      'last_scan_at': card['lastScanAt'] ?? card['last_scan_at'],
      'created_at': card['createdAt'] ?? card['created_at'],
      // La insignia FidelyUsuario del cliente en este local.
      'verified_scans': (fidely['verifiedScans'] as num?)?.toInt() ?? 0,
      'fidely_required': (fidely['fidelyRequired'] as num?)?.toInt() ?? 3,
      'is_fidely': fidely['isFidely'] == true,
    };
  }
}
