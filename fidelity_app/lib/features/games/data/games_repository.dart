import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Los minijuegos que el administrador puede asignar a un negocio.
enum GameKey {
  tictactoe('tictactoe', 'Tres en raya', 'Gana a la computadora: junta tres en línea.', Icons.grid_3x3_rounded),
  hangman('hangman', 'Ahorcado', 'Adivina la palabra antes de que se acaben los intentos.', Icons.abc_rounded),
  flappy('flappy', 'Flappy Bird', 'Vuela entre los tubos y pasa 10 sin chocar.', Icons.flight_rounded);

  final String apiValue;
  final String label;
  final String description;
  final IconData icon;

  const GameKey(this.apiValue, this.label, this.description, this.icon);

  static GameKey? parse(Object? value) {
    for (final g in values) {
      if (g.apiValue == value) return g;
    }
    return null;
  }
}

/// Estado de los minijuegos de un negocio.
enum GameAccessStatus {
  none,
  pending,
  approved,
  rejected;

  static GameAccessStatus parse(Object? value) => switch (value) {
        'pending' => pending,
        'approved' => approved,
        'rejected' => rejected,
        _ => none,
      };
}

/// El premio que fija el administrador.
class GamePrize {
  final String type;
  final int? value;
  final String label;

  const GamePrize({required this.type, required this.label, this.value});

  bool get isDiscount => type == 'discount_percent';

  factory GamePrize.fromJson(Map<String, dynamic> json) => GamePrize(
        type: json['type']?.toString() ?? 'mini_prize',
        value: (json['value'] as num?)?.toInt(),
        label: json['label']?.toString() ?? '',
      );
}

/// Los minijuegos de un negocio: solicitud, juegos asignados y premio.
class GameAccess {
  final String? id;
  final String businessId;
  final GameAccessStatus status;
  final String? note;
  final String? adminNote;
  final List<GameKey> games;
  final GamePrize? prize;
  final DateTime? requestedAt;

  /// Solo en la lista del administrador.
  final String? businessName;
  final String? ownerName;
  final String? ownerEmail;

  const GameAccess({
    required this.businessId,
    required this.status,
    this.id,
    this.note,
    this.adminNote,
    this.games = const [],
    this.prize,
    this.requestedAt,
    this.businessName,
    this.ownerName,
    this.ownerEmail,
  });

  bool get isApproved => status == GameAccessStatus.approved;

  factory GameAccess.fromJson(Map<String, dynamic> json) {
    final business = json['business'];
    final owner = json['owner'];
    final prize = json['prize'];
    return GameAccess(
      id: json['id']?.toString(),
      businessId: json['businessId']?.toString() ?? '',
      status: GameAccessStatus.parse(json['status']),
      note: json['note']?.toString(),
      adminNote: json['adminNote']?.toString(),
      games: ((json['games'] as List?) ?? const [])
          .map(GameKey.parse)
          .whereType<GameKey>()
          .toList(),
      prize: prize is Map ? GamePrize.fromJson(Map<String, dynamic>.from(prize)) : null,
      requestedAt: DateTime.tryParse('${json['requestedAt'] ?? ''}')?.toLocal(),
      businessName: business is Map ? business['name']?.toString() : null,
      ownerName: owner is Map ? owner['fullName']?.toString() : null,
      ownerEmail: owner is Map ? owner['email']?.toString() : null,
    );
  }
}

/// Un reto: un juego que un negocio le mandó al cliente.
class GameInvite {
  final String id;
  final GameKey? game;
  final String gameName;

  /// El negocio que lo mandó.
  final String? businessId;
  final String? businessName;
  final String? prizeLabel;

  /// `upcoming` (aún no empieza), `sent`, `playing`, `finished` o `expired`.
  final String status;

  /// `won` o `lost` cuando ya terminó.
  final String? result;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  /// Intentos que ya usó y cuántos le quedan (de [maxAttempts]).
  final int attempts;
  final int maxAttempts;
  final int attemptsLeft;

  const GameInvite({
    required this.id,
    required this.gameName,
    required this.status,
    this.game,
    this.businessId,
    this.businessName,
    this.prizeLabel,
    this.result,
    this.startsAt,
    this.expiresAt,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.attemptsLeft = 3,
  });

