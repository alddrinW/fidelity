import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Un cliente que cumple años (hoy, pronto o hace poco). Nunca trae el año de
/// nacimiento ni la edad: el dueño solo ve el día y el mes.
class BirthdayItem {
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final String businessId;
  final String? businessName;
  final int month;
  final int day;

  /// Días que faltan (0 = hoy, negativo = ya pasó).
  final int daysUntil;

  /// El dueño ya le regaló su gift card de este cumpleaños.
  final bool gifted;

  const BirthdayItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.businessId,
    required this.month,
    required this.day,
    required this.daysUntil,
    this.avatarUrl,
    this.businessName,
    this.gifted = false,
  });

  bool get isToday => daysUntil == 0;

  factory BirthdayItem.fromJson(Map<String, dynamic> json) => BirthdayItem(
        userId: json['userId'].toString(),
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        avatarUrl: json['avatarUrl']?.toString(),
        businessId: json['businessId'].toString(),
        businessName: json['businessName']?.toString(),
        month: (json['month'] as num).toInt(),
        day: (json['day'] as num).toInt(),
        daysUntil: (json['daysUntil'] as num).toInt(),
        gifted: json['gifted'] == true,
      );
}

class BirthdayList {
  final List<BirthdayItem> items;

  /// Con cuántos días de anticipación se ven los cumpleaños (lo fija el administrador).
  final int upcomingDays;

  const BirthdayList({this.items = const [], this.upcomingDays = 7});

  factory BirthdayList.fromJson(Map<String, dynamic> json) => BirthdayList(
        items: [
          for (final i in (json['items'] as List? ?? const []))
            BirthdayItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        upcomingDays: (json['upcomingDays'] as num?)?.toInt() ?? 7,
      );
}

final birthdaysRepositoryProvider = Provider<BirthdaysRepository>((ref) => BirthdaysRepository());

/// Los cumpleaños de los clientes de los negocios del dueño.
final birthdaysProvider = FutureProvider.autoDispose<BirthdayList>(
  (ref) => ref.watch(birthdaysRepositoryProvider).upcoming(),
);

class BirthdaysRepository {
  final ApiClient _api = ApiClient();

  Future<BirthdayList> upcoming({String? businessId}) async {
    final response = await _api.get(
      'birthdays/upcoming',
      queryParams: {if (businessId != null) 'businessId': businessId},
    );
    return BirthdayList.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Regala una gift card de cumpleaños (plantilla): un descuento (%) o un mini
  /// premio. Vale solo el día del cumpleaños, entre [startTime] y [endTime]
  /// (`HH:mm`, hora de Ecuador); sin ellas, desde la hora del aviso hasta el
  /// final del día.
  Future<void> gift({
    required String businessId,
    required String userId,
    int? discountPercent,
    String? prizeLabel,
    String? startTime,
    String? endTime,
  }) async {
    final discount = discountPercent != null;
    await _api.post('birthdays/gift', body: {
      'businessId': businessId,
      'userId': userId,
      'benefitType': discount ? 'discount_percent' : 'mini_prize',
      if (discount) 'benefitValue': discountPercent else 'benefitLabel': prizeLabel?.trim(),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
    });
  }
}
