import 'package:fidelity_app/core/widgets/app_card.dart';
import 'package:fidelity_app/features/business/data/business_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/cards/customer_explore_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

class _Sales extends CardSalesRepository {
  @override
  Future<List<Campaign>> offers() async => [
        const Campaign(
          id: 'o1',
          type: CampaignType.giftCard,
          title: 'Café de \$1 por \$0.25',
          phase: CampaignPhase.active,
          benefitType: CampaignBenefit.miniPrize,
          benefitLabel: 'Café de \$1',
          priceCents: 25,
          stock: 50,
          stockLeft: 50,
          businesses: [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
        ),
      ];
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('la tarjeta en venta de Explorar es blanca, sin fondo rosado', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardSalesRepositoryProvider.overrideWithValue(_Sales()),
          businessesDirectoryProvider.overrideWith((ref) async => const []),
          campaignFeedProvider.overrideWith((ref) async => const []),
        ],
        child: spanishApp(const Scaffold(body: CustomerExploreView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TARJETAS EN VENTA'), findsOneWidget);
    final tile = tester.widget<AppCard>(find.ancestor(of: find.text('CAFÉ DE \$1'), matching: find.byType(AppCard)).first);
    // Sin color propio: usa el blanco de las tarjetas.
    expect(tile.color, isNull);
  });
}
