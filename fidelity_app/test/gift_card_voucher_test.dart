import 'package:fidelity_app/core/widgets/scratch_card.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

Campaign gift({
  String title = 'Regalo de aniversario',
  int benefitValue = 20,
  String benefitLabel = '20% de descuento',
  DateTime? endsAt,
}) =>
    Campaign(
      id: 'g1',
      type: CampaignType.giftCard,
      title: title,
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.discountPercent,
      benefitValue: benefitValue,
      benefitLabel: benefitLabel,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
      endsAt: endsAt,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GiftCardVoucher', () {
    testWidgets('muestra el local, el nombre, el beneficio y el código',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: SingleChildScrollView(
            child: GiftCardVoucher(
              campaign: gift(endsAt: DateTime.utc(2026, 12, 10, 23, 0)),
              code: 'GFT-ABC234',
              businessName: 'Café Aurora',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('REGALO DE ANIVERSARIO'), findsOneWidget);
      expect(find.text('20% DE DESCUENTO'), findsOneWidget);
      // Con su día y su hora (en hora de Ecuador: 23:00 UTC = 18:00).
      expect(find.text('VÁLIDA HASTA 10/12/2026 18:00'), findsOneWidget);
      expect(find.text('GFT-ABC234'), findsOneWidget);
    });

    testWidgets('el beneficio se tapa con una capa raspable', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: SingleChildScrollView(
            child: GiftCardVoucher(campaign: gift(), scratchable: true),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ScratchCard), findsOneWidget);
    });

    testWidgets('una gift card canjeada se ve apagada', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: SingleChildScrollView(
            child: GiftCardVoucher(campaign: gift(), redeemed: true),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Se apaga con un velo, no con transparencia (no deja ver lo de abajo).
      expect(find.byKey(const ValueKey('redeemed-veil')), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('ScratchCard', () {
    testWidgets('raspar avisa que el premio ya está a la vista',
        (tester) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var revealed = false;
      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: ScratchCard(
                onRevealed: () => revealed = true,
                child: const Center(child: Text('PREMIO')),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(revealed, isFalse);

      // Raspando de un lado al otro.
      await tester.drag(find.byType(ScratchCard), const Offset(260, 0));
      await tester.pumpAndSettle();

      expect(revealed, isTrue);
      expect(find.text('PREMIO'), findsOneWidget);
    });

    testWidgets('si ya está revelado no hay nada que raspar', (tester) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var revealed = false;
      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: ScratchCard(
                revealed: true,
                onRevealed: () => revealed = true,
                child: const Center(child: Text('PREMIO')),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsNothing);
      expect(find.text('PREMIO'), findsOneWidget);
      expect(revealed, isFalse);
    });
  });
}