  /// Se puede jugar ahora mismo.
  bool get isOpen => status == 'sent' || status == 'playing';

  /// Es un reto programado: todavía no empieza.
  bool get isUpcoming => status == 'upcoming';

  factory GameInvite.fromJson(Map<String, dynamic> json) => GameInvite(
        id: json['id'].toString(),
        game: GameKey.parse(json['game']),
        gameName: json['gameName']?.toString() ?? '',
        businessId: json['businessId']?.toString(),
        businessName: json['businessName']?.toString(),
        prizeLabel: json['prizeLabel']?.toString(),
        status: json['status']?.toString() ?? 'sent',
        result: json['result']?.toString(),
        startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
        expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}')?.toLocal(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
        attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
      );
}

/// Una partida tal como la ve el cliente. Lo que sabe del juego va en [play]
/// (el tablero, la palabra con guiones...): el servidor decide quién gana.
class GamePlay {
  final String id;
  final GameKey game;
  final String gameName;
  final String? businessName;
  final String? prizeLabel;
  final String status;
  final String? result;
  final int? score;
  final String? claimCode;
  final Map<String, dynamic> play;

  /// El horario del reto.
  final DateTime? startsAt;
  final DateTime? expiresAt;

  /// Intentos que ya empezó, el máximo y los que le quedan.
  final int attempts;
  final int maxAttempts;
  final int attemptsLeft;

  /// `lost` si acaba de perder un intento pero todavía le quedan otros.
  final String? lastAttempt;

  const GamePlay({
    required this.id,
    required this.game,
    required this.gameName,
    required this.status,
    this.businessName,
    this.prizeLabel,
    this.result,
    this.score,
    this.claimCode,
    this.play = const {},
    this.startsAt,
    this.expiresAt,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.attemptsLeft = 3,
    this.lastAttempt,
  });

  bool get isFinished => status == 'finished';
  bool get isWon => result == 'won';
  bool get isExpired => status == 'expired';

  /// Programado: todavía no llega la hora de inicio.
  bool get isUpcoming => status == 'upcoming';

  /// Perdió el intento anterior y puede intentarlo de nuevo.
  bool get lostLastAttempt => lastAttempt == 'lost' && !isFinished;

  factory GamePlay.fromJson(Map<String, dynamic> json) => GamePlay(
        id: json['id'].toString(),
        game: GameKey.parse(json['game']) ?? GameKey.tictactoe,
        gameName: json['gameName']?.toString() ?? '',
        businessName: json['businessName']?.toString(),
        prizeLabel: json['prizeLabel']?.toString(),
        status: json['status']?.toString() ?? 'sent',
        result: json['result']?.toString(),
        score: (json['score'] as num?)?.toInt(),
        claimCode: json['claimCode']?.toString(),
        play: json['play'] is Map ? Map<String, dynamic>.from(json['play'] as Map) : const {},
        startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
        expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}')?.toLocal(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
        attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
        lastAttempt: json['lastAttempt']?.toString(),
      );
}

/// Un envío del dueño (para su lista).
class SentGame {
  final String gameName;
  final String? userName;
  final String status;
  final String? result;

  /// Intentos que el cliente ya usó (de [maxAttempts]).
  final int attempts;
  final int maxAttempts;

  const SentGame({
    required this.gameName,
    required this.status,
    this.userName,
    this.result,
    this.attempts = 0,
    this.maxAttempts = 3,
  });

  factory SentGame.fromJson(Map<String, dynamic> json) => SentGame(
        gameName: json['gameName']?.toString() ?? '',
        userName: json['userName']?.toString(),
        status: json['status']?.toString() ?? 'sent',
        result: json['result']?.toString(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
      );
}

/// Lo que el dueño mandó: cifras y últimos envíos.
class SentGames {
  final int sent;
  final int played;
  final int won;
  final List<SentGame> items;

  const SentGames({this.sent = 0, this.played = 0, this.won = 0, this.items = const []});

