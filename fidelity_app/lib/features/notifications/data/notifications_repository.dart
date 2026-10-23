import 'dart:async';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/inbox_events.dart';

/// Un movimiento de la bandeja del usuario.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AppNotification(
      id: json['id'].toString(),
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
      read: json['read'] == true,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ?? DateTime.now(),
    );
  }

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        read: true,
        createdAt: createdAt,
      );

  /// Ruta a la que lleva al tocarla (la misma que usa el push).
  String? get route => data['route']?.toString();

  /// Icono según el movimiento: primero por tipo y, si no, por la ruta.
  IconData get icon => switch (type) {
        'gift_card' || 'gift_card_updated' || 'gift_card_cancelled' => Icons.card_giftcard_rounded,
        'claim_redeemed' => Icons.check_circle_outline_rounded,
        'route_completed' || 'route_stamp' => Icons.route_rounded,
        'campaign' => Icons.campaign_outlined,
        'birthday' => Icons.cake_outlined,
        'fidely' => Icons.favorite_rounded,
        'business_activated' => Icons.storefront_outlined,
        'payment_rejected' => Icons.payments_outlined,
        'admin' => Icons.admin_panel_settings_outlined,
        'game_invite' || 'game_won' || 'game_won_owner' || 'games_approved' || 'games_rejected' =>
          Icons.sports_esports_rounded,
        _ => switch (route) {
            '/points_approved' => Icons.stars_rounded,
            '/reward' || '/transfer_received' => Icons.emoji_events_outlined,
            '/business_dashboard/pending' => Icons.pending_actions_rounded,
            '/business_dashboard/rewards' => Icons.emoji_events_outlined,
            _ => Icons.notifications_none_rounded,
          },
      };
}

class NotificationsRepository {
  final ApiClient _api = ApiClient();

  /// Movimientos del más nuevo al más viejo. [before] pide la página siguiente.
  Future<List<AppNotification>> list({DateTime? before, int limit = 30}) async {
    final response = await _api.get('notifications', queryParams: {
      'limit': '$limit',
      if (before != null) 'before': before.toUtc().toIso8601String(),
    });
    if (response is! List) return [];
    return response
        .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
  }

  Future<int> unreadCount() async {
    final response = await _api.get('notifications/unread-count');
    return (response is Map ? (response['count'] as num?)?.toInt() : null) ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.patch('notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.patch('notifications/read-all');
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository());

/// Cuántas notificaciones sin leer tiene el usuario. Se consulta al mostrar la
/// campana, cada minuto y cuando llega un aviso con la app abierta.
final unreadCountProvider =
    NotifierProvider.autoDispose<UnreadCountNotifier, int>(UnreadCountNotifier.new);

class UnreadCountNotifier extends AutoDisposeNotifier<int> {
  Timer? _timer;

  @override
  int build() {
    inboxEvents.addListener(refresh);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    ref.onDispose(() {
      _timer?.cancel();
      inboxEvents.removeListener(refresh);
    });
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final count = await ref.read(notificationsRepositoryProvider).unreadCount();
      state = count;
    } catch (_) {
      // Sin red o sin sesión: se conserva el último valor.
    }
  }

  /// Ajuste inmediato al leer o marcar todas (sin esperar al servidor).
  void set(int count) => state = count < 0 ? 0 : count;
}
