import 'package:fidelity_app/core/widgets/app_card.dart';
import 'package:fidelity_app/core/widgets/fido_mascot.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/cards/card_history_screen.dart';
import 'package:fidelity_app/features/cards/providers/card_history_provider.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_claim_tile.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:fidelity_app/features/games/widgets/game_invite_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

/// El historial con datos de una tarjeta.
class _FakeHistory extends CardHistoryNotifier {
  _FakeHistory({
    this.points = 3,
    this.required = 10,
    this.reward = 'hiernalife 20% de descuento',
    this.loading = false,
    this.withInfo = true,
    this.rewardCount = 1,
    this.withRewards = true,
  });

  final int points;
  final int required;
  final String reward;
  final bool loading;
  final bool withInfo;
  final int rewardCount;
  final bool withRewards;

  // Sin red: los datos ya vienen puestos.
  @override
  void init(String cardId, String businessId) {}

  @override
  Future<void> loadHistory() async {}

  @override
  CardHistoryState build() => CardHistoryState(
        isLoading: loading,
        card: loading
            ? const {}
            : {
                'name': 'Vilcanatu',
                'category': withInfo ? 'Servicios' : null,
                'address': withInfo ? 'Av. Amazonas N31, Quito' : null,
                'reward_description': reward,
                'current_points': points,
                'total_points': 5,
                'rewards_claimed': 1,
                'points_required': required,
                'last_scan_at': '2026-10-19T15:27:16.832Z',
              },
        rewards: withRewards
            ? [
                for (var i = 0; i < rewardCount; i++)
                  {
                    'id': 'r$i',
                    'status': 'approved',
                    'earned_at': '2026-10-19T15:27:16.832Z',
                    'businesses': {'reward_description': 'Café gratis'},
                  },
              ]
            : const [],
      );
}

/// Un regalo del local [businessId] (o de otro).
CampaignClaim claim(String code, String title, {String businessId = 'b1', bool redeemed = false}) => CampaignClaim(
      id: code,
      code: code,
      isRedeemed: redeemed,
      isRoutePrize: false,
      campaign: Campaign(
        id: 'camp-$code',
        type: CampaignType.giftCard,
        title: title,
        phase: CampaignPhase.active,
        benefitType: CampaignBenefit.discountPercent,
        benefitValue: 20,
        benefitLabel: '20% de descuento',
        businesses: [CampaignBusinessRef(id: businessId, name: businessId == 'b1' ? 'Vilcanatu' : 'Otro local')],
      ),
    );

GameInvite invite(String id, String status, {String businessId = 'b1', String game = 'hangman', String? result, int attemptsLeft = 3}) =>
    GameInvite(
      id: id,
      game: GameKey.parse(game),
      gameName: GameKey.parse(game)!.label,
      businessId: businessId,
      businessName: businessId == 'b1' ? 'Vilcanatu' : 'Otro local',
      prizeLabel: '20% de descuento',
      status: status,
      result: result,
      attemptsLeft: attemptsLeft,
      startsAt: DateTime(2026, 12, 1, 10),
      expiresAt: DateTime(2026, 12, 8, 10),
    );

