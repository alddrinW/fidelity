import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../../core/utils/money_format.dart';

enum CampaignType {
  event('event', 'Evento', 'Avisa de una novedad a tus clientes', Icons.celebration_outlined),
  giftCard('gift_card', 'Tarjeta de regalo', 'Un descuento o mini premio para reclamar',
      Icons.card_giftcard_rounded),
  route('route', 'Ruta', 'Pasaporte: visitar varios locales y juntar sellos', Icons.route_rounded),
  scanChallenge('scan_challenge', 'Reto de escaneos',
      'El cliente gana un premio al hacer varios escaneos', Icons.qr_code_scanner_rounded);

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

/// A quién le llega una gift card: a todos los clientes o solo a los elegidos.
enum CampaignAudience {
  all('all', 'Todos mis clientes'),
  selected('selected', 'Clientes elegidos');

  final String apiValue;
  final String label;

  const CampaignAudience(this.apiValue, this.label);

  static CampaignAudience parse(Object? value) =>
      value == 'selected' ? selected : all;
}

/// Cliente de un negocio (para elegir a quién le llega una gift card).
class CampaignCustomer {
  final String id;
  final String? fullName;
  final String email;

  const CampaignCustomer({required this.id, required this.email, this.fullName});

  String get displayName => (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : email;

  factory CampaignCustomer.fromJson(Map<String, dynamic> json) => CampaignCustomer(
        id: json['id'].toString(),
        fullName: json['fullName']?.toString(),
        email: json['email']?.toString() ?? '',
      );
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

  /// La compró con tarjeta (vale hasta [expiresAt], no hasta que cierre la campaña).
  final bool isPurchase;
  final DateTime? createdAt;
  final DateTime? redeemedAt;

  /// Tarjetas compradas: hasta cuándo vale.
  final DateTime? expiresAt;

  /// Solo en "mis tarjetas": la campaña a la que pertenece.
  final Campaign? campaign;

  const CampaignClaim({
    required this.id,
    required this.code,
    required this.isRedeemed,
    required this.isRoutePrize,
    this.isPurchase = false,
    this.createdAt,
    this.redeemedAt,
    this.expiresAt,
    this.campaign,
  });

  factory CampaignClaim.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'];
    return CampaignClaim(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      isRedeemed: json['status'] == 'redeemed',
      isRoutePrize: json['source'] == 'route_complete' || json['source'] == 'challenge_complete',
      isPurchase: json['source'] == 'purchase',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
      redeemedAt: DateTime.tryParse('${json['redeemedAt'] ?? ''}')?.toLocal(),
      expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}')?.toLocal(),
      campaign: campaign is Map ? Campaign.fromJson(Map<String, dynamic>.from(campaign)) : null,
    );
  }
}

/// La compra por transferencia que el cliente tiene en curso en una tarjeta en venta:
/// esperando el comprobante, en revisión, o la última que se rechazó.
class TransferPurchase {
  final String id;

  /// `pending` (falta el comprobante), `in_review` o `rejected`.
  final String status;
  final String reference;
  final int amountCents;

  /// Mientras falta el comprobante: hasta cuándo se le guarda la tarjeta.
  final DateTime? reservedUntil;

  /// Si se rechazó: por qué, para que lo corrija.
  final String? reviewNote;

  const TransferPurchase({
    required this.id,
    required this.status,
    required this.reference,
    required this.amountCents,
    this.reservedUntil,
    this.reviewNote,
  });

  bool get isPending => status == 'pending';
  bool get isInReview => status == 'in_review';
  bool get isRejected => status == 'rejected';

  factory TransferPurchase.fromJson(Map<String, dynamic> json) => TransferPurchase(
        id: json['id'].toString(),
        status: json['status']?.toString() ?? 'pending',
        reference: json['reference']?.toString() ?? '',
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        reservedUntil: DateTime.tryParse('${json['reservedUntil'] ?? ''}')?.toLocal(),
        reviewNote: json['reviewNote']?.toString(),
      );
}

class CampaignStats {
  final int claims;
  final int redeemed;
  final int participants;

  /// Clientes elegidos (gift cards con audiencia elegida).
  final int recipients;

  const CampaignStats({
    this.claims = 0,
    this.redeemed = 0,
    this.participants = 0,
    this.recipients = 0,
  });
}

class Campaign {
  final String id;
  final CampaignType type;
  final String title;
  final String? description;
  final String? imageUrl;

  /// Plantilla con la que se creó (`birthday`): lleva su propio diseño y texto.
  final String? template;
  final CampaignBenefit? benefitType;
  final int? benefitValue;
  final String? benefitLabel;
  final int? requiredStamps;

  /// Reto de escaneos: cuántos escaneos debe hacer el cliente.
  final int? requiredScans;

  /// Reto de escaneos: cuántos lleva el cliente (vista de cliente).
  final int scanProgress;
  final CampaignAudience audience;

  /// Tarjeta en venta: lo que cuesta, en centavos (`null` si se regala).
  final int? priceCents;

  /// Tarjeta en venta: cuántas se ponen a la venta y cuántas quedan.
  final int? stock;
  final int? stockLeft;

  /// Tarjeta en venta: cuántos días vale desde que se compra.
  final int? cardValidDays;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final CampaignPhase phase;
  final List<CampaignBusinessRef> businesses;

