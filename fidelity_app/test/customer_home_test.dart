import 'package:fidelity_app/features/cards/customer_home_view.dart';
import 'package:fidelity_app/features/cards/providers/my_cards_provider.dart';
import 'package:fidelity_app/features/cards/widgets/registered_scans_list.dart';
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
}) =>
    {
      'id': id,
      'current_points': points,
      'pending_scans': 0,
      'rewards': const [],
      'businesses': {
        'id': 'b-$id',
        'name': name,
        'points_required': required,
        'reward_description': reward,
        'logo_url': null,
      },
    };

class _FakeCards extends MyCardsNotifier {
  _FakeCards(this.cardsState);
  final MyCardsState cardsState;

  @override
  MyCardsState build() => cardsState;
}

class _FakeGames extends GamesRepository {
  @override
  Future<List<GameInvite>> myInvites() async => const [];
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('RegisteredScansList', () {
    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> cards, {ValueChanged<Map<String, dynamic>>? onOpen}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(spanishApp(
        Scaffold(
          body: SingleChildScrollView(
            child: RegisteredScansList(cards: cards, onOpen: onOpen ?? (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el local, su premio y cuánto lleva', (tester) async {
      await pump(tester, [card('1', 'Vilcanatu', points: 1)]);

      expect(find.text('MIS ESCANEOS REGISTRADOS'), findsOneWidget);
      expect(find.text('VILCANATU'), findsOneWidget);
      expect(find.text('PREMIO'), findsOneWidget);
      expect(find.text('Café gratis'), findsOneWidget);
      expect(find.text('1/10'), findsOneWidget);
    });

    testWidgets('un local sin premio descrito no deja un hueco', (tester) async {
      await pump(tester, [card('1', 'Vilcanatu', points: 1, reward: null)]);

      expect(find.text('PREMIO'), findsNothing);
      expect(find.text('VILCANATU'), findsOneWidget);
    });

    testWidgets('mantiene el orden de las tarjetas y al tocar una se abre', (tester) async {
      Map<String, dynamic>? opened;
      await pump(
        tester,
        [card('1', 'Primero', points: 1), card('2', 'Segundo', points: 9)],
        onOpen: (c) => opened = c,
      );

      expect(tester.getTopLeft(find.text('PRIMERO')).dy, lessThan(tester.getTopLeft(find.text('SEGUNDO')).dy));

      await tester.tap(find.text('SEGUNDO'));
      expect(opened?['id'], '2');
    });

    testWidgets('sin tarjetas no ocupa espacio', (tester) async {
      await pump(tester, const []);

      expect(find.text('MIS ESCANEOS REGISTRADOS'), findsNothing);
    });

    testWidgets('en un celular angosto y con letra grande no se desborda', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(320, 900), textScaler: TextScaler.linear(1.4)),
        child: spanishApp(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RegisteredScansList(
                cards: [
                  card('1', 'Restaurante El Rincón de la Abuela Mercedes', points: 11, required: 12, reward: 'Almuerzo completo con postre y bebida gratis'),
                ],
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('inicio del cliente', () {
    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> cards) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          myCardsProvider.overrideWith(() => _FakeCards(MyCardsState(isLoading: false, userName: 'juan diego', cards: cards))),
          gamesRepositoryProvider.overrideWithValue(_FakeGames()),
        ],
        child: spanishApp(const Scaffold(body: CustomerHomeView())),
      ));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('ya no muestra "Novedades": solo los escaneos registrados', (tester) async {
      await pump(tester, [card('1', 'Vilcanatu', points: 1), card('2', 'Aurora', points: 2)]);

      expect(find.text('NOVEDADES'), findsNothing);
      expect(find.text('MIS ESCANEOS REGISTRADOS'), findsOneWidget);
      expect(find.text('VILCANATU'), findsOneWidget);
      expect(find.text('AURORA'), findsOneWidget);
    });

    testWidgets('sin tarjetas invita a escanear el primer código', (tester) async {
      await pump(tester, const []);

      expect(find.text('NOVEDADES'), findsNothing);
      expect(find.text('EMPIEZA A GANAR'), findsOneWidget);
    });
  });
}
