import 'package:fidelity_app/core/utils/money_format.dart';
import 'package:fidelity_app/features/admin/admin_card_payouts_screen.dart';
import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/gift_card_form_screen.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:fidelity_app/features/card_sales/card_offer_screen.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/card_sales/my_sales_screen.dart';
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Datos de prueba en lugar de la red.
class _FakeSales extends CardSalesRepository {
  CardSalesRules rulesValue = const CardSalesRules(enabled: true, commissionPercent: 10);
  List<Campaign> offersValue = [];
  SalesSummary salesValue = const SalesSummary();
  PayoutsOverview payoutsValue = const PayoutsOverview();

  final List<String> purchases = [];
  final List<(String, String?)> settled = [];
  final List<(String, String?)> refunded = [];

  @override
  Future<CardSalesRules> rules() async => rulesValue;

  @override
  Future<List<Campaign>> offers() async => offersValue;

  @override
  Future<Uri> startPurchase(String campaignId) async {
    purchases.add(campaignId);
    return Uri.parse('https://pay.example.com/$campaignId');
  }

  @override
  Future<SalesSummary> mySales() async => salesValue;

  @override
  Future<PayoutsOverview> payouts() async => payoutsValue;

  @override
  Future<void> settle(String businessId, {String? note}) async => settled.add((businessId, note));

  @override
  Future<void> markRefunded(String purchaseId, {String? note}) async => refunded.add((purchaseId, note));
}

class _FakeCampaigns extends CampaignsRepository {
  final List<Map<String, Object?>> created = [];

  @override
  Future<List<Campaign>> mine() async => [];

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
    int? priceCents,
    int? stock,
    int? cardValidDays,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    created.add({
      'title': title,
      'businessIds': businessIds,
      'audience': audience,
      'priceCents': priceCents,
      'stock': stock,
      'cardValidDays': cardValidDays,
      'benefitLabel': benefitLabel,
    });
    return _offer();
  }
}

class _FakeGames extends GamesRepository {
  @override
  Future<List<GameInvite>> myInvites() async => const [];
}

