import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Un negocio donde el cliente puede jugar su juego de la semana.
class WeeklyBusiness {
  final String id;
  final String name;
  final String? logoUrl;
  final int currentPoints;
  final int pointsRequired;

  /// Ya ganó un punto aquí: no se puede elegir (hasta haber ganado en todos).
  final bool blocked;

  const WeeklyBusiness({
    required this.id,
    required this.name,
    this.logoUrl,
    this.currentPoints = 0,
    this.pointsRequired = 10,
    this.blocked = false,
  });

  factory WeeklyBusiness.fromJson(Map<String, dynamic> json) => WeeklyBusiness(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Negocio',
        logoUrl: json['logoUrl']?.toString(),
        currentPoints: (json['currentPoints'] as num?)?.toInt() ?? 0,
        pointsRequired: (json['pointsRequired'] as num?)?.toInt() ?? 10,
        blocked: json['blocked'] == true,
      );
}

/// El juego que el cliente ya eligió esta semana.
class WeeklyCurrent {
  final String inviteId;
  final String businessId;
  final String? businessName;
  final String gameName;

  /// `sent`, `playing` o `finished`.
  final String status;

  /// `won` o `lost` cuando ya terminó.
  final String? result;

  /// Todavía no empezó a jugar: puede cambiar de negocio.
  final bool canChange;

  const WeeklyCurrent({
    required this.inviteId,
    required this.businessId,
    required this.gameName,
    required this.status,
    this.businessName,
    this.result,
    this.canChange = false,
  });

  bool get isFinished => status == 'finished';
  bool get isWon => result == 'won';

  factory WeeklyCurrent.fromJson(Map<String, dynamic> json) => WeeklyCurrent(
        inviteId: json['inviteId'].toString(),
        businessId: json['businessId'].toString(),
        businessName: json['businessName']?.toString(),
        gameName: json['gameName']?.toString() ?? '',
        status: json['status']?.toString() ?? 'sent',
        result: json['result']?.toString(),
        canChange: json['canChange'] == true,
      );
}

/// Lo que ve el cliente del juego semanal: una vez por semana (lunes a
/// domingo) elige un negocio y juega; si gana, suma puntos ahí.
class WeeklyStatus {
  /// `off`, `available`, `playing`, `done` o `empty`.
  final String state;
  final int points;

  /// Cuándo vuelve a estar disponible (el lunes siguiente).
  final DateTime? nextAt;
  final WeeklyCurrent? current;
  final List<WeeklyBusiness> businesses;

  const WeeklyStatus({
    this.state = 'off',
    this.points = 1,
    this.nextAt,
    this.current,
    this.businesses = const [],
  });

  bool get isOff => state == 'off';
  bool get isAvailable => state == 'available';
  bool get isPlaying => state == 'playing';
  bool get isDone => state == 'done';
  bool get isEmpty => state == 'empty';

  /// Todavía tiene su juego de esta semana por jugar.
  bool get canPlay => isAvailable || isPlaying;

  factory WeeklyStatus.fromJson(Map<String, dynamic> json) => WeeklyStatus(
        state: json['state']?.toString() ?? 'off',
        points: (json['points'] as num?)?.toInt() ?? 1,
        nextAt: DateTime.tryParse('${json['nextAt'] ?? ''}')?.toLocal(),
        current: json['current'] is Map ? WeeklyCurrent.fromJson(Map<String, dynamic>.from(json['current'] as Map)) : null,
        businesses: ((json['businesses'] as List?) ?? const [])
            .map((b) => WeeklyBusiness.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
      );
}

class WeeklyGameRepository {
  final ApiClient _api = ApiClient();

  Future<WeeklyStatus> status() async =>
      WeeklyStatus.fromJson(Map<String, dynamic>.from(await _api.get('weekly-game/status') as Map));

  /// Elige el negocio y arranca el juego de la semana: devuelve el reto para abrirlo.
  Future<String> start(String businessId) async {
    final response = await _api.post('weekly-game/start', body: {'businessId': businessId});
    return (response as Map)['inviteId'].toString();
  }
}

final weeklyGameRepositoryProvider = Provider<WeeklyGameRepository>((ref) => WeeklyGameRepository());

final weeklyGameProvider = FutureProvider.autoDispose<WeeklyStatus>(
  (ref) => ref.watch(weeklyGameRepositoryProvider).status(),
);
