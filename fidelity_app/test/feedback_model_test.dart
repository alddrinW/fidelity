import 'package:fidelity_app/features/feedback/data/feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackItem.fromJson', () {
    test('lee un reclamo abierto con su cliente y su local', () {
      final item = FeedbackItem.fromJson({
        'id': 'f1',
        'businessId': 'b1',
        'business': {'name': 'Café Aurora'},
        'user': {'fullName': 'Luis Mora', 'email': 'luis@mail.com'},
        'kind': 'complaint',
        'rating': 1,
        'tags': ['Demora', 'Mal trato'],
        'message': 'Esperé 40 minutos',
        'status': 'open',
        'createdAt': '2026-10-14T15:00:00.000Z',
      });

      expect(item.kind, FeedbackKind.complaint);
      expect(item.rating, FeedbackRating.bad);
      expect(item.tags, ['Demora', 'Mal trato']);
      expect(item.userName, 'Luis Mora');
      expect(item.businessName, 'Café Aurora');
      expect(item.isResolved, isFalse);
      expect(item.createdAt, isNotNull);
    });

    test('una felicitación resuelta sin comentario ni respuesta', () {
      final item = FeedbackItem.fromJson({
        'id': 'f2',
        'kind': 'praise',
        'rating': 3,
        'status': 'resolved',
      });

      expect(item.kind, FeedbackKind.praise);
      expect(item.rating, FeedbackRating.great);
      expect(item.isResolved, isTrue);
      expect(item.tags, isEmpty);
      expect(item.message, isNull);
      expect(item.businessName, 'Local');
    });

    test('valores desconocidos caen en valores seguros', () {
      final item = FeedbackItem.fromJson({'id': 'f3', 'kind': '???', 'rating': 7});

      expect(item.kind, FeedbackKind.suggestion);
      expect(item.rating, isNull);
    });
  });

  test('cada calificación ofrece sus propias etiquetas de motivo', () {
    expect(FeedbackRating.bad.tags, contains('Demora'));
    expect(FeedbackRating.great.tags, contains('Atención rápida'));
    expect(FeedbackRating.bad.tags, isNot(contains('Atención rápida')));
    for (final rating in FeedbackRating.values) {
      // El backend acepta hasta 5 etiquetas por opinión.
      expect(rating.tags.length, lessThanOrEqualTo(5));
    }
  });
}
