import 'dart:convert';

import 'package:fidelity_app/core/utils/image_picking.dart';
import 'package:fidelity_app/features/admin/admin_card_reviews_screen.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/card_sales/card_offer_screen.dart';
import 'package:fidelity_app/features/card_sales/card_transfer_screen.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/payments/data/payments_repository.dart' show BankAccount;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Una imagen de 1 × 1 píxel.
final _pngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
final _picked = PickedImage(bytes: _pngBytes, dataUri: 'data:image/png;base64,${base64Encode(_pngBytes)}');
const _bank = BankAccount(bank: 'Banco Pichincha', accountNumber: '2200112233', accountType: 'Ahorros', holder: 'Fidelity S.A.', taxId: '1790012345001');

class _FakeSales extends CardSalesRepository {
  CardSalesRules rulesValue = const CardSalesRules(enabled: true, transferEnabled: true, cardEnabled: false, bankAccounts: [_bank]);
  List<Campaign> offersValue = [];
  List<CardReview> reviewsValue = [];

  final List<String> cardPurchases = [];
  final List<String> transfers = [];
  final List<(String, String, String?)> proofs = [];
  final List<String> approved = [];
  final List<(String, String)> rejected = [];
  Object? failWith;

  @override
  Future<CardSalesRules> rules() async => rulesValue;

  @override
  Future<List<Campaign>> offers() async => offersValue;

  @override
  Future<Uri> startPurchase(String campaignId) async {
    cardPurchases.add(campaignId);
    return Uri.parse('https://pay.example.com/$campaignId');
  }

  @override
  Future<TransferStart> startTransfer(String campaignId) async {
    transfers.add(campaignId);
    return TransferStart(
      purchaseId: 'p-new',
      reference: 'TJ-NEW234',
      amountCents: 25,
      reservedUntil: DateTime.now().add(const Duration(hours: 12)),
      bankAccounts: const [_bank],
    );
  }

  @override
  Future<void> submitProof(String purchaseId, String proofDataUri, {String? note}) async {
    if (failWith != null) throw failWith!;
    proofs.add((purchaseId, proofDataUri, note));
  }

  @override
  Future<List<CardReview>> reviews() async => reviewsValue;

  @override
  Future<void> approveReview(String purchaseId) async {
    if (failWith != null) throw failWith!;
    approved.add(purchaseId);
  }

  @override
  Future<void> rejectReview(String purchaseId, String reason) async {
    if (failWith != null) throw failWith!;
    rejected.add((purchaseId, reason));
  }
}

Campaign _offer({TransferPurchase? purchase, CampaignClaim? claim, int stockLeft = 3}) => Campaign(
      id: 'o1',
      type: CampaignType.giftCard,
      title: 'Café por 25 centavos',
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.miniPrize,
      benefitLabel: 'Café de \$1',
      priceCents: 25,
      stock: 50,
      stockLeft: stockLeft,
      cardValidDays: 30,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
      purchase: purchase,
      claim: claim,
    );

TransferPurchase _purchase(String status, {String? reviewNote}) => TransferPurchase(
      id: 'p1',
      status: status,
      reference: 'TJ-ABC234',
      amountCents: 25,
      reservedUntil: status == 'pending' ? DateTime.now().add(const Duration(hours: 5)) : null,
      reviewNote: reviewNote,
    );

