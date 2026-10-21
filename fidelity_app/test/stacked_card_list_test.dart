import 'package:fidelity_app/core/widgets/stacked_card_list.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

Campaign gift(String title, int value) => Campaign(
      id: title,
      type: CampaignType.giftCard,
      title: title,
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.discountPercent,
      benefitValue: value,
      benefitLabel: '$value% de descuento',
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Vilcanatu')],
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<List<String>> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tapped = <String>[];
    final gifts = [gift('Premio ahorcado', 20), gift('Regalo Fidelity', 20), gift('Regalo', 10)];
    await tester.pumpWidget(spanishApp(
      Scaffold(
        body: StackedCardList(
          itemCount: gifts.length,
          itemBuilder: (context, i) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tapped.add(gifts[i].title),
            child: GiftCardVoucher(
              campaign: gifts[i],
              code: 'GFT-ABC23$i',
              businessName: 'Vilcanatu',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tapped;
  }

  testWidgets('cada regalo se ve con el diseño del cheque del local', (tester) async {
    await pumpList(tester);

    expect(find.byType(GiftCardVoucher), findsNWidgets(3));
    expect(find.text('PREMIO AHORCADO'), findsOneWidget);
    expect(find.text('GFT-ABC231'), findsOneWidget);
  });

  testWidgets('los cheques se montan unos sobre otros', (tester) async {
    await pumpList(tester);

    final primero = tester.getRect(find.byType(GiftCardVoucher).at(0));
    final segundo = tester.getRect(find.byType(GiftCardVoucher).at(1));
    final tercero = tester.getRect(find.byType(GiftCardVoucher).at(2));
    expect(segundo.top, lessThan(primero.bottom));
    expect(tercero.top, lessThan(segundo.bottom));
    // Y la siguiente va por encima: el solape es constante, no se acumula.
    expect(primero.bottom - segundo.top, closeTo(segundo.bottom - tercero.top, 0.5));
  });

  testWidgets('el toque cae en el cheque que se ve, no en el de abajo', (tester) async {
    final tapped = await pumpList(tester);

    // Justo en la franja donde el segundo cheque tapa al primero.
    final primero = tester.getRect(find.byType(GiftCardVoucher).at(0));
    await tester.tapAt(Offset(primero.center.dx, primero.bottom - 4));
    await tester.pump();
    expect(tapped, ['Regalo Fidelity']);

    await tester.tapAt(tester.getRect(find.byType(GiftCardVoucher).at(0)).center);
    await tester.pump();
    expect(tapped, ['Regalo Fidelity', 'Premio ahorcado']);
  });
}