  /// Tarjeta ya reclamada por el cliente (vista de cliente).
  final CampaignClaim? claim;

  /// Tarjeta en venta: su compra por transferencia en curso (vista de cliente).
  final TransferPurchase? purchase;

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
    this.template,
    this.benefitType,
    this.benefitValue,
    this.benefitLabel,
    this.requiredStamps,
    this.requiredScans,
    this.scanProgress = 0,
    this.audience = CampaignAudience.all,
    this.priceCents,
    this.stock,
    this.stockLeft,
    this.cardValidDays,
    this.startsAt,
    this.endsAt,
    this.claim,
    this.purchase,
    this.stampedBusinessIds = const [],
    this.completed = false,
    this.stats,
  });

  /// Es una gift card de cumpleaños (plantilla): vale solo el día del cumpleaños.
  bool get isBirthday => template == 'birthday';

  /// Sellos necesarios para completar la ruta.
  int get stampsNeeded => requiredStamps ?? businesses.length;

  /// Escaneos necesarios para completar el reto.
  int get scansNeeded => requiredScans ?? 0;

  bool get isActive => phase == CampaignPhase.active;

  /// Es una tarjeta en venta (se compra, no se reclama).
  bool get isForSale => priceCents != null;

  /// "\$0.25"
  String get priceText => priceCents == null ? '' : centsText(priceCents!);

  factory Campaign.fromJson(Map<String, dynamic> json) {
    final claim = json['claim'];
    final purchase = json['purchase'];
    final stats = json['stats'];
    int number(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;

    return Campaign(
      id: json['id'].toString(),
      type: CampaignType.parse(json['type']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      template: json['template']?.toString(),
      benefitType: CampaignBenefit.parse(json['benefitType']),
      benefitValue: (json['benefitValue'] as num?)?.toInt(),
      benefitLabel: json['benefitLabel']?.toString(),
      requiredStamps: (json['requiredStamps'] as num?)?.toInt(),
      requiredScans: (json['requiredScans'] as num?)?.toInt(),
      scanProgress: (json['scanProgress'] as num?)?.toInt() ?? 0,
      audience: CampaignAudience.parse(json['audience']),
      priceCents: (json['priceCents'] as num?)?.toInt(),
      stock: (json['stock'] as num?)?.toInt(),
      stockLeft: (json['stockLeft'] as num?)?.toInt(),
      cardValidDays: (json['cardValidDays'] as num?)?.toInt(),
      startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
      endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}')?.toLocal(),
      phase: CampaignPhase.parse(json['phase']),
      businesses: ((json['businesses'] as List?) ?? const [])
          .map((b) => CampaignBusinessRef.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList(),
      claim: claim is Map ? CampaignClaim.fromJson(Map<String, dynamic>.from(claim)) : null,
      purchase: purchase is Map ? TransferPurchase.fromJson(Map<String, dynamic>.from(purchase)) : null,
      stampedBusinessIds:
          ((json['stampedBusinessIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      completed: json['completed'] == true,
      stats: stats is Map
          ? CampaignStats(
              claims: number(stats, 'claims'),
              redeemed: number(stats, 'redeemed'),
              participants: number(stats, 'participants'),
              recipients: number(stats, 'recipients'),
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
        isRoutePrize: json['source'] == 'route_complete' || json['source'] == 'challenge_complete',
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

/// Normaliza el código de letras que escribe el local: sin espacios y en
/// mayúsculas (el de la gift card siempre es `GFT-XXXXXX`).
String normalizeGiftCode(String raw) => raw.trim().toUpperCase();

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
    int? requiredScans,
    CampaignAudience audience = CampaignAudience.all,
    List<String> recipientIds = const [],
    int? priceCents,
    int? stock,
    int? cardValidDays,
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
      if (requiredScans != null) 'requiredScans': requiredScans,
      if (type == CampaignType.giftCard) 'audience': audience.apiValue,
      if (type == CampaignType.giftCard && audience == CampaignAudience.selected)
        'recipientIds': recipientIds,
      if (priceCents != null) 'priceCents': priceCents,
      if (priceCents != null && stock != null) 'stock': stock,
      if (priceCents != null && cardValidDays != null) 'cardValidDays': cardValidDays,
      if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
    });
    return Campaign.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Edita una campaña (en una gift card: título, descripción, beneficio, fin e
  /// imagen de fondo).
  ///
  /// [imageDataUri] en `null` deja la imagen como está; una cadena vacía la
  /// quita.
  Future<Campaign> update(
    String campaignId, {
    String? title,
    String? description,
    int? benefitValue,
    String? benefitLabel,
    DateTime? endsAt,
    String? imageDataUri,
  }) async {
    final response = await _api.patch('campaigns/$campaignId', body: {
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (benefitValue != null) 'benefitValue': benefitValue,
      if (benefitLabel != null) 'benefitLabel': benefitLabel.trim(),
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
      if (imageDataUri != null) 'imageUrl': imageDataUri,
    });
    return Campaign.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Clientes de los negocios indicados, para elegir a quién le llega una gift card.
  Future<List<CampaignCustomer>> customers(List<String> businessIds, {String? query}) async {
    final response = await _api.get('campaigns/customers', queryParams: {
      'businessIds': businessIds.join(','),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
    if (response is! List) return [];
    return response
        .map((c) => CampaignCustomer.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
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