Future<void> _open(
  WidgetTester tester,
  _FakeHistory history, {
  int initialTab = 0,
  Size size = const Size(900, 2400),
  List<CampaignClaim> claims = const [],
  List<GameInvite> invites = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      cardHistoryProvider.overrideWith(() => history),
      myClaimsProvider.overrideWith((ref) async => claims),
      myGameInvitesProvider.overrideWith((ref) async => invites),
    ],
    child: spanishApp(
      Scaffold(
        body: CardHistoryScreen(
          loyaltyCardId: 'c1',
          businessId: 'b1',
          businessName: 'Vilcanatu',
          initialTabIndex: initialTab,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Los sellos de la tarjeta: `ganado` o `falta`.
Finder stamp(String state) => find.byWidgetPredicate(
      (w) => w.key is ValueKey && (w.key as ValueKey).value.toString().endsWith('-$state'),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('la cabecera del local', () {
    testWidgets('muestra el logo, el nombre, dónde queda, los sellos y el premio', (tester) async {
      await _open(tester, _FakeHistory());

      expect(find.text('VILCANATU'), findsOneWidget);
      expect(find.text('Servicios · Av. Amazonas N31, Quito'), findsOneWidget);
      expect(find.text('TUS SELLOS'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);
      // El premio ya no lleva una franja aparte: va en el mensaje de los sellos.
      expect(find.text('TU PREMIO'), findsNothing);
      expect(find.text('Te faltan 7 puntos para: hiernalife 20% de descuento'), findsOneWidget);
      // Sin logo cargado se ve el ícono de tienda.
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });

    testWidgets('la cabecera va centrada y sin franja de color: logo, nombre y dirección en el medio', (tester) async {
      await _open(tester, _FakeHistory());

      const screenCenter = 450.0; // la pantalla de la prueba mide 900 de ancho
      expect(tester.getCenter(find.byIcon(Icons.storefront_outlined)).dx, closeTo(screenCenter, 1));
      expect(tester.getCenter(find.text('VILCANATU')).dx, closeTo(screenCenter, 1));
      expect(tester.getCenter(find.text('Servicios · Av. Amazonas N31, Quito')).dx, closeTo(screenCenter, 1));
      // Volver a la izquierda y filtrar a la derecha, a la altura del logo.
      final back = tester.getCenter(find.byTooltip('Volver')).dx;
      final filter = tester.getCenter(find.byTooltip('Filtrar por fechas')).dx;
      expect(back, lessThan(screenCenter - 100));
      expect(filter, greaterThan(screenCenter + 100));
      // Los dos botones quedan a la misma distancia del logo.
      expect(screenCenter - back, closeTo(filter - screenCenter, 20));
      expect(tester.getCenter(find.byTooltip('Volver')).dy, closeTo(tester.getCenter(find.byIcon(Icons.storefront_outlined)).dy, 4));
    });

    testWidgets('un sello por cada punto: ganados, por ganar y el premio al final', (tester) async {
      await _open(tester, _FakeHistory(points: 7, required: 8, withRewards: false));

      expect(stamp('ganado'), findsNWidgets(7));
      expect(stamp('falta'), findsOneWidget);
      expect(find.text('7 / 8'), findsOneWidget);
      expect(find.text('Un punto más y consigues: hiernalife 20% de descuento'), findsOneWidget);
      // El último sello es el regalo.
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    });

    testWidgets('con todos los puntos el premio está listo', (tester) async {
      await _open(tester, _FakeHistory(points: 10, required: 10));

      expect(stamp('ganado'), findsNWidgets(10));
      expect(stamp('falta'), findsNothing);
      expect(find.text('¡Tu premio está listo: hiernalife 20% de descuento!'), findsOneWidget);
    });

    testWidgets('la insignia FidelyUsuario va dentro de la misma tarjeta que los sellos', (tester) async {
      await _open(tester, _FakeHistory());

      final card = find.ancestor(of: find.text('TUS SELLOS'), matching: find.byType(AppCard)).first;
      expect(
        find.descendant(of: card, matching: find.text('Te faltan 3 escaneos para ser FidelyUsuario')),
        findsOneWidget,
      );
    });

    testWidgets('con el premio listo, Fido celebra dentro de la tarjeta', (tester) async {
      await _open(tester, _FakeHistory(points: 10, required: 10));

      expect(
        find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.celebrate),
        findsOneWidget,
      );
    });

    testWidgets('sin el premio listo, Fido no aparece en la tarjeta', (tester) async {
      await _open(tester, _FakeHistory(points: 4, required: 10));

      expect(find.byType(FidoMascot), findsNothing);
    });

    testWidgets('con el premio listo y un local sin premio descrito, el mensaje no lo nombra', (tester) async {
      await _open(tester, _FakeHistory(points: 10, required: 10, reward: ''));

      expect(find.text('¡Tu premio está listo!'), findsOneWidget);
    });

    testWidgets('un premio que pide muchos puntos usa una barra en vez de círculos', (tester) async {
      await _open(tester, _FakeHistory(points: 5, required: 30));

      expect(stamp('ganado'), findsNothing);
      expect(find.text('5 / 30'), findsOneWidget);
    });

    testWidgets('un local sin premio descrito solo dice que falta para "tu premio"', (tester) async {
      await _open(tester, _FakeHistory(reward: ''));

      expect(find.text('TU PREMIO'), findsNothing);
      expect(find.text('Te faltan 7 puntos para tu premio'), findsOneWidget);
    });

    testWidgets('sin dirección ni categoría no deja un hueco', (tester) async {
      await _open(tester, _FakeHistory(withInfo: false));

      expect(find.textContaining('·'), findsNothing);
      expect(find.text('VILCANATU'), findsOneWidget);
    });

    testWidgets('mientras carga se ve el nombre y un indicador, sin sellos', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [cardHistoryProvider.overrideWith(() => _FakeHistory(loading: true))],
        child: spanishApp(
          const Scaffold(
            body: CardHistoryScreen(loyaltyCardId: 'c1', businessId: 'b1', businessName: 'Vilcanatu'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VILCANATU'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('TUS SELLOS'), findsNothing);
    });

    testWidgets('en un celular angosto y con letra grande no se desborda', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cardHistoryProvider.overrideWith(
            () => _FakeHistory(points: 11, required: 12, reward: 'Almuerzo completo con postre y bebida gratis para dos personas'),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(320, 900), textScaler: TextScaler.linear(1.4)),
          child: spanishApp(
            const Scaffold(
              body: CardHistoryScreen(
                loyaltyCardId: 'c1',
                businessId: 'b1',
                businessName: 'Restaurante El Rincón de la Abuela Mercedes',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('TUS SELLOS'), findsOneWidget);
    });
  });

  group('las pestañas', () {
    testWidgets('Premios, Tarjetas y Minijuegos: ya no hay pestaña de escaneos', (tester) async {
      await _open(tester, _FakeHistory());

      expect(find.text('PREMIOS'), findsOneWidget);
      expect(find.text('TARJETAS'), findsOneWidget);
      expect(find.text('MINIJUEGOS'), findsOneWidget);
      expect(find.text('ESCANEOS'), findsNothing);
      // El registro de escaneos se quitó.
      expect(find.text('+1 PUNTO'), findsNothing);
    });

    testWidgets('abre en Premios y muestra los premios del cliente', (tester) async {
      await _open(tester, _FakeHistory());

      expect(find.text('CAFÉ GRATIS'), findsOneWidget);
    });

    testWidgets('sin premios dice que todavía no ganó ninguno', (tester) async {
      await _open(tester, _FakeHistory(withRewards: false));

      expect(find.text('SIN PREMIOS'), findsOneWidget);
    });

    testWidgets('se puede abrir directo en las gift cards', (tester) async {
      await _open(tester, _FakeHistory(), initialTab: CardHistoryScreen.giftCardsTab);

      expect(find.text('SIN GIFT CARDS'), findsOneWidget);
    });

    testWidgets('se puede abrir directo en los minijuegos', (tester) async {
      await _open(tester, _FakeHistory(), initialTab: CardHistoryScreen.gamesTab);

      expect(find.text('SIN MINIJUEGOS'), findsOneWidget);
    });

    testWidgets('las pestañas se quedan fijas al desplazar la lista', (tester) async {
      await _open(tester, _FakeHistory(rewardCount: 14), size: const Size(400, 760));

      final before = tester.getTopLeft(find.text('PREMIOS')).dy;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();

      // La cabecera se fue hacia arriba, pero las pestañas se quedan arriba, visibles.
      final after = tester.getTopLeft(find.text('PREMIOS')).dy;
      expect(after, lessThan(before));
      expect(after, inInclusiveRange(0, 40));
      expect(find.text('TUS SELLOS').hitTestable(), findsNothing);
      // Deja terminar la animación de las tarjetas que aparecen al desplazar.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('la pestaña Tarjetas (gift cards del local)', () {
    testWidgets('muestra solo las gift cards que ese local le dio', (tester) async {
      await _open(
        tester,
        _FakeHistory(),
        initialTab: CardHistoryScreen.giftCardsTab,
        claims: [
          claim('GFT-AAAAAA', 'Regalo de Vilcanatu'),
          claim('GFT-BBBBBB', 'Regalo de otro', businessId: 'b2'),
          claim('GFT-CCCCCC', 'Otro regalo de Vilcanatu', redeemed: true),
        ],
      );

      expect(find.text('REGALO DE VILCANATU'), findsOneWidget);
      expect(find.text('OTRO REGALO DE VILCANATU'), findsOneWidget);
      expect(find.text('REGALO DE OTRO'), findsNothing);
      expect(find.text('GFT-AAAAAA'), findsOneWidget);
      expect(find.text('GFT-BBBBBB'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('sin gift cards de este local lo explica', (tester) async {
      await _open(
        tester,
        _FakeHistory(),
        initialTab: CardHistoryScreen.giftCardsTab,
        claims: [claim('GFT-BBBBBB', 'Regalo de otro', businessId: 'b2')],
      );

      expect(find.text('SIN GIFT CARDS'), findsOneWidget);
      expect(find.text('REGALO DE OTRO'), findsNothing);
    });

    testWidgets('claimsOfBusiness filtra por el local participante', (tester) async {
      final list = [claim('A', 'x'), claim('B', 'y', businessId: 'b2')];

      expect(claimsOfBusiness(list, 'b1').map((c) => c.code), ['A']);
      expect(claimsOfBusiness(list, 'b9'), isEmpty);
    });
  });

  group('la pestaña Minijuegos', () {
    testWidgets('muestra los juegos de ese local con su estado', (tester) async {
      await _open(
        tester,
        _FakeHistory(),
        initialTab: CardHistoryScreen.gamesTab,
        invites: [
          invite('1', 'sent', attemptsLeft: 2),
          invite('2', 'upcoming', game: 'flappy'),
          invite('3', 'finished', game: 'tictactoe', result: 'won'),
          invite('4', 'finished', result: 'lost'),
          invite('5', 'expired', game: 'flappy'),
          invite('6', 'sent', businessId: 'b2'),
        ],
      );

      // Solo los de este local (el sexto es de otro).
      expect(find.text('JUGAR'), findsOneWidget);
      expect(find.text('PROGRAMADO'), findsOneWidget);
      expect(find.text('GANASTE'), findsOneWidget);
      expect(find.text('PERDISTE'), findsOneWidget);
      expect(find.text('VENCIÓ'), findsOneWidget);
      expect(find.text('Te quedan 2 intentos', findRichText: false, skipOffstage: false), findsNothing);
      expect(find.textContaining('Te quedan 2 intentos'), findsOneWidget);
      expect(find.text('Gana: 20% de descuento'), findsNWidgets(5));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('los que se pueden jugar salen primero, luego programados y al final los terminados', (tester) async {
      final ordered = invitesOfBusiness(
        [
          invite('a', 'finished', result: 'won'),
          invite('b', 'upcoming'),
          invite('c', 'expired'),
          invite('d', 'sent'),
          invite('e', 'playing'),
          invite('x', 'sent', businessId: 'b2'),
        ],
        'b1',
      );

      expect(ordered.map((i) => i.id), ['d', 'e', 'b', 'a', 'c']);
    });

    testWidgets('sin juegos de este local lo explica', (tester) async {
      await _open(
        tester,
        _FakeHistory(),
        initialTab: CardHistoryScreen.gamesTab,
        invites: [invite('x', 'sent', businessId: 'b2')],
      );

      expect(find.text('SIN MINIJUEGOS'), findsOneWidget);
    });
  });

  group('acciones', () {
    testWidgets('el filtro de fechas, volver y el botón de sugerencias siguen en su lugar', (tester) async {
      await _open(tester, _FakeHistory());

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('el botón de sugerencias es rosa y no lleva borde negro', (tester) async {
      await _open(tester, _FakeHistory());

      final button = tester.widget<Material>(
        find.ancestor(of: find.byIcon(Icons.chat_bubble_outline_rounded), matching: find.byType(Material)).first,
      );
      expect(button.shape, const CircleBorder());
      expect(button.color, const Color(0xFFFEBFDC));
    });
  });
}
