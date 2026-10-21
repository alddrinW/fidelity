import 'package:fidelity_app/features/admin/widgets/admin_widgets.dart';
import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/gift_card_form_screen.dart';
import 'package:fidelity_app/features/campaigns/gift_card_manage_screen.dart';
import 'package:fidelity_app/features/campaigns/gift_cards_tab.dart';
import 'package:fidelity_app/features/campaigns/widgets/customer_picker_sheet.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Datos de prueba en lugar de la red.
class _FakeCampaignsRepository extends CampaignsRepository {
  List<Campaign> campaigns = [];
  List<IssuedClaim> issued = [];
  List<CampaignCustomer> customerList = [];

  final List<Map<String, Object?>> created = [];
  final List<Map<String, Object?>> updates = [];
  final List<String> cancelled = [];
  final List<String?> customerQueries = [];

  @override
  Future<List<Campaign>> mine() async => campaigns;

  @override
  Future<List<IssuedClaim>> claims(String campaignId) async => issued;

  @override
  Future<List<CampaignCustomer>> customers(List<String> businessIds, {String? query}) async {
    customerQueries.add(query);
    final q = (query ?? '').trim().toLowerCase();
    return customerList
        .where((c) => q.isEmpty || '${c.fullName} ${c.email}'.toLowerCase().contains(q))
        .toList();
  }

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
      'audience': audience,
      'recipientIds': recipientIds,
    });
    return campaigns.isNotEmpty ? campaigns.first : _gift();
  }

  @override
  Future<Campaign> update(
    String campaignId, {
    String? title,
    String? description,
    int? benefitValue,
    String? benefitLabel,
    DateTime? endsAt,
    String? imageDataUri,
  }) async {
    updates.add({
      'title': title,
      'description': description,
      'benefitValue': benefitValue,
      'benefitLabel': benefitLabel,
      'endsAt': endsAt,
      'imageDataUri': imageDataUri,
    });
    return _gift(
      title: title ?? 'Regalo de aniversario',
      benefitValue: benefitValue ?? 20,
      benefitLabel: benefitLabel ?? (benefitValue != null ? '$benefitValue% de descuento' : '20% de descuento'),
    );
  }

  @override
  Future<void> cancel(String campaignId) async => cancelled.add(campaignId);
}

Campaign _gift({
  String id = 'g1',
  String title = 'Regalo de aniversario',
  int benefitValue = 20,
  String benefitLabel = '20% de descuento',
  CampaignBenefit benefit = CampaignBenefit.discountPercent,
  CampaignAudience audience = CampaignAudience.all,
  CampaignPhase phase = CampaignPhase.active,
  CampaignStats? stats = const CampaignStats(claims: 5, redeemed: 2, recipients: 0),
}) =>
    Campaign(
      id: id,
      type: CampaignType.giftCard,
      title: title,
      phase: phase,
      benefitType: benefit,
      benefitValue: benefit == CampaignBenefit.discountPercent ? benefitValue : null,
      benefitLabel: benefitLabel,
      audience: audience,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
      stats: stats,
    );

