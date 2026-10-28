import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/business/data/business_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/gift_card_form_screen.dart';
import 'package:fidelity_app/features/campaigns/my_gifts_screen.dart';
import 'package:fidelity_app/features/cards/customer_shell_screen.dart';
import 'package:fidelity_app/features/cards/providers/my_cards_provider.dart';
import 'package:fidelity_app/features/notifications/data/notifications_repository.dart';
import 'package:fidelity_app/features/notifications/notifications_screen.dart';
import 'package:fidelity_app/features/profile/providers/user_profile_provider.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// El "backend" de la prueba: guarda las gift cards, los regalos que se
/// emiten a cada cliente y los avisos de la bandeja. Así se puede probar el
/// flujo entero (el local crea la gift card y el cliente la recibe) sin red.
class _FakeBackend {
  final List<Campaign> campaigns = [];
  final List<CampaignClaim> claims = [];
  final List<AppNotification> notifications = [];
  final List<Map<String, Object?>> created = [];

  int get unread => notifications.where((n) => !n.read).length;

  /// Lo que hace el backend al crear una gift card: la guarda, le entrega un
  /// regalo con su código a cada cliente y le deja un aviso en la bandeja.
  Campaign createGiftCard({
    required String title,
    required int benefitValue,
    String benefitLabel = '20% de descuento',
  }) {
    final campaign = Campaign(
      id: 'g${campaigns.length + 1}',
      type: CampaignType.giftCard,
      title: title,
      phase: CampaignPhase.active,
      benefitType: CampaignBenefit.discountPercent,
      benefitValue: benefitValue,
      benefitLabel: benefitLabel,
      businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
    );
    campaigns.add(campaign);
    claims.add(CampaignClaim(
      id: 'cl${claims.length + 1}',
      code: 'GFT-${claims.length + 1}ABCDE',
      isRedeemed: false,
      isRoutePrize: false,
      createdAt: DateTime.now(),
      campaign: campaign,
    ));
    notifications.add(AppNotification(
      id: 'n${notifications.length + 1}',
      type: 'gift_card',
      title: 'Café Aurora te regaló una gift card',
      body: '$benefitLabel. Ábrela en Mis regalos y muestra su código.',
      createdAt: DateTime.now(),
      data: {
        'type': 'gift_card',
        'route': '/my_gifts',
        'campaign_id': campaign.id
      },
    ));
    return campaign;
  }
}

class _FakeCampaignsRepository extends CampaignsRepository {
  _FakeCampaignsRepository(this.backend);
  final _FakeBackend backend;

  @override
  Future<List<Campaign>> mine() async => backend.campaigns;

  @override
  Future<List<Campaign>> feed() async => backend.campaigns;

  @override
  Future<List<CampaignClaim>> myClaims() async => backend.claims;

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
    backend.created.add({
      'type': type,
      'title': title,
      'audience': audience,
      'recipientIds': recipientIds,
    });
    return backend.createGiftCard(
      title: title,
      benefitValue: benefitValue ?? 20,
      benefitLabel: benefitLabel ?? '${benefitValue ?? 20}% de descuento',
    );
  }
}

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository(this.backend);
  final _FakeBackend backend;

  @override
  Future<List<AppNotification>> list(
          {DateTime? before, int limit = 30}) async =>
      backend.notifications;

  @override
  Future<int> unreadCount() async => backend.unread;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}

/// El cliente ya tiene una tarjeta en el local.
class _FakeCards extends MyCardsNotifier {
  _FakeCards(this.cardsState);
  final MyCardsState cardsState;

  @override
  MyCardsState build() => cardsState;
}

/// El perfil del cliente, sin red.
class _FakeProfile extends UserProfileNotifier {
  @override
  UserProfileState build() => UserProfileState(
        isLoading: false,
        fullName: 'juan diego',
        phone: '0999994555',
        email: 'juan@uide.edu.ec',
      );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Flujo de una gift card', () {
    late _FakeBackend backend;
    late ProviderContainer container;

