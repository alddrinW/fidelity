import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// De parte de quién llegó el cliente a Fidelity (si llegó invitado).
class ReferredBy {
  final String? name;

  /// `pending` hasta su primer escaneo aprobado; después `rewarded`.
  final String status;
  final int points;

  const ReferredBy({this.name, required this.status, required this.points});

  bool get isPending => status != 'rewarded';

  factory ReferredBy.fromJson(Map<String, dynamic> json) => ReferredBy(
        name: json['name']?.toString(),
        status: json['status']?.toString() ?? 'pending',
        points: (json['points'] as num?)?.toInt() ?? 0,
      );
}

/// Lo que ve el cliente de "Invitar amigos": se invita a la app, no a un local.
class ReferralInfo {
  /// Invitar amigos está encendido (lo decide el administrador).
  final bool enabled;

  /// Su código (`AMG-XXXXXX`) y su enlace de invitación (null si el servidor no tiene dirección pública).
  final String? code;
  final String? link;

  /// Lo que gana quien invita y lo que gana el amigo, en puntos de invitación.
  final int referrerPoints;
  final int friendPoints;
  final int maxFriends;

  /// Cuántos amigos usaron su código y cuántos ya hicieron su primer escaneo.
  final int invited;
  final int rewarded;

  /// Cuántos amigos se necesitan para ganar los puntos (3 por defecto), cuántos ya
  /// cuentan para su meta y cuántos grupos completos ya le pagaron.
  final int friendsRequired;
  final int counted;
  final int groupsPaid;

  /// Cuándo cuenta un amigo: `registration` (al registrarse con el código) o
  /// `first_scan` (cuando hace su primer escaneo aprobado).
  final String trigger;

  /// Puntos de invitación ganados que todavía no usa: los gasta en el local que elija.
  final int balance;

  /// Cuántos locales participan (los marca el administrador).
  final int eligibleLocals;
  final ReferredBy? referredBy;

  const ReferralInfo({
    this.enabled = false,
    this.code,
    this.link,
    this.referrerPoints = 1,
    this.friendPoints = 0,
    this.maxFriends = 20,
    this.invited = 0,
    this.rewarded = 0,
    this.friendsRequired = 3,
    this.counted = 0,
    this.groupsPaid = 0,
    this.trigger = 'registration',
    this.balance = 0,
    this.eligibleLocals = 0,
    this.referredBy,
  });

  /// Hay algo que mostrar: está encendido o todavía le quedan puntos por usar.
  bool get visible => enabled || balance > 0;

  /// Amigos que ya cuentan en el grupo que está juntando (de 0 a [friendsRequired] - 1).
  int get inGroup => friendsRequired <= 0 ? 0 : counted % friendsRequired;

  /// Cuántos le faltan para completar el grupo y ganar sus puntos.
  int get missing => friendsRequired - inGroup;

  /// Los amigos solo cuentan cuando hacen su primer escaneo.
  bool get countsOnFirstScan => trigger == 'first_scan';

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    int number(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    final by = json['referredBy'];
    return ReferralInfo(
      enabled: json['enabled'] == true,
      code: json['code']?.toString(),
      link: json['link']?.toString(),
      referrerPoints: number('referrerPoints', 1),
      friendPoints: number('friendPoints', 0),
      maxFriends: number('maxFriends', 20),
      invited: number('invited', 0),
      rewarded: number('rewarded', 0),
      friendsRequired: number('friendsRequired', 3),
      counted: number('counted', 0),
      groupsPaid: number('groupsPaid', 0),
      trigger: json['trigger']?.toString() ?? 'registration',
      balance: number('balance', 0),
      eligibleLocals: number('eligibleLocals', 0),
      referredBy: by is Map ? ReferredBy.fromJson(Map<String, dynamic>.from(by)) : null,
    );
  }
}

/// Un local donde se pueden usar los puntos de invitación.
class ReferralLocal {
  final String id;
  final String name;
  final String? logoUrl;
  final String? category;
  final String? address;
  final String? rewardDescription;
  final int pointsRequired;

  /// Los puntos que ya lleva el cliente ahí (null si todavía no tiene tarjeta).
  final int? currentPoints;

  const ReferralLocal({
    required this.id,
    required this.name,
    this.logoUrl,
    this.category,
    this.address,
    this.rewardDescription,
    this.pointsRequired = 10,
    this.currentPoints,
  });

