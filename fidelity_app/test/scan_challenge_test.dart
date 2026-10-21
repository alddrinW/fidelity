import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/campaigns/campaign_detail_screen.dart';
import 'package:fidelity_app/features/campaigns/campaign_form_screen.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/widgets/campaign_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Guarda lo que se manda a crear, sin red.
class _FakeCampaigns extends CampaignsRepository {
  final List<Map<String, Object?>> created = [];

  @override
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
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    created.add({
      'type': type,
      'title': title,
      'businessIds': businessIds,
      'benefitType': benefitType,
      'benefitValue': benefitValue,
      'benefitLabel': benefitLabel,
      'requiredScans': requiredScans,
      'requiredStamps': requiredStamps,
    });
    return _challenge();
  }
}

Campaign _challenge({int progress = 2, int needed = 5, CampaignClaim? claim}) => Campaign(
      id: 'ch1',
      type: CampaignType.scanChallenge,
      title: 'Reto de la semana',
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.discountPercent,
      benefitValue: 15,
      benefitLabel: '15% de descuento',
      requiredScans: needed,
      scanProgress: progress,
      claim: claim,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('modelo', () {
    test('lee los escaneos que pide el reto y el avance del cliente', () {
      final c = Campaign.fromJson({
        'id': 'ch1',
        'type': 'scan_challenge',
        'title': 'Reto',
        'phase': 'active',
        'benefitLabel': '15% de descuento',
        'requiredScans': 5,
        'scanProgress': 3,
        'businesses': [
          {'id': 'b1', 'name': 'Café Aurora'}
        ],
      });

      expect(c.type, CampaignType.scanChallenge);
      expect(c.scansNeeded, 5);
      expect(c.scanProgress, 3);
    });

    test('sin esos datos el avance es 0', () {
      final c = Campaign.fromJson({'id': '1', 'type': 'event', 'title': 'x', 'phase': 'active', 'businesses': []});

      expect(c.scansNeeded, 0);
      expect(c.scanProgress, 0);
    });

    test('el premio de un reto se trata como premio (no como gift card reclamada)', () {
      final claim = CampaignClaim.fromJson({'id': '1', 'code': 'RTO-ABC234', 'status': 'active', 'source': 'challenge_complete'});

      expect(claim.isRoutePrize, isTrue);
      expect(CampaignClaim.fromJson({'id': '2', 'code': 'GFT-AAAAAA', 'status': 'active', 'source': 'claim'}).isRoutePrize, isFalse);
    });

    test('el reto tiene su propio nombre, ícono y resumen', () {
      expect(CampaignType.scanChallenge.label, 'Reto de escaneos');
      expect(CampaignType.parse('scan_challenge'), CampaignType.scanChallenge);
      expect(campaignHeadline(_challenge()), '5 escaneos y ganas: 15% de descuento');
      expect(campaignColors(CampaignType.scanChallenge).background, isNotNull);
    });
  });

  group('formulario del dueño', () {
    late _FakeCampaigns repo;

    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeCampaigns();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          campaignsRepositoryProvider.overrideWithValue(repo),
          businessOverviewProvider.overrideWith(
            (ref) async => const [BusinessOverview(id: 'b1', name: 'Café Aurora', isActive: true)],
          ),
        ],
        child: spanishApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CampaignFormScreen()),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece el reto de escaneos entre los tipos de campaña', (tester) async {
      await openForm(tester);

      expect(find.text('Reto de escaneos'), findsOneWidget);
      expect(find.text('El cliente gana un premio al hacer varios escaneos'), findsOneWidget);
    });

    testWidgets('al elegirlo pide cuántos escaneos y el premio', (tester) async {
      await openForm(tester);
      expect(find.text('ESCANEOS QUE PIDES'), findsNothing);

      await tester.tap(find.text('Reto de escaneos'));
      await tester.pumpAndSettle();

      expect(find.text('ESCANEOS QUE PIDES'), findsOneWidget);
      expect(find.text('Cuántos escaneos debe hacer el cliente'), findsOneWidget);
      expect(find.text('PREMIO DEL RETO'), findsOneWidget);
      expect(find.text('DESCUENTO'), findsOneWidget);
      expect(find.text('MINI PREMIO'), findsOneWidget);
      // Por defecto pide 5.
      expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
    });

    testWidgets('crea el reto con el número de escaneos y el descuento', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Reto de escaneos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Título de la campaña'), 'Reto de la semana');
      await tester.enterText(find.widgetWithText(TextFormField, '5'), '8');
      await tester.pumpAndSettle();
      await tester.tap(find.text('LANZAR CAMPAÑA'));
      await tester.pumpAndSettle();

      expect(repo.created, hasLength(1));
      expect(repo.created.single, {
        'type': CampaignType.scanChallenge,
        'title': 'Reto de la semana',
        'businessIds': ['b1'],
        'benefitType': CampaignBenefit.discountPercent,
        'benefitValue': 10,
        'benefitLabel': null,
        'requiredScans': 8,
        'requiredStamps': null,
      });
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un mini premio manda su descripción', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Reto de escaneos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MINI PREMIO'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Título de la campaña'), 'Reto del café');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mini premio (ej. Café pequeño gratis)'), 'Café gratis');
      await tester.pumpAndSettle();
      await tester.tap(find.text('LANZAR CAMPAÑA'));
      await tester.pumpAndSettle();

      expect(repo.created.single['benefitType'], CampaignBenefit.miniPrize);
      expect(repo.created.single['benefitLabel'], 'Café gratis');
      expect(repo.created.single['benefitValue'], isNull);
      expect(repo.created.single['requiredScans'], 5);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('no deja crear un reto con menos de 2 escaneos', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Reto de escaneos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Título de la campaña'), 'Reto malo');
      await tester.enterText(find.widgetWithText(TextFormField, '5'), '1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('LANZAR CAMPAÑA'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un número entre 2 y 100'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('las otras campañas no piden escaneos', (tester) async {
      await openForm(tester);

      expect(find.text('ESCANEOS QUE PIDES'), findsNothing);
      await tester.tap(find.text('Evento'));
      await tester.pumpAndSettle();
      expect(find.text('ESCANEOS QUE PIDES'), findsNothing);
    });
  });

  group('lo que ve el cliente', () {
    Future<void> openDetail(WidgetTester tester, Campaign campaign) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: spanishApp(CampaignDetailScreen(campaign: campaign, claim: campaign.claim)),
      ));
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('muestra cuántos escaneos lleva y qué gana', (tester) async {
      await openDetail(tester, _challenge(progress: 2, needed: 5));

      expect(find.text('REGALO'), findsNothing);
      expect(find.text('RETO DE LA SEMANA'), findsOneWidget);
      expect(find.text('TU AVANCE · 2 DE 5 ESCANEOS'), findsOneWidget);
      expect(find.textContaining('Haz 5 escaneos en Café Aurora'), findsOneWidget);
      expect(find.textContaining('15% de descuento'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('si ya lo completó muestra su código para canjear', (tester) async {
      final claim = CampaignClaim.fromJson({'id': 'c', 'code': 'RTO-ABC234', 'status': 'active', 'source': 'challenge_complete'});
      await openDetail(tester, _challenge(progress: 5, claim: claim));

      expect(find.text('TU AVANCE · 5 DE 5 ESCANEOS'), findsOneWidget);
      expect(find.textContaining('¡Lo lograste!'), findsOneWidget);
      expect(find.text('RTO-ABC234'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('el avance nunca pasa del número pedido', (tester) async {
      await openDetail(tester, _challenge(progress: 9, needed: 5));

      expect(find.text('TU AVANCE · 5 DE 5 ESCANEOS'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
