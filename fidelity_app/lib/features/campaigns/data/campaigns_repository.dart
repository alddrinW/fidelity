import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

enum CampaignType {
  event('event', 'Evento', 'Avisa de una novedad a tus clientes', Icons.celebration_outlined),
  giftCard('gift_card', 'Tarjeta de regalo', 'Un descuento o mini premio para reclamar',
      Icons.card_giftcard_rounded),
  route('route', 'Ruta', 'Pasaporte: visitar varios locales y juntar sellos', Icons.route_rounded);

  final String apiValue;
  final String label;
  final String description;
  final IconData icon;

  const CampaignType(this.apiValue, this.label, this.description, this.icon);

  static CampaignType parse(Object? value) {
    for (final t in values) {
      if (t.apiValue == value) return t;
    }
    return event;
  }
}

enum CampaignPhase {
  scheduled('Programada'),
  active('Activa'),
  ended('Finalizada'),
  cancelled('Cancelada');

  final String label;

  const CampaignPhase(this.label);

  static CampaignPhase parse(Object? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return active;
  }
}

enum CampaignBenefit {
  discountPercent('discount_percent', 'Descuento'),
  miniPrize('mini_prize', 'Mini premio');

  final String apiValue;
  final String label;

  const CampaignBenefit(this.apiValue, this.label);

  static CampaignBenefit? parse(Object? value) {
    for (final b in values) {
      if (b.apiValue == value) return b;
    }
    return null;
  }
}

/// Negocio participante de una campaña.
class CampaignBusinessRef {
  final String id;
  final String name;
  final String? logoUrl;

  const CampaignBusinessRef({required this.id, required this.name, this.logoUrl});

  factory CampaignBusinessRef.fromJson(Map<String, dynamic> json) => CampaignBusinessRef(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Local',
        logoUrl: json['logoUrl']?.toString(),
      );
}

/// Tarjeta de regalo o premio de ruta de un cliente (con su código de canje).
class CampaignClaim {
  final String id;
  final String code;
  final bool isRedeemed;
  final bool isRoutePrize;
  final DateTime? createdAt;
  final DateTime? redeemedAt;

  /// Solo en "mis tarjetas": la campaña a la que pertenece.
  final Campaign? campaign;

  const CampaignClaim({
    required this.id,
    required this.code,
    required this.isRedeemed,
    required this.isRoutePrize,
    this.createdAt,
    this.redeemedAt,
    this.campaign,
  });

  factory CampaignClaim.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'];
    return CampaignClaim(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      isRedeemed: json['status'] == 'redeemed',
      isRoutePrize: json['source'] == 'route_complete',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
      redeemedAt: DateTime.tryParse('${json['redeemedAt'] ?? ''}')?.toLocal(),
      campaign: campaign is Map ? Campaign.fromJson(Map<String, dynamic>.from(campaign)) : null,
    );
  }
}

class CampaignStats {
  final int claims;
  final int redeemed;
  final int participants;

  const CampaignStats({this.claims = 0, this.redeemed = 0, this.participants = 0});
}

class Campaign {
  final String id;
  final CampaignType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final CampaignBenefit? benefitType;
  final int? benefitValue;
  final String? benefitLabel;
  final int? requiredStamps;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final CampaignPhase phase;
  final List<CampaignBusinessRef> businesses;

  /// Tarjeta ya reclamada por el cliente (vista de cliente).
  final CampaignClaim? claim;

  /// Locales donde el cliente ya tiene su sello (rutas, vista de cliente).
  final List<String> stampedBusinessIds;
  final bool completed;

  /// Cifras de la campaña (vista del dueño).
  final CampaignStats? stats;

  const Campaign({
    required this.id,
    required this.type,
    required this.title,
    required this.phase,
    required this.businesses,
    this.description,
    this.imageUrl,
    this.benefitType,
    this.benefitValue,
    this.benefitLabel,
    this.requiredStamps,
    this.startsAt,
    this.endsAt,
    this.claim,
    this.stampedBusinessIds = const [],
    this.completed = false,
    this.stats,
  });

  /// Sellos necesarios para completar la ruta.
  int get stampsNeeded => requiredStamps ?? businesses.length;

  bool get isActive => phase == CampaignPhase.active;

