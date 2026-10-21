import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/widgets/campaign_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> json(Map<String, dynamic> extra) => {
        'id': 'c1',
        'type': 'gift_card',
        'title': 'Aniversario',
        'phase': 'active',
        'startsAt': '2026-10-01T10:00:00.000Z',
        'businesses': [
          {'id': 'b1', 'name': 'Café Aurora'},
          {'id': 'b2', 'name': 'Café Norte', 'logoUrl': null},
        ],
        ...extra,
      };

  group('Campaign.fromJson', () {
    test('lee una tarjeta de regalo reclamada', () {
      final c = Campaign.fromJson(json({
        'benefitType': 'discount_percent',
        'benefitValue': 20,
        'benefitLabel': '20% de descuento',
        'claim': {'id': 'cl1', 'code': 'GFT-ABC234', 'status': 'active', 'source': 'claim'},
      }));

      expect(c.type, CampaignType.giftCard);
      expect(c.benefitType, CampaignBenefit.discountPercent);
      expect(c.benefitLabel, '20% de descuento');
      expect(c.claim?.code, 'GFT-ABC234');
      expect(c.claim?.isRedeemed, isFalse);
      expect(c.businesses.map((b) => b.name), ['Café Aurora', 'Café Norte']);
      expect(c.isActive, isTrue);
    });

    test('lee una ruta con sus sellos y las cifras del dueño', () {
      final c = Campaign.fromJson(json({
        'type': 'route',
        'requiredStamps': 2,
        'stampedBusinessIds': ['b1'],
        'completed': false,
        'stats': {'claims': 3, 'redeemed': 1, 'participants': 5},
      }));

      expect(c.type, CampaignType.route);
      expect(c.stampsNeeded, 2);
      expect(c.stampedBusinessIds, ['b1']);
      expect(c.stats?.claims, 3);
      expect(c.stats?.participants, 5);
    });

    test('sin requiredStamps la ruta pide un sello por local', () {
      final c = Campaign.fromJson(json({'type': 'route'}));

      expect(c.stampsNeeded, 2);
    });

    test('valores desconocidos caen en valores seguros', () {
      final c = Campaign.fromJson(json({'type': '???', 'phase': '???', 'benefitType': 'x'}));

      expect(c.type, CampaignType.event);
      expect(c.phase, CampaignPhase.active);
      expect(c.benefitType, isNull);
    });
  });

  test('CampaignClaim distingue canjeadas y premios de ruta', () {
    final claim = CampaignClaim.fromJson({
      'id': 'x',
      'code': 'RTA-AAAAAA',
      'status': 'redeemed',
      'source': 'route_complete',
    });

    expect(claim.isRedeemed, isTrue);
    expect(claim.isRoutePrize, isTrue);
  });

  group('textos de la campaña', () {
    test('vigencia según la fase', () {
      expect(campaignValidity(Campaign.fromJson(json({'phase': 'ended'}))), 'Terminó');
      expect(campaignValidity(Campaign.fromJson(json({'phase': 'cancelled'}))), 'Cancelada');
      expect(campaignValidity(Campaign.fromJson(json({'phase': 'active'}))), 'Sin fecha de fin');
      expect(
        campaignValidity(Campaign.fromJson(json({'phase': 'active', 'endsAt': '2026-12-31T20:00:00.000Z'}))),
        startsWith('Hasta el 31/12/2026'),
      );
      expect(
        campaignValidity(Campaign.fromJson(json({'phase': 'scheduled'}))),
        startsWith('Empieza el '),
      );
    });

    test('titular según el tipo', () {
      expect(
        campaignHeadline(Campaign.fromJson(json({'benefitLabel': '20% de descuento'}))),
        '20% de descuento',
      );
      expect(
        campaignHeadline(Campaign.fromJson(json({'type': 'route', 'benefitLabel': 'Taza'}))),
        'Gana: Taza',
      );
      expect(
        campaignHeadline(Campaign.fromJson(json({'type': 'event', 'description': 'Noche de jazz'}))),
        'Noche de jazz',
      );
      expect(
        campaignHeadline(Campaign.fromJson(json({'type': 'event'}))),
        'Novedades de Café Aurora',
      );
    });
  });

  test('cada tipo de campaña tiene su valor de API', () {
    expect(CampaignType.values.map((t) => t.apiValue), ['event', 'gift_card', 'route', 'scan_challenge']);
    expect(CampaignType.parse('gift_card'), CampaignType.giftCard);
    expect(CampaignBenefit.parse('mini_prize'), CampaignBenefit.miniPrize);
  });
}