    final cardState = MyCardsState(
      isLoading: false,
      userName: 'juan diego',
      cards: [
        {
          'id': 'c1',
          'current_points': 3,
          'pending_scans': 0,
          'rewards': const [],
          'businesses': {
            'id': 'b1',
            'name': 'Café Aurora',
            'points_required': 10,
            'reward_description': 'Café gratis',
            'logo_url': null,
            'business_categories': {'name': 'Cafeterías'},
          },
        },
      ],
    );

    Future<void> show(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: spanishApp(child),
        ),
      );
      // El inicio del cliente tiene un carrusel que no deja de moverse: no se espera a que "se quede quieto".
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    /// El formulario se abre encima de otra pantalla (como en la app), porque
    /// al enviar se cierra con `pop`.
    Future<void> showForm(WidgetTester tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GiftCardFormScreen()),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      backend = _FakeBackend();
      container = ProviderContainer(
        overrides: [
          campaignsRepositoryProvider
              .overrideWithValue(_FakeCampaignsRepository(backend)),
          notificationsRepositoryProvider
              .overrideWithValue(_FakeNotificationsRepository(backend)),
          businessOverviewProvider.overrideWith(
            (ref) async => const [
              BusinessOverview(id: 'b1', name: 'Café Aurora', isActive: true),
            ],
          ),
          businessesDirectoryProvider.overrideWith((ref) async => const []),
          myCardsProvider.overrideWith(() => _FakeCards(cardState)),
          userProfileProvider.overrideWith(() => _FakeProfile()),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets(
        'el local la crea, el cliente recibe el aviso, el regalo y su QR',
        (tester) async {
      // 1. El dueño la crea desde el formulario.
      await showForm(tester);
      await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Nombre de la gift card (ej. Regalo de aniversario)'),
        'Regalo de aniversario',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR GIFT CARD'));
      await tester.pumpAndSettle();

      expect(backend.created.single['type'], CampaignType.giftCard);
      expect(backend.created.single['title'], 'Regalo de aniversario');
      expect(backend.created.single['audience'], CampaignAudience.all);

      // El backend le entregó un regalo con su código y le dejó el aviso.
      expect(backend.claims.single.code, startsWith('GFT-'));
      expect(backend.notifications.single.type, 'gift_card');
      expect(backend.notifications.single.data['route'], '/my_gifts');

      // 2. El panel del cliente muestra la campana con el pendiente y la
      //    pestaña de regalos.
      await show(tester, const CustomerShellScreen());
      expect(find.text('REGALOS'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // el contador de la campana

      // El botón de escanear es rosa y sin borde negro.
      final scan = tester.widget<Material>(
        find.ancestor(of: find.byIcon(Icons.qr_code_scanner_rounded), matching: find.byType(Material)).first,
      );
      expect(scan.shape, const CircleBorder());

      // 3. La bandeja del cliente lista el aviso.
      await show(tester, const NotificationsScreen());
      expect(find.text('Café Aurora te regaló una gift card'), findsOneWidget);
      expect(find.textContaining('Ábrela en Mis regalos'), findsOneWidget);

      // 4. "Mis regalos" muestra el cheque de la gift card con su código, y al
      //    tocarlo se abre el detalle (ya no hay QR: solo el código de letras).
      await show(tester, const MyGiftsView());
      expect(find.text('REGALO DE ANIVERSARIO'), findsOneWidget);
      // Se ve igual que lo entrega el local: el cheque, con el beneficio y el código.
      expect(find.byType(GiftCardVoucher), findsOneWidget);
      expect(find.textContaining('DE DESCUENTO'), findsOneWidget);
      expect(find.text(backend.claims.single.code), findsOneWidget);

      await tester.tap(find.text('REGALO DE ANIVERSARIO'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(backend.claims.single.code), findsOneWidget);
      expect(find.textContaining('para canjearlo'), findsOneWidget);
    });
  });
}