  factory Campaign.fromJson(Map<String, dynamic> json) {
    final claim = json['claim'];
    final stats = json['stats'];
    int number(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;

    return Campaign(
      id: json['id'].toString(),
      type: CampaignType.parse(json['type']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      benefitType: CampaignBenefit.parse(json['benefitType']),
      benefitValue: (json['benefitValue'] as num?)?.toInt(),
      benefitLabel: json['benefitLabel']?.toString(),
      requiredStamps: (json['requiredStamps'] as num?)?.toInt(),
      startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
      endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}')?.toLocal(),
      phase: CampaignPhase.parse(json['phase']),
      businesses: ((json['businesses'] as List?) ?? const [])
          .map((b) => CampaignBusinessRef.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList(),
      claim: claim is Map ? CampaignClaim.fromJson(Map<String, dynamic>.from(claim)) : null,
      stampedBusinessIds:
          ((json['stampedBusinessIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      completed: json['completed'] == true,
      stats: stats is Map
          ? CampaignStats(
              claims: number(stats, 'claims'),
              redeemed: number(stats, 'redeemed'),
              participants: number(stats, 'participants'),
            )
          : null,
    );
  }
}

/// Tarjeta o premio emitido por una campaña (lista del dueño).
class IssuedClaim {
  final String code;
  final bool isRedeemed;
  final bool isRoutePrize;
  final String? userName;
  final String? userEmail;
  final DateTime? createdAt;
  final DateTime? redeemedAt;

  const IssuedClaim({
    required this.code,
    required this.isRedeemed,
    required this.isRoutePrize,
    this.userName,
    this.userEmail,
    this.createdAt,
    this.redeemedAt,
  });

  factory IssuedClaim.fromJson(Map<String, dynamic> json) => IssuedClaim(
        code: json['code']?.toString() ?? '',
        isRedeemed: json['status'] == 'redeemed',
        isRoutePrize: json['source'] == 'route_complete',
        userName: json['userName']?.toString(),
        userEmail: json['userEmail']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
        redeemedAt: DateTime.tryParse('${json['redeemedAt'] ?? ''}')?.toLocal(),
      );
}

/// Resultado de canjear un código.
class RedeemResult {
  final String code;
  final String campaignTitle;
  final String? benefitLabel;
  final String? userName;

  const RedeemResult({
    required this.code,
    required this.campaignTitle,
    this.benefitLabel,
    this.userName,
  });

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
        code: json['code']?.toString() ?? '',
        campaignTitle: json['campaignTitle']?.toString() ?? '',
        benefitLabel: json['benefitLabel']?.toString(),
        userName: json['userName']?.toString(),
      );
}

final campaignsRepositoryProvider = Provider<CampaignsRepository>((ref) => CampaignsRepository());

/// Novedades del cliente: campañas vigentes de sus locales.
final campaignFeedProvider = FutureProvider.autoDispose<List<Campaign>>(
  (ref) => ref.watch(campaignsRepositoryProvider).feed(),
);

/// Tarjetas de regalo y premios de ruta del cliente.
final myClaimsProvider = FutureProvider.autoDispose<List<CampaignClaim>>(
  (ref) => ref.watch(campaignsRepositoryProvider).myClaims(),
);

/// Campañas del dueño.
final myCampaignsProvider = FutureProvider.autoDispose<List<Campaign>>(
  (ref) => ref.watch(campaignsRepositoryProvider).mine(),
);

class CampaignsRepository {
  final ApiClient _api = ApiClient();

  List<Campaign> _campaigns(dynamic response) {
    if (response is! List) return [];
    return response.map((c) => Campaign.fromJson(Map<String, dynamic>.from(c as Map))).toList();
  }

  Future<List<Campaign>> feed() async => _campaigns(await _api.get('campaigns/feed'));

  Future<List<Campaign>> mine() async => _campaigns(await _api.get('campaigns/mine'));

  Future<List<CampaignClaim>> myClaims() async {
    final response = await _api.get('campaigns/claims/mine');
    if (response is! List) return [];
    return response
        .map((c) => CampaignClaim.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
  }

  /// El cliente reclama la tarjeta de regalo.
  Future<CampaignClaim> claim(String campaignId) async {
    final response = await _api.post('campaigns/$campaignId/claim');
    return CampaignClaim.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Campaign> create({
    required CampaignType type,
    required String title,
    required List<String> businessIds,
    String? description,
    String? imageDataUri,
    CampaignBenefit? benefitType,
    int? benefitValue,
    String? benefitLabel,
    int? requiredStamps,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final response = await _api.post('campaigns', body: {
      'type': type.apiValue,
      'title': title.trim(),
      'businessIds': businessIds,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (imageDataUri != null && imageDataUri.isNotEmpty) 'imageUrl': imageDataUri,
      if (benefitType != null) 'benefitType': benefitType.apiValue,
      if (benefitValue != null) 'benefitValue': benefitValue,
      if (benefitLabel != null && benefitLabel.trim().isNotEmpty) 'benefitLabel': benefitLabel.trim(),
      if (requiredStamps != null) 'requiredStamps': requiredStamps,
      if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
    });
    return Campaign.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> cancel(String campaignId) async {
    await _api.patch('campaigns/$campaignId/cancel');
  }

  Future<List<IssuedClaim>> claims(String campaignId) async {
    final response = await _api.get('campaigns/$campaignId/claims');
    if (response is! List) return [];
    return response
        .map((c) => IssuedClaim.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
  }

  Future<RedeemResult> redeem(String code) async {
    final response = await _api.post('campaigns/redeem', body: {'code': code.trim()});
    return RedeemResult.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