Campaign _offer({
  String id = 'o1',
  String title = 'Café por 25 centavos',
  int priceCents = 25,
  int stock = 50,
  int stockLeft = 3,
  int validDays = 30,
  CampaignClaim? claim,
  DateTime? endsAt,
}) =>
    Campaign(
      id: id,
      type: CampaignType.giftCard,
      title: title,
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.miniPrize,
      benefitLabel: 'Café pequeño',
      priceCents: priceCents,
      stock: stock,
      stockLeft: stockLeft,
      cardValidDays: validDays,
      endsAt: endsAt,
      claim: claim,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('dinero', () {
    test('centsText muestra centavos como dólares', () {
      expect(centsText(25), '\$0.25');
      expect(centsText(100), '\$1.00');
      expect(centsText(1234), '\$12.34');
    });

    test('centsFromInput entiende lo que escribe el dueño', () {
      expect(centsFromInput('0.25'), 25);
      expect(centsFromInput('1,5'), 150);
      expect(centsFromInput(' \$2 '), 200);
      expect(centsFromInput('0.1'), 10);
      expect(centsFromInput(''), isNull);
      expect(centsFromInput('abc'), isNull);
      expect(centsFromInput('0'), isNull);
      expect(centsFromInput('-1'), isNull);
    });
  });

  group('modelos', () {
    test('una tarjeta en venta trae su precio, cupos y vigencia', () {
      final c = Campaign.fromJson({
        'id': 'o1',
        'type': 'gift_card',
        'title': 'Café',
        'phase': 'active',
        'priceCents': 25,
        'stock': 50,
        'stockLeft': 12,
        'cardValidDays': 30,
        'businesses': [
          {'id': 'b1', 'name': 'Café Aurora'},
        ],
      });

      expect(c.isForSale, isTrue);
      expect(c.priceText, '\$0.25');
      expect([c.stock, c.stockLeft, c.cardValidDays], [50, 12, 30]);
    });

    test('una gift card regalada no tiene precio', () {
      final c = Campaign.fromJson({'id': 'g1', 'type': 'gift_card', 'title': 'Regalo', 'phase': 'active'});

      expect(c.isForSale, isFalse);
      expect(c.priceText, '');
    });

    test('una tarjeta comprada vence en su propia fecha', () {
      final claim = CampaignClaim.fromJson({
        'id': 'cl1',
        'code': 'GFT-ABC234',
        'status': 'active',
        'source': 'purchase',
        'expiresAt': '2026-11-23T12:00:00.000Z',
      });

      expect(claim.isPurchase, isTrue);
      expect(claim.isRedeemed, isFalse);
      expect(claim.expiresAt, isNotNull);
      expect(CampaignClaim.fromJson({'id': 'x', 'code': 'c', 'source': 'claim'}).isPurchase, isFalse);
    });

    test('las reglas del administrador y el resumen de ventas se leen del servidor', () {
      final rules = CardSalesRules.fromJson({
        'enabled': true,
        'commissionPercent': 12,
        'minPriceCents': 25,
        'maxPriceCents': 2500,
      });
      expect([rules.enabled, rules.commissionPercent, rules.minPriceCents, rules.maxPriceCents], [true, 12, 25, 2500]);

      final sales = SalesSummary.fromJson({
        'sold': 3,
        'grossCents': 75,
        'commissionCents': 9,
        'netCents': 66,
        'redeemed': 2,
        'payableCents': 44,
        'paidOutCents': 0,
        'pendingCents': 22,
        'recent': [
          {'title': 'Café', 'buyer': 'Luis', 'amountCents': 25, 'netCents': 22, 'redeemed': true, 'settled': false},
        ],
      });
      expect([sales.sold, sales.payableCents, sales.recent.length], [3, 44, 1]);
      expect(sales.recent.first.redeemed, isTrue);
    });
  });

  group('el cheque en venta', () {
    testWidgets('muestra el precio y cuántos días vale desde la compra', (tester) async {
      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: GiftCardVoucher(campaign: _offer(), priceLabel: '\$0.25', businessName: 'Café Aurora'),
        ),
      ));

      expect(find.text('\$0.25'), findsOneWidget);
      expect(find.text('VALE 30 DÍAS DESDE LA COMPRA'), findsOneWidget);
    });

    testWidgets('una tarjeta ya comprada muestra hasta cuándo vale', (tester) async {
      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: GiftCardVoucher(
            campaign: _offer(),
            code: 'GFT-ABC234',
            validUntil: DateTime.utc(2026, 11, 23, 15),
            businessName: 'Café Aurora',
          ),
        ),
      ));

      expect(find.textContaining('VÁLIDA HASTA'), findsOneWidget);
      expect(find.textContaining('DESDE LA COMPRA'), findsNothing);
    });
  });

  group('CardOfferScreen (el cliente compra)', () {
    Future<_FakeSales> open(WidgetTester tester, Campaign offer, {List<Campaign>? listed}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeSales()..offersValue = listed ?? [offer];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(CardOfferScreen(offer: offer)),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('muestra el local, la vigencia, los cupos y el botón con el precio', (tester) async {
      await open(tester, _offer());

      expect(find.text('TARJETA EN VENTA'), findsOneWidget);
      expect(find.text('Café Aurora'), findsWidgets);
      expect(find.text('30 días desde que la compras'), findsOneWidget);
      expect(find.text('3 / 50'), findsOneWidget);
      expect(find.text('COMPRAR POR \$0.25'), findsOneWidget);
      expect(find.textContaining('PayPhone'), findsOneWidget);
    });

    testWidgets('al comprar, pide la página de pago de esa tarjeta', (tester) async {
      final repo = await open(tester, _offer());

      await tester.tap(find.text('COMPRAR POR \$0.25'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.purchases, ['o1']);
    });

    testWidgets('agotada: no se puede comprar', (tester) async {
      final repo = await open(tester, _offer(stockLeft: 0));

      expect(find.text('AGOTADA'), findsWidgets);
      expect(find.textContaining('COMPRAR POR'), findsNothing);
      await tester.tap(find.text('AGOTADA').last);
      await tester.pump();
      expect(repo.purchases, isEmpty);
    });

    testWidgets('si ya la compró, lo dice y lleva a Mis regalos', (tester) async {
      final bought = _offer(
        stockLeft: 0,
        claim: const CampaignClaim(id: 'cl1', code: 'GFT-ABC234', isRedeemed: false, isRoutePrize: false, isPurchase: true),
      );
      await open(tester, bought);

      expect(find.text('YA LA TIENES: VER MIS REGALOS'), findsOneWidget);
      expect(find.textContaining('COMPRAR POR'), findsNothing);
    });

    testWidgets('muestra hasta cuándo se vende, si tiene fin', (tester) async {
      await open(tester, _offer(endsAt: DateTime.now().add(const Duration(days: 3))));

      expect(find.text('SE VENDE HASTA'), findsOneWidget);
    });
  });

  group('banner de Fido con tarjetas en venta', () {
    Future<void> open(WidgetTester tester, List<Campaign> offers) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeSales()..offersValue = offers;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardSalesRepositoryProvider.overrideWithValue(repo),
            gamesRepositoryProvider.overrideWithValue(_FakeGames()),
          ],
          child: spanishApp(const Scaffold(body: FidoBannerCarousel(autoPlay: false))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('una sola tarjeta: dice qué es, a cuánto y en qué local', (tester) async {
      await open(tester, [_offer()]);

      expect(find.text('CAFÉ PEQUEÑO POR \$0.25'), findsOneWidget);
      expect(find.text('Café Aurora. Cómprala y canjéala en el local.'), findsOneWidget);
      expect(find.text('COMPRAR'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'Fido con un café'), findsOneWidget);
    });

    testWidgets('varias: dice cuántas y desde qué precio', (tester) async {
      await open(tester, [_offer(), _offer(id: 'o2', priceCents: 100)]);

      expect(find.text('2 TARJETAS EN VENTA'), findsOneWidget);
      expect(find.text('Desde \$0.25. Cómpralas con tarjeta.'), findsOneWidget);
    });

    testWidgets('las que ya compró no se ofrecen de nuevo', (tester) async {
      final bought = _offer(
        claim: const CampaignClaim(id: 'cl1', code: 'GFT-ABC234', isRedeemed: false, isRoutePrize: false, isPurchase: true),
      );
      await open(tester, [bought]);

      expect(find.text('COMPRAR'), findsNothing);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('sin ofertas no sale nada', (tester) async {
      await open(tester, const []);

      expect(find.byType(PageView), findsNothing);
    });
  });

  group('GiftCardFormScreen: poner la tarjeta en venta', () {
    Future<(_FakeCampaigns, _FakeSales)> open(WidgetTester tester, {bool enabled = true}) async {
      tester.view.physicalSize = const Size(900, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final campaigns = _FakeCampaigns();
      final sales = _FakeSales()..rulesValue = CardSalesRules(enabled: enabled, commissionPercent: 10);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campaignsRepositoryProvider.overrideWithValue(campaigns),
            cardSalesRepositoryProvider.overrideWithValue(sales),
            businessOverviewProvider.overrideWith(
              (ref) async => const [
                BusinessOverview(id: 'b1', name: 'Café Aurora', isActive: true),
              ],
            ),
          ],
          child: spanishApp(const GiftCardFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (campaigns, sales);
    }

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la gift card (ej. Regalo de aniversario)'), 'Café por 25 centavos');
      await tester.tap(find.text('MINI PREMIO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Mini premio (ej. Café pequeño gratis)'), 'Café pequeño');
    }

    testWidgets('si el administrador apagó la venta, no se ofrece', (tester) async {
      await open(tester, enabled: false);

      expect(find.text('¿LA REGALAS O LA VENDES?'), findsNothing);
      expect(find.text('LA VENDO'), findsNothing);
    });

    testWidgets('vender pide precio, cupos y vigencia, y explica la comisión del administrador', (tester) async {
      await open(tester);

      expect(find.text('¿LA REGALAS O LA VENDES?'), findsOneWidget);
      expect(find.text('Precio en dólares (ej. 0.25)'), findsNothing);

      await tester.tap(find.text('LA VENDO'));
      await tester.pumpAndSettle();

      expect(find.text('Precio en dólares (ej. 0.25)'), findsOneWidget);
      expect(find.text('Cuántas tarjetas pones a la venta'), findsOneWidget);
      expect(find.text('Días que vale la tarjeta tras comprarla'), findsOneWidget);
      expect(find.textContaining('Fidelity se queda el 10%'), findsOneWidget);
      // Una tarjeta en venta es para todos: ya no se elige a quién le llega.
      expect(find.textContaining('¿A QUIÉN LE LLEGA?'), findsNothing);
      // Los pasos se renumeran sin el de a quién le llega.
      expect(find.text('PASO 3 · PRECIO Y CUPOS'), findsOneWidget);
      expect(find.text('PASO 4 · NEGOCIO'), findsOneWidget);
      expect(find.text('PASO 5 · FECHA Y HORA'), findsOneWidget);
      expect(find.text('TERMINA LA VENTA'), findsOneWidget);
      expect(find.text('PONER EN VENTA'), findsOneWidget);
    });

    testWidgets('con precio, cupos y días válidos la pone en venta', (tester) async {
      final (campaigns, _) = await open(tester);
      await fill(tester);
      await tester.tap(find.text('LA VENDO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio en dólares (ej. 0.25)'), '0.25');
      await tester.enterText(find.widgetWithText(TextFormField, 'Cuántas tarjetas pones a la venta'), '40');
      await tester.enterText(find.widgetWithText(TextFormField, 'Días que vale la tarjeta tras comprarla'), '15');

      await tester.tap(find.text('PONER EN VENTA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(campaigns.created, hasLength(1));
      expect(campaigns.created.first, containsPair('priceCents', 25));
      expect(campaigns.created.first, containsPair('stock', 40));
      expect(campaigns.created.first, containsPair('cardValidDays', 15));
      expect(campaigns.created.first, containsPair('audience', CampaignAudience.all));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('un precio fuera de lo que permite el administrador no se envía', (tester) async {
      final (campaigns, _) = await open(tester);
      await fill(tester);
      await tester.tap(find.text('LA VENDO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio en dólares (ej. 0.25)'), '0.05');

      await tester.tap(find.text('PONER EN VENTA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(campaigns.created, isEmpty);
      expect(find.text('El precio debe estar entre \$0.25 y \$25.00.'), findsOneWidget);
    });

    testWidgets('sin precio no se envía', (tester) async {
      final (campaigns, _) = await open(tester);
      await fill(tester);
      await tester.tap(find.text('LA VENDO'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PONER EN VENTA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(campaigns.created, isEmpty);
      expect(find.text('Escribe el precio en dólares, por ejemplo 0.25.'), findsOneWidget);
    });

    testWidgets('regalarla sigue igual que antes: sin precio', (tester) async {
      final (campaigns, _) = await open(tester);
      await fill(tester);

      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(campaigns.created, hasLength(1));
      expect(campaigns.created.first, containsPair('priceCents', null));
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('MySalesScreen (lo vendido)', () {
    Future<void> open(WidgetTester tester, SalesSummary summary) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeSales()..salesValue = summary;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const MySalesScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin ventas lo explica', (tester) async {
      await open(tester, const SalesSummary());

      expect(find.text('AÚN NO VENDES TARJETAS'), findsOneWidget);
    });

    testWidgets('muestra lo que puede cobrar, lo vendido y la comisión', (tester) async {
      await open(
        tester,
        const SalesSummary(
          sold: 3,
          grossCents: 75,
          commissionCents: 9,
          netCents: 66,
          redeemed: 2,
          payableCents: 44,
          paidOutCents: 0,
          pendingCents: 22,
          recent: [
            SaleRow(title: 'Café pequeño', buyer: 'Luis Mora', amountCents: 25, netCents: 22, redeemed: true),
            SaleRow(title: 'Café pequeño', buyer: 'Ana Ruiz', amountCents: 25, netCents: 22, settled: true, redeemed: true),
            SaleRow(title: 'Café pequeño', buyer: 'Beto', amountCents: 25, netCents: 22),
          ],
        ),
      );

      expect(find.text('POR COBRAR'), findsWidgets);
      expect(find.text('\$0.44'), findsOneWidget);
      expect(find.textContaining('\$0.09 son la comisión de Fidelity'), findsOneWidget);
      // Estado de cada venta.
      expect(find.text('PAGADA'), findsOneWidget);
      expect(find.text('SIN CANJEAR'), findsWidgets);
    });
  });

  group('AdminCardPayoutsScreen (pagar a los locales)', () {
    Future<_FakeSales> open(WidgetTester tester, PayoutsOverview data) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeSales()..payoutsValue = data;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const AdminCardPayoutsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('sin nada por pagar lo dice', (tester) async {
      await open(tester, const PayoutsOverview());

      expect(find.text('NADA POR PAGAR'), findsOneWidget);
    });

    testWidgets('lista lo que se le debe a cada local y el total', (tester) async {
      await open(
        tester,
        const PayoutsOverview(payouts: [
          PayoutRow(businessId: 'b1', businessName: 'Café Aurora', ownerEmail: 'ana@x.com', cards: 2, netCents: 44),
          PayoutRow(businessId: 'b2', businessName: 'Pizzería Sol', cards: 5, netCents: 110),
        ]),
      );

      expect(find.text('\$1.54'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('2 tarjetas canjeadas · ana@x.com'), findsOneWidget);
      expect(find.text('REGISTRAR PAGO'), findsNWidgets(2));
    });

    testWidgets('registrar el pago pide la referencia y lo envía', (tester) async {
      final repo = await open(
        tester,
        const PayoutsOverview(payouts: [PayoutRow(businessId: 'b1', businessName: 'Café Aurora', cards: 1, netCents: 22)]),
      );

      await tester.tap(find.text('REGISTRAR PAGO'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ya le transferiste \$0.22'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Transferencia 123');
      await tester.tap(find.text('REGISTRAR PAGO').last);
      await tester.pumpAndSettle();

      expect(repo.settled, [('b1', 'Transferencia 123')]);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('cancelar el diálogo no registra nada', (tester) async {
      final repo = await open(
        tester,
        const PayoutsOverview(payouts: [PayoutRow(businessId: 'b1', businessName: 'Café Aurora', cards: 1, netCents: 22)]),
      );

      await tester.tap(find.text('REGISTRAR PAGO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.settled, isEmpty);
    });

    testWidgets('las compras cobradas dos veces aparecen por devolver', (tester) async {
      final repo = await open(
        tester,
        const PayoutsOverview(refunds: [
          RefundRow(id: 'p9', reference: 'TJ-ABC234', amountCents: 25, buyer: 'Luis', businessName: 'Café Aurora'),
        ]),
      );

      expect(find.text('POR DEVOLVER'), findsOneWidget);
      expect(find.text('TJ-ABC234'), findsOneWidget);

      await tester.tap(find.text('YA LA DEVOLVÍ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YA LA DEVOLVÍ').last);
      await tester.pumpAndSettle();

      expect(repo.refunded, [('p9', '')]);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
