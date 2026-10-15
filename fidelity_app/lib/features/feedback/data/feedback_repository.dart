import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

enum FeedbackKind {
  suggestion('suggestion', 'Sugerencia'),
  complaint('complaint', 'Reclamo'),
  praise('praise', 'Felicitación');

  final String apiValue;
  final String label;

  const FeedbackKind(this.apiValue, this.label);

  static FeedbackKind parse(Object? value) {
    for (final k in values) {
      if (k.apiValue == value) return k;
    }
    return suggestion;
  }
}

/// Calificación rápida de la atención (1 = mal, 2 = regular, 3 = excelente).
enum FeedbackRating {
  bad(1, 'Mal', Icons.sentiment_very_dissatisfied_rounded),
  fair(2, 'Regular', Icons.sentiment_neutral_rounded),
  great(3, 'Excelente', Icons.sentiment_very_satisfied_rounded);

  final int value;
  final String label;
  final IconData icon;

  const FeedbackRating(this.value, this.label, this.icon);

  static FeedbackRating? fromValue(Object? value) {
    for (final r in values) {
      if (r.value == value) return r;
    }
    return null;
  }

  /// Etiquetas de motivo que se ofrecen según la calificación.
  List<String> get tags => switch (this) {
        bad => const ['Demora', 'Mal trato', 'Local sucio', 'Pedido incorrecto', 'Precio'],
        fair => const ['Atención lenta', 'Podría mejorar', 'Poca variedad', 'Precio'],
        great => const [
            'Atención rápida',
            'Local impecable',
            'Amabilidad',
            'Buen precio',
            'Buen producto',
          ],
      };
}

class FeedbackItem {
  final String id;
  final String businessId;
  final String businessName;
  final String? userName;
  final String? userEmail;
  final FeedbackKind kind;
  final FeedbackRating? rating;
  final List<String> tags;
  final String? message;
  final bool isResolved;
  final String? reply;
  final DateTime? createdAt;

  const FeedbackItem({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.kind,
    required this.tags,
    required this.isResolved,
    this.userName,
    this.userEmail,
    this.rating,
    this.message,
    this.reply,
    this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map?;
    final user = json['user'] as Map?;
    return FeedbackItem(
      id: json['id'].toString(),
      businessId: json['businessId']?.toString() ?? '',
      businessName: business?['name']?.toString() ?? 'Local',
      userName: (user?['fullName'] ?? user?['full_name'])?.toString(),
      userEmail: user?['email']?.toString(),
      kind: FeedbackKind.parse(json['kind']),
      rating: FeedbackRating.fromValue(json['rating']),
      tags: ((json['tags'] as List?) ?? const []).map((t) => t.toString()).toList(),
      message: json['message']?.toString(),
      isResolved: json['status'] == 'resolved',
      reply: json['reply']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
    );
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) => FeedbackRepository());

/// Opiniones enviadas por el propio cliente.
final myFeedbackProvider = FutureProvider.autoDispose<List<FeedbackItem>>(
  (ref) => ref.watch(feedbackRepositoryProvider).listMine(),
);

class FeedbackRepository {
  final ApiClient _api = ApiClient();

  Future<void> send({
    required String businessId,
    FeedbackRating? rating,
    FeedbackKind? kind,
    List<String> tags = const [],
    String? message,
  }) async {
    await _api.post('feedback', body: {
      'businessId': businessId,
      if (rating != null) 'rating': rating.value,
      if (kind != null) 'kind': kind.apiValue,
      if (tags.isNotEmpty) 'tags': tags,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
  }

  Future<List<FeedbackItem>> listMine() async => _parse(await _api.get('feedback/mine'));

  /// Todas las opiniones (administrador).
  Future<List<FeedbackItem>> listAll() async => _parse(await _api.get('feedback'));

  /// Opiniones de un negocio (dueño o administrador).
  Future<List<FeedbackItem>> listForBusiness(String businessId) async =>
      _parse(await _api.get('feedback/business/$businessId'));

  Future<void> resolve(String id, {String? reply}) async {
    await _api.patch('feedback/$id/resolve', body: {
      if (reply != null && reply.trim().isNotEmpty) 'reply': reply.trim(),
    });
  }

  List<FeedbackItem> _parse(dynamic response) {
    if (response is! List) return [];
    return response
        .map((f) => FeedbackItem.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList();
  }
}
