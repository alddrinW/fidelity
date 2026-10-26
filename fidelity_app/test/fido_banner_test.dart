import 'dart:io';

import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

Map<String, dynamic> card(
  String id,
  String name, {
  int points = 0,
  int required = 10,
  String? reward = 'Café gratis',
  bool pendingReward = false,
}) =>
    {
      'id': id,
      'current_points': points,
      'pending_scans': 0,
      'rewards': [
        if (pendingReward) {'status': 'pending'},
      ],
      'businesses': {
        'id': 'b-$id',
        'name': name,
        'points_required': required,
        'reward_description': reward,
        'logo_url': null,
      },
    };

class _FakeGames extends GamesRepository {
  @override
  Future<List<GameInvite>> myInvites() async => const [];
}

class _FakeSales extends CardSalesRepository {
  _FakeSales(this.offersValue);
  final List<Campaign> offersValue;

  @override
  Future<List<Campaign>> offers() async => offersValue;
}

Campaign _offer() => const Campaign(
      id: 'o1',
      type: CampaignType.giftCard,
      title: 'Café por 25 centavos',
      phase: CampaignPhase.active,
      benefitLabel: 'Café de \$1',
      priceCents: 25,
      stock: 50,
      stockLeft: 12,
      cardValidDays: 30,
      businesses: [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('las poses de Fido', () {
    test('cada pose tiene su archivo, liviano y con su descripción', () {
      for (final pose in FidoPose.values) {
        final file = File(pose.asset);
        expect(file.existsSync(), isTrue, reason: pose.asset);
        // Es un banner de un celular: cada pose debe pesar poco.
        expect(file.lengthSync(), lessThan(120 * 1024), reason: pose.asset);
        expect(pose.label, startsWith('Fido'));
      }
    });
  });

  group('los banners en inglés', () {
    final t = Translator.english;

    test('títulos, botones y mensajes con datos', () {
      expect(t.toEnglish('¡PREMIO LISTO!'), 'PRIZE READY!');
      expect(t.toEnglish('TE FALTA 1 PUNTO'), '1 POINT TO GO');
      expect(t.toEnglish('INVITA A UN AMIGO'), 'INVITE A FRIEND');
      expect(t.toEnglish('COMPRAR'), 'BUY');
      expect(t.toEnglish('Pásate por Café Aurora y reclama tu premio.'), 'Stop by Café Aurora and claim your prize.');
      expect(t.toEnglish('Escanea hoy en Pizzería Sol y gana: 20% de descuento.'), 'Scan today at Pizzería Sol and win: 20% de descuento.');
      expect(t.toEnglish('Café Aurora. Cómprala y canjéala en el local.'), 'Café Aurora. Buy it and redeem it at the business.');
      expect(t.toEnglish('Ahorcado de Café Aurora. Te quedan 3 intentos.'), 'Hangman at Café Aurora. You have 3 attempts left.');
      expect(t.toEnglish('Ahorcado de Café Aurora. Te queda 1 intento.'), 'Hangman at Café Aurora. You have 1 attempt left.');
    });

    test('el precio de una tarjeta en el título', () {
      expect(t.toEnglish('CAFÉ DE \$1 POR \$0.25'), 'CAFÉ DE \$1 FOR \$0.25');
    });
  });

  group('FidoBannerCarousel', () {
    Future<void> open(
      WidgetTester tester, {
      List<Map<String, dynamic>> cards = const [],
      List<Campaign> offers = const [],
      void Function(Map<String, dynamic>)? onReward,
      VoidCallback? onScan,
      VoidCallback? onOffers,
      bool autoPlay = false,
      Size size = const Size(900, 1600),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamesRepositoryProvider.overrideWithValue(_FakeGames()),
            cardSalesRepositoryProvider.overrideWithValue(_FakeSales(offers)),
          ],
          child: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: spanishApp(
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FidoBannerCarousel(
                    cards: cards,
                    onOpenReward: onReward,
                    onScan: onScan,
                    onOpenOffers: onOffers,
                    autoPlay: autoPlay,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('sin nada que decirle, no ocupa espacio', (tester) async {
      await open(tester, cards: [card('1', 'Aurora', points: 2)]);

      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('un premio esperando: Fido lo dice con los pulgares arriba y abre ese premio', (tester) async {
      Map<String, dynamic>? opened;
      await open(
        tester,
        cards: [card('1', 'Café Aurora', points: 10, pendingReward: true)],
        onReward: (c) => opened = c,
      );

      expect(find.text('¡PREMIO LISTO!'), findsOneWidget);
      expect(find.text('Pásate por Café Aurora y reclama tu premio.'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.semanticLabel == FidoPose.pulgares.label), findsOneWidget);

      await tester.tap(find.text('VER PREMIO'));
      expect(opened?['id'], '1');
    });

    testWidgets('a un punto del premio: dice cuál y lleva al escáner', (tester) async {
      var scans = 0;
      await open(
        tester,
        cards: [card('1', 'Pizzería Sol', points: 9, reward: '20% de descuento')],
        onScan: () => scans++,
      );

      expect(find.text('TE FALTA 1 PUNTO'), findsOneWidget);
      expect(find.text('Escanea hoy en Pizzería Sol y gana: 20% de descuento.'), findsOneWidget);

      await tester.tap(find.text('ESCANEAR'));
      expect(scans, 1);
    });

    testWidgets('sin escáner al que ir, no ofrece "te falta 1"', (tester) async {
      await open(tester, cards: [card('1', 'Pizzería Sol', points: 9)]);

      expect(find.text('TE FALTA 1 PUNTO'), findsNothing);
    });

    testWidgets('con un premio y un punto por ganar, el premio va primero y hay puntitos', (tester) async {
      await open(
        tester,
        cards: [card('1', 'Pizzería Sol', points: 9), card('2', 'Café Aurora', points: 10, pendingReward: true)],
        onReward: (_) {},
        onScan: () {},
      );

      expect(find.text('¡PREMIO LISTO!'), findsOneWidget);
      expect(find.text('TE FALTA 1 PUNTO'), findsNothing);
      // Dos mensajes = dos puntitos de avance.
      expect(find.byType(AnimatedContainer), findsNWidgets(2));

      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('TE FALTA 1 PUNTO'), findsOneWidget);
    });

    testWidgets('pasa solo al siguiente mensaje cada 6 segundos', (tester) async {
      await open(
        tester,
        cards: [card('1', 'Pizzería Sol', points: 9), card('2', 'Café Aurora', points: 10, pendingReward: true)],
        onReward: (_) {},
        onScan: () {},
        autoPlay: true,
      );
      expect(find.text('¡PREMIO LISTO!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('¡PREMIO LISTO!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2)); // salta el temporizador
      await tester.pump(const Duration(milliseconds: 300)); // y se desliza
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TE FALTA 1 PUNTO'), findsOneWidget);
      expect(find.text('¡PREMIO LISTO!'), findsNothing);
    });

    testWidgets('si el usuario pidió menos movimiento, no pasa solo', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamesRepositoryProvider.overrideWithValue(_FakeGames()),
            cardSalesRepositoryProvider.overrideWithValue(_FakeSales(const [])),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(900, 1600), disableAnimations: true),
            child: spanishApp(
              Scaffold(
                body: FidoBannerCarousel(
                  cards: [card('1', 'Pizzería Sol', points: 9), card('2', 'Café Aurora', points: 10, pendingReward: true)],
                  onOpenReward: (_) {},
                  onScan: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 20));

      expect(find.text('¡PREMIO LISTO!'), findsOneWidget);
    });

    testWidgets('una tarjeta en venta: la ofrece con el café y su precio', (tester) async {
      await open(tester, offers: [_offer()]);

      expect(find.text('CAFÉ DE \$1 POR \$0.25'), findsOneWidget);
      expect(find.text('COMPRAR'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.semanticLabel == FidoPose.cafe.label), findsOneWidget);
    });

    testWidgets('si los mensajes cambian, el carrusel arranca otra vez desde el primero', (tester) async {
      // Un premio que llega mientras mira otro mensaje no deja al carrusel en una página que ya no existe.
      await open(tester, cards: [card('1', 'Pizzería Sol', points: 9)], onScan: () {});
      expect(find.text('TE FALTA 1 PUNTO'), findsOneWidget);
    });

    testWidgets('en un celular angosto, con letra grande y nombres largos no se desborda', (tester) async {
      await open(
        tester,
        cards: [
          card('1', 'Restaurante El Rincón de la Abuela Mercedes y Familia', points: 11, required: 12, reward: 'Almuerzo completo con postre y bebida gratis'),
        ],
        onReward: (_) {},
        onScan: () {},
        size: const Size(320, 800),
        textScale: 1.4,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('un solo mensaje no muestra puntitos', (tester) async {
      await open(tester, cards: [card('1', 'Pizzería Sol', points: 9)], onScan: () {});

      expect(find.byType(AnimatedContainer), findsNothing);
    });
  });
}