  factory SentGames.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map ? Map<String, dynamic>.from(json['stats'] as Map) : const {};
    int n(String k) => (stats[k] as num?)?.toInt() ?? 0;
    return SentGames(
      sent: n('sent'),
      played: n('played'),
      won: n('won'),
      items: ((json['items'] as List?) ?? const [])
          .map((i) => SentGame.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

/// Resultado de mandar un juego.
class SendResult {
  final int sent;
  final int skipped;

  /// El horario con el que quedó el juego (lo confirma el servidor).
  final DateTime? startsAt;
  final DateTime? endsAt;

  const SendResult({required this.sent, required this.skipped, this.startsAt, this.endsAt});
}

final gamesRepositoryProvider = Provider<GamesRepository>((ref) => GamesRepository());

/// Los minijuegos de un negocio (para su dueño).
final gameAccessProvider = FutureProvider.autoDispose.family<GameAccess, String>(
  (ref, businessId) => ref.watch(gamesRepositoryProvider).access(businessId),
);

/// Lo que el dueño mandó a sus clientes.
final sentGamesProvider = FutureProvider.autoDispose.family<SentGames, String>(
  (ref, businessId) => ref.watch(gamesRepositoryProvider).sent(businessId),
);

/// Solicitudes de minijuegos (para el administrador).
final gameRequestsProvider = FutureProvider.autoDispose<List<GameAccess>>(
  (ref) => ref.watch(gamesRepositoryProvider).requests(),
);

/// Los retos del cliente.
final myGameInvitesProvider = FutureProvider.autoDispose<List<GameInvite>>(
  (ref) => ref.watch(gamesRepositoryProvider).myInvites(),
);

class GamesRepository {
  final ApiClient _api = ApiClient();

  // --- Dueño ---

  Future<GameAccess> access(String businessId) async {
    final response = await _api.get('games/access/$businessId');
    final json = Map<String, dynamic>.from(response as Map);
    json['businessId'] ??= businessId;
    return GameAccess.fromJson(json);
  }

  Future<GameAccess> request(String businessId, {String? note}) async {
    final response = await _api.post('games/requests', body: {
      'businessId': businessId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return GameAccess.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<SendResult> send(
    String businessId,
    GameKey game, {
    bool selected = false,
    List<String> recipientIds = const [],
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final response = await _api.post('games/invites', body: {
      'businessId': businessId,
      'game': game.apiValue,
      'audience': selected ? 'selected' : 'all',
      if (selected) 'recipientIds': recipientIds,
      if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
    });
    final json = Map<String, dynamic>.from(response as Map);
    return SendResult(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
      endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}')?.toLocal(),
    );
  }

  Future<SentGames> sent(String businessId) async {
    final response = await _api.get('games/sent/$businessId');
    return SentGames.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // --- Administrador ---

  Future<List<GameAccess>> requests({String? status}) async {
    final response = await _api.get('games/requests', queryParams: {
      if (status != null) 'status': status,
    });
    if (response is! List) return [];
    return response
        .map((r) => GameAccess.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> approve(
    String id, {
    required List<GameKey> games,
    required bool discount,
    int? value,
    String? label,
  }) async {
    await _api.patch('games/requests/$id/approve', body: {
      'games': games.map((g) => g.apiValue).toList(),
      'prizeType': discount ? 'discount_percent' : 'mini_prize',
      if (discount && value != null) 'prizeValue': value,
      if (label != null && label.trim().isNotEmpty) 'prizeLabel': label.trim(),
    });
  }

  Future<void> reject(String id, String reason) async {
    await _api.patch('games/requests/$id/reject', body: {'reason': reason.trim()});
  }

  // --- Cliente ---

  Future<List<GameInvite>> myInvites() async {
    final response = await _api.get('games/my-invites');
    if (response is! List) return [];
    return response
        .map((i) => GameInvite.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
  }

  Future<GamePlay> invite(String id) async => _play(await _api.get('games/invites/$id'));

  Future<GamePlay> start(String id) async => _play(await _api.post('games/invites/$id/start'));

  Future<GamePlay> guess(String id, String letter) async =>
      _play(await _api.post('games/invites/$id/guess', body: {'letter': letter}));

  Future<GamePlay> move(String id, int cell) async =>
      _play(await _api.post('games/invites/$id/move', body: {'cell': cell}));

  Future<GamePlay> finish(String id, int score) async =>
      _play(await _api.post('games/invites/$id/finish', body: {'score': score}));

  GamePlay _play(dynamic response) =>
      GamePlay.fromJson(Map<String, dynamic>.from(response as Map));
}