CardReview _review({String id = 'r1', String? proofUrl}) => CardReview(
      id: id,
      reference: 'TJ-ABC234',
      amountCents: 25,
      title: 'Café de \$1',
      buyer: 'Luis Mora',
      buyerEmail: 'luis@test.com',
      businessName: 'Café Aurora',
      proofUrl: proofUrl ?? 'data:image/png;base64,${base64Encode(_pngBytes)}',
      note: 'Transferencia 987654',
      reportedAt: DateTime(2026, 10, 27, 10, 5),
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('modelos', () {
    test('las reglas traen con qué se puede pagar y las cuentas', () {
      final rules = CardSalesRules.fromJson({
        'enabled': true,
        'cardEnabled': true,
        'transferEnabled': true,
        'bankAccounts': [
          {'bank': 'Banco Pichincha', 'accountNumber': '2200112233', 'holder': 'Fidelity S.A.'},
        ],
      });

      expect(rules.canChoose, isTrue);
      expect(rules.bankAccounts.single.accountNumber, '2200112233');
    });

    test('sin esos datos (servidor viejo) se asume solo PayPhone', () {
      final rules = CardSalesRules.fromJson({'enabled': true});

      expect(rules.cardEnabled, isTrue);
      expect(rules.transferEnabled, isFalse);
      expect(rules.canChoose, isFalse);
      expect(rules.bankAccounts, isEmpty);
    });

    test('la oferta trae su compra por transferencia en curso', () {
      final offer = Campaign.fromJson({
        'id': 'o1',
        'type': 'gift_card',
        'title': 'Café',
        'purchase': {
          'id': 'p1',
          'status': 'rejected',
          'reference': 'TJ-ABC234',
          'amountCents': 25,
          'reservedUntil': null,
          'reviewNote': 'El monto no coincide',
        },
      });

      expect(offer.purchase!.isRejected, isTrue);
      expect(offer.purchase!.reviewNote, 'El monto no coincide');
      expect(offer.purchase!.reservedUntil, isNull);
      expect(Campaign.fromJson({'id': 'o2', 'type': 'gift_card', 'title': 'x', 'purchase': null}).purchase, isNull);
    });

    test('el comprobante por revisar', () {
      final review = CardReview.fromJson({
        'id': 'r1',
        'reference': 'TJ-ABC234',
        'amountCents': 25,
        'title': 'Café',
        'buyer': 'Luis',
        'proofUrl': 'https://x.test/a.png',
        'reportedAt': '2026-10-27T15:05:00.000Z',
      });

      expect(review.amountCents, 25);
      expect(review.reportedAt, isNotNull);
      expect(review.note, isNull);
    });
  });

  group('CardOfferScreen: pagar por transferencia', () {
    Future<_FakeSales> open(
      WidgetTester tester,
      Campaign offer, {
      CardSalesRules? rules,
    }) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeSales()..offersValue = [offer];
      if (rules != null) repo.rulesValue = rules;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(CardOfferScreen(offer: offer)),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('si solo hay transferencia, comprar abre la pantalla de transferencia sin preguntar', (tester) async {
      final repo = await open(tester, _offer());

      expect(find.textContaining('Pagas por transferencia bancaria'), findsOneWidget);
      await tester.tap(find.text('COMPRAR POR \$0.25'));
      await tester.pumpAndSettle();

      expect(repo.transfers, ['o1']);
      expect(repo.cardPurchases, isEmpty);
      expect(find.text('PAGAR POR TRANSFERENCIA'), findsOneWidget);
      expect(find.text('TJ-NEW234'), findsOneWidget);
    });

    testWidgets('si hay las dos formas, el cliente elige', (tester) async {
      final repo = await open(
        tester,
        _offer(),
        rules: const CardSalesRules(enabled: true, transferEnabled: true, bankAccounts: [_bank]),
      );

      expect(find.textContaining('o por transferencia bancaria'), findsOneWidget);
      await tester.tap(find.text('COMPRAR POR \$0.25'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('¿CÓMO QUIERES PAGAR?'), findsOneWidget);
      expect(find.text('Tarjeta de crédito o débito'), findsOneWidget);
      expect(find.text('Transferencia bancaria'), findsOneWidget);
      expect(repo.transfers, isEmpty);

      await tester.tap(find.text('Transferencia bancaria'));
      await tester.pumpAndSettle();
      expect(repo.transfers, ['o1']);
      expect(find.text('PAGAR POR TRANSFERENCIA'), findsOneWidget);
    });

    testWidgets('elegir tarjeta sigue yendo a PayPhone', (tester) async {
      final repo = await open(
        tester,
        _offer(),
        rules: const CardSalesRules(enabled: true, transferEnabled: true, bankAccounts: [_bank]),
      );

      await tester.tap(find.text('COMPRAR POR \$0.25'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Tarjeta de crédito o débito'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.cardPurchases, ['o1']);
      expect(repo.transfers, isEmpty);
    });

    testWidgets('solo con tarjeta no cambia nada (no pregunta)', (tester) async {
      final repo = await open(
        tester,
        _offer(),
        rules: const CardSalesRules(enabled: true),
      );

      await tester.tap(find.text('COMPRAR POR \$0.25'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿CÓMO QUIERES PAGAR?'), findsNothing);
      expect(repo.cardPurchases, ['o1']);
    });

    testWidgets('falta el comprobante: lo dice, y "Subir comprobante" retoma la misma referencia', (tester) async {
      final repo = await open(tester, _offer(purchase: _purchase('pending')));

      expect(find.text('FALTA TU COMPROBANTE'), findsOneWidget);
      expect(find.textContaining('TJ-ABC234'), findsWidgets);
      expect(find.text('COMPRAR POR \$0.25'), findsNothing);

      await tester.tap(find.text('SUBIR COMPROBANTE'));
      await tester.pumpAndSettle();

      expect(repo.transfers, isEmpty); // no se crea otra compra
      expect(find.text('PAGAR POR TRANSFERENCIA'), findsOneWidget);
      expect(find.text('TJ-ABC234'), findsOneWidget);
      expect(find.text('2200112233'), findsOneWidget);
    });

    testWidgets('en revisión: lo explica y no deja comprar otra vez, aunque se haya agotado', (tester) async {
      await open(tester, _offer(purchase: _purchase('in_review'), stockLeft: 0));

      expect(find.text('ESTAMOS REVISANDO TU COMPROBANTE'), findsOneWidget);
      expect(find.text('AGOTADA'), findsNothing);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'COMPROBANTE EN REVISIÓN'));
      expect(button.onPressed, isNull);
    });

    testWidgets('rechazado: muestra el motivo y deja intentar de nuevo', (tester) async {
      final repo = await open(tester, _offer(purchase: _purchase('rejected', reviewNote: 'El monto no coincide')));

      expect(find.text('NO PUDIMOS ACEPTAR TU COMPROBANTE'), findsOneWidget);
      expect(find.text('El monto no coincide'), findsOneWidget);
      await tester.tap(find.text('INTENTAR DE NUEVO'));
      await tester.pumpAndSettle();

      expect(repo.transfers, ['o1']);
    });

    testWidgets('con la tarjeta ya comprada no se muestra ninguna compra en curso', (tester) async {
      await open(
        tester,
        _offer(
          purchase: _purchase('rejected', reviewNote: 'antiguo'),
          claim: const CampaignClaim(id: 'cl1', code: 'GFT-ABC234', isRedeemed: false, isRoutePrize: false, isPurchase: true),
        ),
      );

      expect(find.text('NO PUDIMOS ACEPTAR TU COMPROBANTE'), findsNothing);
      expect(find.text('YA LA TIENES: VER MIS REGALOS'), findsOneWidget);
    });
  });

  group('CardTransferScreen', () {
    late _FakeSales repo;
    bool? popped;

    Future<void> open(WidgetTester tester, {Locale locale = const Locale('es'), Future<PickedImage?> Function()? pick}) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeSales();
      popped = null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => CardTransferScreen(
                            offer: _offer(),
                            start: TransferStart(
                              purchaseId: 'p1',
                              reference: 'TJ-ABC234',
                              amountCents: 25,
                              reservedUntil: DateTime.now().add(const Duration(hours: 3)),
                              bankAccounts: const [_bank],
                            ),
                            pickImage: pick ?? () async => _picked,
                          ),
                        ),
                      );
                    },
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el monto, la referencia, las cuentas y hasta cuándo se guarda la tarjeta', (tester) async {
      await open(tester);

      expect(find.text('PAGAR POR TRANSFERENCIA'), findsOneWidget);
      expect(find.text('\$0.25'), findsOneWidget);
      expect(find.text('TJ-ABC234'), findsOneWidget);
      expect(find.text('TRANSFIERE A ESTA CUENTA'), findsOneWidget);
      expect(find.text('2200112233'), findsOneWidget);
      expect(find.text('BANCO PICHINCHA'), findsOneWidget);
      expect(find.textContaining('Guardamos tu tarjeta hasta las'), findsOneWidget);
      expect(find.text('ENVIAR COMPROBANTE'), findsOneWidget);
    });

    testWidgets('copiar la referencia la pone en el portapapeles', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester);

      await tester.tap(find.byTooltip('Copiar referencia'));
      await tester.pump();

      expect(copied, 'TJ-ABC234');
      expect(find.text('Referencia copiada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sin la foto no se envía', (tester) async {
      await open(tester);

      await tester.tap(find.text('ENVIAR COMPROBANTE'));
      await tester.pump();

      expect(find.text('Adjunta la foto del comprobante de la transferencia.'), findsOneWidget);
      expect(repo.proofs, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('con la foto y la nota los envía, avisa que lo revisarán y cierra con "true"', (tester) async {
      await open(tester);

      await tester.tap(find.text('HAZ CLIC AQUÍ PARA SUBIR LA FOTO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Transferencia 123');
      await tester.tap(find.text('ENVIAR COMPROBANTE'));
      await tester.pumpAndSettle();

      expect(repo.proofs, [('p1', _picked.dataUri, 'Transferencia 123')]);
      expect(find.text('COMPROBANTE ENVIADO'), findsOneWidget);
      expect(find.textContaining('te avisaremos apenas lo aprobemos'), findsOneWidget);

      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });

    testWidgets('si el servidor lo rechaza (p. ej. la reserva venció), muestra el motivo y se queda', (tester) async {
      await open(tester);
      repo.failWith = Exception('La reserva de esta tarjeta venció. Empieza de nuevo.');

      await tester.tap(find.text('HAZ CLIC AQUÍ PARA SUBIR LA FOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR COMPROBANTE'));
      await tester.pumpAndSettle();

      expect(find.text('La reserva de esta tarjeta venció. Empieza de nuevo.'), findsOneWidget);
      expect(popped, isNull);
      expect(find.text('PAGAR POR TRANSFERENCIA'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('en inglés sale traducida', (tester) async {
      await open(tester, locale: const Locale('en'));

      expect(find.text('PAY BY TRANSFER'), findsOneWidget);
      expect(find.text('AMOUNT TO TRANSFER'), findsOneWidget);
      expect(find.text('TRANSFER TO THIS ACCOUNT'), findsOneWidget);
      expect(find.text('SEND RECEIPT'), findsOneWidget);
      expect(find.textContaining('We are holding your card until'), findsOneWidget);
    });
  });

  group('AdminCardReviewsScreen', () {
    Future<_FakeSales> open(WidgetTester tester, List<CardReview> reviews) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeSales()..reviewsValue = reviews;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardSalesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const AdminCardReviewsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('sin comprobantes dice que todo está al día', (tester) async {
      await open(tester, []);

      expect(find.text('TODO AL DÍA'), findsOneWidget);
    });

    testWidgets('lista cada comprobante con su monto, referencia, cliente, nota y foto', (tester) async {
      await open(tester, [_review()]);

      expect(find.text('COMPROBANTES DE TARJETAS'), findsOneWidget);
      expect(find.text('CAFÉ DE \$1'), findsOneWidget);
      expect(find.text('\$0.25'), findsOneWidget);
      expect(find.text('TJ-ABC234'), findsOneWidget);
      expect(find.text('Luis Mora · luis@test.com'), findsOneWidget);
      expect(find.text('Transferencia 987654'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('APROBAR'), findsOneWidget);
      expect(find.text('RECHAZAR'), findsOneWidget);
    });

    testWidgets('aprobar pide confirmar y entrega', (tester) async {
      final repo = await open(tester, [_review()]);

      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Ya viste en tu banco la transferencia de \$0.25'), findsOneWidget);
      expect(repo.approved, isEmpty);

      await tester.tap(find.text('SÍ, APROBAR'));
      await tester.pumpAndSettle();

      expect(repo.approved, ['r1']);
      expect(find.text('Comprobante aprobado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('cancelar la confirmación no aprueba nada', (tester) async {
      final repo = await open(tester, [_review()]);

      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(repo.approved, isEmpty);
    });

    testWidgets('rechazar exige el motivo', (tester) async {
      final repo = await open(tester, [_review()]);

      await tester.tap(find.text('RECHAZAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RECHAZAR COMPROBANTE'));
      await tester.pump();

      expect(find.text('Escribe el motivo para que el cliente sepa qué corregir'), findsOneWidget);
      expect(repo.rejected, isEmpty);
    });

    testWidgets('rechazar con un motivo escrito lo envía', (tester) async {
      final repo = await open(tester, [_review()]);

      await tester.tap(find.text('RECHAZAR'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Falta la referencia  ');
      await tester.tap(find.text('RECHAZAR COMPROBANTE'));
      await tester.pumpAndSettle();

      expect(repo.rejected, [('r1', 'Falta la referencia')]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un motivo común se pone con un toque', (tester) async {
      final repo = await open(tester, [_review()]);

      await tester.tap(find.text('RECHAZAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('El monto no coincide'));
      await tester.pump();
      await tester.tap(find.text('RECHAZAR COMPROBANTE'));
      await tester.pumpAndSettle();

      expect(repo.rejected, [('r1', 'El monto no coincide')]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('si otro administrador ya lo revisó, avisa y la lista se actualiza', (tester) async {
      final repo = await open(tester, [_review()]);
      repo.failWith = Exception('Este comprobante ya fue revisado');

      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SÍ, APROBAR'));
      await tester.pumpAndSettle();

      expect(find.text('Este comprobante ya fue revisado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