Campaign _event() => const Campaign(
      id: 'e1',
      type: CampaignType.event,
      title: 'Noche de música',
      phase: CampaignPhase.active,
      businesses: [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
      stats: CampaignStats(),
    );

const _ana = CampaignCustomer(id: 'u1', fullName: 'Ana Paz', email: 'ana@mail.com');
const _luis = CampaignCustomer(id: 'u2', fullName: 'Luis Mora', email: 'luis@mail.com');

Finder _pill(String label) =>
    find.byWidgetPredicate((w) => w is AdminFilterPill && w.label == label);

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('modelos', () {
    test('una campaña lee su audiencia y los clientes elegidos', () {
      final c = Campaign.fromJson({
        'id': 'g1',
        'type': 'gift_card',
        'title': 'Solo para ti',
        'phase': 'active',
        'audience': 'selected',
        'stats': {'claims': 3, 'redeemed': 1, 'participants': 0, 'recipients': 3},
        'businesses': [],
      });

      expect(c.audience, CampaignAudience.selected);
      expect(c.stats?.recipients, 3);
    });

    test('sin audiencia se asume que llega a todos', () {
      expect(CampaignAudience.parse(null), CampaignAudience.all);
      expect(CampaignAudience.parse('all'), CampaignAudience.all);
      expect(CampaignAudience.parse('otra'), CampaignAudience.all);
    });

    test('un cliente sin nombre se muestra por su correo', () {
      expect(const CampaignCustomer(id: '1', email: 'x@mail.com').displayName, 'x@mail.com');
      expect(_ana.displayName, 'Ana Paz');
    });

    test('el código del cliente se normaliza a mayúsculas', () {
      expect(normalizeGiftCode('  gft-abc234  '), 'GFT-ABC234');
      expect(normalizeGiftCode('otra cosa'), 'OTRA COSA');
    });
  });

  group('GiftCardsTab', () {
    Future<_FakeCampaignsRepository> open(WidgetTester tester, List<Campaign> campaigns) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeCampaignsRepository()..campaigns = campaigns;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [campaignsRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const Scaffold(body: GiftCardsTab())),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('lista solo las gift cards (no eventos ni rutas)', (tester) async {
      await open(tester, [_gift(), _event()]);

      expect(find.text('REGALO DE ANIVERSARIO'), findsOneWidget);
      expect(find.text('NOCHE DE MÚSICA'), findsNothing);
    });

    testWidgets('muestra cuántas se enviaron y canjearon', (tester) async {
      await open(tester, [_gift(stats: const CampaignStats(claims: 5, redeemed: 2))]);

      expect(find.text('ENVIADAS'), findsOneWidget);
      expect(find.text('CANJEADAS'), findsOneWidget);
      expect(find.text('SIN CANJEAR'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 5 enviadas - 2 canjeadas
    });

    testWidgets('indica a quién le llega', (tester) async {
      await open(tester, [
        _gift(id: 'a', title: 'Para todos'),
        _gift(
          id: 'b',
          title: 'Para unos',
          audience: CampaignAudience.selected,
          stats: const CampaignStats(claims: 2, recipients: 2),
        ),
      ]);

      expect(find.textContaining('Todos mis clientes'), findsOneWidget);
      expect(find.textContaining('2 clientes elegidos'), findsOneWidget);
    });

    testWidgets('ofrece crear una gift card y canjear con el código de letras',
        (tester) async {
      await open(tester, [_gift()]);

      expect(find.text('NUEVA GIFT CARD'), findsOneWidget);
      expect(find.text('CANJEAR CÓDIGO'), findsOneWidget);
      // Ya no se escanea el QR: el local escribe el código.
      expect(find.text('ESCANEAR QR'), findsNothing);
    });

    testWidgets('sin gift cards muestra el estado vacío', (tester) async {
      await open(tester, [_event()]);

      expect(find.text('SIN GIFT CARDS'), findsOneWidget);
    });
  });

  group('GiftCardFormScreen', () {
    Future<_FakeCampaignsRepository> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeCampaignsRepository()..customerList = [_ana, _luis];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campaignsRepositoryProvider.overrideWithValue(repo),
            businessOverviewProvider.overrideWith(
              (ref) async => const [BusinessOverview(id: 'b1', name: 'Café Aurora', isActive: true)],
            ),
          ],
          child: spanishApp(const GiftCardFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> typeTitle(WidgetTester tester, String text) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre (ej. Regalo de aniversario)'), text);
    }

    testWidgets('muestra la plantilla del cheque y se actualiza al escribir', (tester) async {
      await open(tester);

      // La vista previa del cheque, con el nombre de ejemplo.
      expect(find.text('ASÍ SE VERÁ EL CHEQUE'), findsOneWidget);
      expect(find.text('TU GIFT CARD'), findsOneWidget);
      expect(find.byType(GiftCardVoucher), findsOneWidget);

      await typeTitle(tester, 'Regalo de aniversario');
      await tester.pumpAndSettle();

      // El cheque ya muestra el nombre que se escribió.
      expect(find.text('REGALO DE ANIVERSARIO'), findsOneWidget);
    });

    testWidgets('el beneficio se elige entre descuento y mini premio', (tester) async {
      await open(tester);

      // Las dos opciones siguen disponibles.
      expect(find.text('DESCUENTO'), findsOneWidget);
      expect(find.text('MINI PREMIO'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Porcentaje de descuento'), findsOneWidget);

      await tester.tap(find.text('MINI PREMIO'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Porcentaje de descuento'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Mini premio (ej. Café pequeño gratis)'), findsOneWidget);
    });

    testWidgets('se elige a quién le llega', (tester) async {
      await open(tester);

      expect(find.text('¿A QUIÉN LE LLEGA?'), findsOneWidget);
      expect(find.text('TODOS MIS CLIENTES'), findsOneWidget);
      expect(find.text('CLIENTES ELEGIDOS'), findsOneWidget);
    });

    testWidgets('con un solo negocio activo ya viene elegido y llega a todos por defecto', (tester) async {
      final repo = await open(tester);

      await typeTitle(tester, 'Regalo de aniversario');
      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pumpAndSettle();

      expect(repo.created, hasLength(1));
      final args = repo.created.single;
      expect(args['type'], CampaignType.giftCard);
      expect(args['title'], 'Regalo de aniversario');
      expect(args['businessIds'], ['b1']);
      expect(args['benefitType'], CampaignBenefit.discountPercent);
      expect(args['benefitValue'], 10);
      expect(args['audience'], CampaignAudience.all);
      expect(args['recipientIds'], isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un mini premio se envía con su descripción', (tester) async {
      final repo = await open(tester);

      await typeTitle(tester, 'Café de cortesía');
      await tester.tap(_pill('Mini premio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Mini premio (ej. Café pequeño gratis)'), 'Café pequeño');
      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pumpAndSettle();

      final args = repo.created.single;
      expect(args['benefitType'], CampaignBenefit.miniPrize);
      expect(args['benefitLabel'], 'Café pequeño');
      expect(args['benefitValue'], isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el nombre es obligatorio', (tester) async {
      final repo = await open(tester);

      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre debe tener al menos 3 caracteres'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('elegir clientes sin elegir ninguno no deja enviar', (tester) async {
      final repo = await open(tester);

      await typeTitle(tester, 'Solo para ti');
      await tester.tap(_pill('Clientes elegidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pump();

      expect(find.text('Elige al menos un cliente.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('elige clientes en la hoja y se envía solo a ellos', (tester) async {
      final repo = await open(tester);

      await typeTitle(tester, 'Solo para ti');
      await tester.tap(_pill('Clientes elegidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ELEGIR CLIENTES'));
      await tester.pumpAndSettle();

      expect(find.text('ELIGE A TUS CLIENTES'), findsOneWidget);
      await tester.tap(find.text('Ana Paz'));
      await tester.tap(find.text('Luis Mora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO (2)'));
      await tester.pumpAndSettle();

      expect(find.text('2 CLIENTES ELEGIDOS'), findsOneWidget);

      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pumpAndSettle();

      final args = repo.created.single;
      expect(args['audience'], CampaignAudience.selected);
      expect((args['recipientIds'] as List).toSet(), {'u1', 'u2'});
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('al programar exige elegir la fecha', (tester) async {
      final repo = await open(tester);

      await typeTitle(tester, 'Programada');
      // "Programar" abre el selector de fecha del sistema; se cierra sin elegir.
      await tester.tap(_pill('Programar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4)); // toca fuera del diálogo
      await tester.pumpAndSettle();
      await tester.tap(find.text('PROGRAMAR').last);
      await tester.pump();

      expect(find.text('Elige cuándo empieza la gift card.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });
  });

  group('CustomerPicker', () {
    Future<_FakeCampaignsRepository> open(
      WidgetTester tester, {
      Set<String> initial = const {},
      void Function(Set<String>?)? onResult,
    }) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeCampaignsRepository()..customerList = [_ana, _luis];
      await tester.pumpWidget(
        spanishApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final picked = await showCustomerPicker(
                  context,
                  repository: repo,
                  businessIds: const ['b1'],
                  initial: initial,
                );
                onResult?.call(picked);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('muestra los clientes y respeta los ya elegidos', (tester) async {
      await open(tester, initial: {'u1'});

      expect(find.text('Ana Paz'), findsOneWidget);
      expect(find.text('ana@mail.com'), findsOneWidget);
      expect(find.text('LISTO (1)'), findsOneWidget);
    });

    testWidgets('busca por nombre o correo', (tester) async {
      final repo = await open(tester);

      await tester.enterText(find.byType(TextFormField), 'luis');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.customerQueries.last, 'luis');
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(find.text('Ana Paz'), findsNothing);
    });

    testWidgets('elegir y quitar a todos', (tester) async {
      await open(tester);

      await tester.tap(find.text('ELEGIR A TODOS'));
      await tester.pumpAndSettle();
      expect(find.text('LISTO (2)'), findsOneWidget);

      await tester.tap(find.text('QUITAR A TODOS'));
      await tester.pumpAndSettle();
      expect(find.text('LISTO'), findsOneWidget);
    });

    testWidgets('devuelve los ids elegidos', (tester) async {
      Set<String>? result;
      await open(tester, onResult: (r) => result = r);

      await tester.tap(find.text('Luis Mora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO (1)'));
      await tester.pumpAndSettle();

      expect(result, {'u2'});
    });

    testWidgets('sin clientes lo explica', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeCampaignsRepository();
      await tester.pumpWidget(
        spanishApp(
          Scaffold(
            body: CustomerPicker(repository: repo, businessIds: const ['b1']),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no tienes clientes en este negocio.'), findsOneWidget);
    });
  });

  group('GiftCardManageScreen', () {
    final issued = [
      const IssuedClaim(code: 'GFT-AAAAAA', isRedeemed: false, isRoutePrize: false, userName: 'Ana Paz'),
      const IssuedClaim(code: 'GFT-BBBBBB', isRedeemed: true, isRoutePrize: false, userEmail: 'luis@mail.com'),
    ];

    Future<_FakeCampaignsRepository> open(WidgetTester tester, Campaign campaign) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeCampaignsRepository()..issued = issued;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [campaignsRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(GiftCardManageScreen(campaign: campaign)),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('muestra la gift card, sus cifras y lo que recibió cada cliente', (tester) async {
      await open(tester, _gift());

      // El nombre sale en el encabezado y en el cheque.
      expect(find.text('REGALO DE ANIVERSARIO'), findsNWidgets(2));
      expect(find.text('20% DE DESCUENTO'), findsOneWidget);
      expect(find.text('GFT-AAAAAA'), findsOneWidget);
      expect(find.text('Ana Paz'), findsOneWidget);
      expect(find.text('GFT-BBBBBB'), findsOneWidget);
      expect(find.text('luis@mail.com'), findsOneWidget);
      // 2 enviadas, 1 canjeada, 1 sin canjear
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tocar una gift card muestra su código y el cheque', (tester) async {
      await open(tester, _gift());

      await tester.tap(find.text('GFT-AAAAAA'));
      await tester.pumpAndSettle();

      expect(find.byType(GiftCardCodeDialog), findsOneWidget);
      // El cheque de la pantalla y el del diálogo.
      expect(find.byType(GiftCardVoucher), findsNWidgets(2));
      // Ya no hay QR: solo el código de letras.
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('REGALO DE ANIVERSARIO'), findsWidgets);
    });

    testWidgets('editar el descuento envía solo lo que cambió', (tester) async {
      final repo = await open(tester, _gift());

      await tester.tap(find.text('EDITAR GIFT CARD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '20'), '35');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      expect(repo.updates, hasLength(1));
      expect(repo.updates.single['benefitValue'], 35);
      expect(repo.updates.single['title'], isNull);
      expect(repo.updates.single['benefitLabel'], isNull);
      expect(find.text('35% DE DESCUENTO'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un mini premio se edita con su descripción', (tester) async {
      final repo = await open(
        tester,
        _gift(benefit: CampaignBenefit.miniPrize, benefitLabel: 'Café pequeño'),
      );

      await tester.tap(find.text('EDITAR GIFT CARD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Café pequeño'), 'Café grande');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      expect(repo.updates.single['benefitLabel'], 'Café grande');
      expect(repo.updates.single['benefitValue'], isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un descuento fuera de rango no se guarda', (tester) async {
      final repo = await open(tester, _gift());

      await tester.tap(find.text('EDITAR GIFT CARD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '20'), '150');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      expect(find.text('Entre 1 y 100'), findsOneWidget);
      expect(repo.updates, isEmpty);
    });

    testWidgets('cancelar pide confirmación y avisa que los clientes lo sabrán', (tester) async {
      final repo = await open(tester, _gift());

      await tester.tap(find.text('CANCELAR GIFT CARD'));
      await tester.pumpAndSettle();
      expect(find.text('¿CANCELAR GIFT CARD?'), findsOneWidget);
      expect(find.text('Tus clientes dejarán de poder canjearla y recibirán un aviso.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'CANCELAR GIFT CARD'));
      await tester.pumpAndSettle();

      expect(repo.cancelled, ['g1']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('una gift card cancelada ya no se edita ni se cancela', (tester) async {
      await open(tester, _gift(phase: CampaignPhase.cancelled));

      expect(find.text('EDITAR GIFT CARD'), findsNothing);
      expect(find.text('CANCELAR GIFT CARD'), findsNothing);
    });

    testWidgets('una programada explica que se enviará a la hora', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeCampaignsRepository(); // sin emitidas todavía
      await tester.pumpWidget(
        ProviderScope(
          overrides: [campaignsRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(
            GiftCardManageScreen(campaign: _gift(phase: CampaignPhase.scheduled, stats: const CampaignStats())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Se enviarán a tus clientes cuando llegue la hora.'), findsOneWidget);
    });
  });
}