  factory ReferralLocal.fromJson(Map<String, dynamic> json) => ReferralLocal(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
        category: json['category']?.toString(),
        address: json['address']?.toString(),
        rewardDescription: json['rewardDescription']?.toString(),
        pointsRequired: (json['pointsRequired'] as num?)?.toInt() ?? 10,
        currentPoints: (json['currentPoints'] as num?)?.toInt(),
      );
}

/// El resultado de usar puntos de invitación en un local.
class ReferralUsed {
  final String businessName;
  final int used;
  final int balance;
  final int currentPoints;
  final int newRewards;

  const ReferralUsed({
    required this.businessName,
    required this.used,
    required this.balance,
    required this.currentPoints,
    this.newRewards = 0,
  });
}

/// El resultado de usar el código de un amigo.
class ReferralRedeemed {
  final int friendPoints;
  final String? referrerName;

  const ReferralRedeemed({required this.friendPoints, this.referrerName});
}

/// Un local activo con su marca de participación (lo ve el administrador).
class ReferralAdminBusiness {
  final String id;
  final String name;
  final String? logoUrl;
  final String? category;
  final String? address;
  final bool enabled;

  const ReferralAdminBusiness({
    required this.id,
    required this.name,
    required this.enabled,
    this.logoUrl,
    this.category,
    this.address,
  });

  ReferralAdminBusiness withEnabled(bool value) => ReferralAdminBusiness(
        id: id,
        name: name,
        logoUrl: logoUrl,
        category: category,
        address: address,
        enabled: value,
      );

  factory ReferralAdminBusiness.fromJson(Map<String, dynamic> json) => ReferralAdminBusiness(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
        category: json['category']?.toString(),
        address: json['address']?.toString(),
        enabled: json['enabled'] == true,
      );
}

final referralsRepositoryProvider = Provider<ReferralsRepository>((ref) => ReferralsRepository());

/// "Invitar amigos" del cliente: su código, su enlace y sus puntos de invitación.
final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo>(
  (ref) => ref.watch(referralsRepositoryProvider).me(),
);

/// Los locales donde puede usar sus puntos de invitación.
final referralLocalsProvider = FutureProvider.autoDispose<List<ReferralLocal>>(
  (ref) => ref.watch(referralsRepositoryProvider).locals(),
);

/// Los locales activos con su marca (para el administrador).
final referralAdminBusinessesProvider = FutureProvider.autoDispose<List<ReferralAdminBusiness>>(
  (ref) => ref.watch(referralsRepositoryProvider).adminBusinesses(),
);

class ReferralsRepository {
  final ApiClient _api = ApiClient();

  Future<ReferralInfo> me() async {
    final response = await _api.get('referrals/me');
    return ReferralInfo.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<ReferralLocal>> locals() async {
    final response = await _api.get('referrals/locals');
    if (response is! List) return [];
    return [for (final l in response) ReferralLocal.fromJson(Map<String, dynamic>.from(l as Map))];
  }

  /// Usa [points] de sus puntos de invitación en el local que elige.
  Future<ReferralUsed> use(String businessId, {int points = 1}) async {
    final response = await _api.post('referrals/use', body: {'businessId': businessId, 'points': points});
    final json = Map<String, dynamic>.from(response as Map);
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ReferralUsed(
      businessName: json['businessName']?.toString() ?? '',
      used: number('used'),
      balance: number('balance'),
      currentPoints: number('currentPoints'),
      newRewards: number('newRewards'),
    );
  }

  /// Usa el código de un amigo (para quien ya tiene cuenta).
  Future<ReferralRedeemed> redeem(String code) async {
    final response = await _api.post('referrals/redeem', body: {'code': code.trim()});
    final json = Map<String, dynamic>.from(response as Map);
    return ReferralRedeemed(
      friendPoints: (json['friendPoints'] as num?)?.toInt() ?? 0,
      referrerName: json['referrerName']?.toString(),
    );
  }

  // --- Administrador ---

  Future<List<ReferralAdminBusiness>> adminBusinesses({String? query}) async {
    final response = await _api.get(
      'referrals/admin/businesses',
      queryParams: {if (query != null && query.trim().isNotEmpty) 'q': query.trim()},
    );
    if (response is! List) return [];
    return [for (final b in response) ReferralAdminBusiness.fromJson(Map<String, dynamic>.from(b as Map))];
  }

  Future<void> setBusiness(String id, bool enabled) async {
    await _api.patch('referrals/admin/businesses/$id', body: {'enabled': enabled});
  }

  Future<void> setMany(List<String> ids, bool enabled) async {
    await _api.put('referrals/admin/businesses', body: {'ids': ids, 'enabled': enabled});
  }
}
