import 'package:fidelity_app/core/l10n/app_language.dart';
import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/banners/data/banners_repository.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:fidelity_app/features/games/data/weekly_game_repository.dart';
import 'package:fidelity_app/features/games/game_invite_screen.dart';
import 'package:fidelity_app/features/games/weekly_game_screen.dart';
import 'package:fidelity_app/features/games/widgets/game_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_banners.dart';
import 'spanish_app.dart';

class _FakeWeekly extends WeeklyGameRepository {
  _FakeWeekly(this.value);
  WeeklyStatus value;

  final List<String> started = [];
  Object? failWith;

  @override
  Future<WeeklyStatus> status() async => value;

  @override
  Future<String> start(String businessId) async {
    if (failWith != null) throw failWith!;
    started.add(businessId);
    return 'invite-1';
  }
}

class _FakeGames extends GamesRepository {
  @override
  Future<List<GameInvite>> myInvites() async => const [];

  @override
  Future<GamePlay> invite(String id) async => const GamePlay(
        id: 'invite-1',
        game: GameKey.hangman,
        gameName: 'Ahorcado',
        status: 'sent',
        weekly: true,
        businessName: 'Pizzería Sol',
        prizeLabel: '1 punto en Pizzería Sol',
      );
}

class _FakeSales extends CardSalesRepository {
  @override
  Future<List<Campaign>> offers() async => const [];
}

/// El banner ya diseñado (la imagen) de un archivo.
Finder bannerImage(String asset) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == asset,
    );

const _a = WeeklyBusiness(id: 'a', name: 'Café Aurora', currentPoints: 3, pointsRequired: 10);
const _b = WeeklyBusiness(id: 'b', name: 'Pizzería Sol', currentPoints: 7, pointsRequired: 8);
const _c = WeeklyBusiness(id: 'c', name: 'Heladería Luna', blocked: true);

WeeklyStatus _available({List<WeeklyBusiness> businesses = const [_a, _b, _c], int points = 1}) =>
    WeeklyStatus(state: 'available', points: points, nextAt: DateTime(2026, 10, 26), businesses: businesses);

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('en inglés', () {
    final t = Translator.english;

    test('el juego semanal y sus mensajes', () {
      expect(t.toEnglish('JUEGO DE LA SEMANA'), 'GAME OF THE WEEK');
      expect(t.toEnglish('ELEGIR NEGOCIO'), 'CHOOSE BUSINESS');
      expect(t.toEnglish('Elige un negocio, juega y gana 1 punto.'), startsWith('Pick a business, play and win'));
      expect(t.toEnglish('Llevas 3 de 10 puntos'), 'You have 3 of 10 points');
      expect(t.toEnglish('Ya ganaste aquí'), 'You already won here');
      expect(t.toEnglish('VUELVE EL LUNES'), 'COME BACK ON MONDAY');
      expect(t.toEnglish('Sumaste 1 punto en Café Aurora.'), startsWith('You earned'));
      expect(t.toEnglish('1 PUNTO EN PIZZERÍA SOL'), '1 POINT AT PIZZERÍA SOL');
    });
  });

  group('modelos', () {
    test('lee el estado de la semana con sus negocios y el juego elegido', () {
      final s = WeeklyStatus.fromJson({
        'state': 'playing',
        'points': 2,
        'nextAt': '2026-10-26T05:00:00.000Z',
        'current': {
          'inviteId': 'w1',
          'businessId': 'a',
          'businessName': 'Café Aurora',
          'gameName': 'Ahorcado',
          'status': 'sent',
          'canChange': true,
        },
        'businesses': [
          {'id': 'a', 'name': 'Café Aurora', 'currentPoints': 3, 'pointsRequired': 10, 'blocked': false},
          {'id': 'c', 'name': 'Heladería Luna', 'blocked': true},
        ],
      });

      expect(s.isPlaying, isTrue);
      expect(s.canPlay, isTrue);
      expect(s.points, 2);
      expect(s.current?.canChange, isTrue);
      expect(s.businesses.map((b) => b.blocked), [false, true]);
      expect(s.nextAt, isNotNull);
    });

    test('solo "available" y "playing" pueden jugar', () {
      for (final (state, can) in [('off', false), ('available', true), ('playing', true), ('done', false), ('empty', false)]) {
        expect(WeeklyStatus(state: state).canPlay, can, reason: state);
      }
    });

    test('un juego semanal de la partida se reconoce', () {
      final play = GamePlay.fromJson({'id': 'i', 'game': 'hangman', 'gameName': 'Ahorcado', 'status': 'sent', 'weekly': true});
      expect(play.weekly, isTrue);
      expect(GamePlay.fromJson({'id': 'i', 'game': 'hangman', 'gameName': 'x', 'status': 'sent'}).weekly, isFalse);
    });
  });

  group('WeeklyGameScreen', () {
    Future<_FakeWeekly> open(WidgetTester tester, WeeklyStatus status) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeWeekly(status);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyGameRepositoryProvider.overrideWithValue(repo),
            bannersRepositoryProvider.overrideWithValue(FakeBannersRepository()),
            gamesRepositoryProvider.overrideWithValue(_FakeGames()),
          ],
          child: spanishApp(const WeeklyGameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('apagado por el administrador: lo dice', (tester) async {
      await open(tester, const WeeklyStatus(state: 'off'));

      expect(find.text('JUEGO NO DISPONIBLE'), findsOneWidget);
    });

    testWidgets('sin ser cliente de ningún negocio: explica cómo empezar', (tester) async {
      await open(tester, const WeeklyStatus(state: 'empty'));

      expect(find.text('AÚN NO TIENES NEGOCIOS'), findsOneWidget);
    });

    testWidgets('disponible: pide elegir negocio y muestra cuánto lleva en cada uno', (tester) async {
      await open(tester, _available());

      expect(find.text('ELIGE TU NEGOCIO'), findsOneWidget);
      expect(find.text('Juegas una vez por semana. Si ganas, sumas 1 punto en el negocio que elijas.'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('Llevas 3 de 10 puntos'), findsOneWidget);
      expect(find.text('Llevas 7 de 8 puntos'), findsOneWidget);
    });

    testWidgets('el negocio donde ya ganó sale bloqueado, con candado, y no se puede elegir', (tester) async {
      final repo = await open(tester, _available());

      expect(find.text('Ya ganaste aquí'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('no se pueden repetir'), findsOneWidget);

      await tester.tap(find.text('HELADERÍA LUNA'));
      await tester.pump();
      expect(repo.started, isEmpty);
    });

    testWidgets('con 2 puntos configurados lo dice en plural', (tester) async {
      await open(tester, _available(points: 2));

      expect(find.textContaining('sumas 2 puntos'), findsOneWidget);
    });

    testWidgets('elegir un negocio arranca el juego y abre la partida', (tester) async {
      final repo = await open(tester, _available());

      await tester.tap(find.text('PIZZERÍA SOL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.started, ['b']);
      expect(find.byType(GameInviteScreen), findsOneWidget);
      // La partida semanal se presenta como tal y su premio es el punto.
      expect(find.text('TU JUEGO DE LA SEMANA'), findsWidgets);
      expect(find.text('1 PUNTO EN PIZZERÍA SOL'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6)); // deja terminar las animaciones
    });

    testWidgets('si el servidor lo rechaza, muestra el motivo y no abre nada', (tester) async {
      (await open(tester, _available())).failWith = Exception('Ya ganaste un punto en este negocio. Elige otro.');

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ya ganaste un punto en este negocio. Elige otro.'), findsOneWidget);
      expect(find.byType(GameInviteScreen), findsNothing);
    });

    testWidgets('ya eligió y le falta jugar: ofrece jugar y cambiar de negocio', (tester) async {
      await open(
        tester,
        const WeeklyStatus(
          state: 'playing',
          businesses: [_a, _b],
          current: WeeklyCurrent(inviteId: 'w1', businessId: 'a', businessName: 'Café Aurora', gameName: 'Ahorcado', status: 'sent', canChange: true),
        ),
      );

      expect(find.text('TU JUEGO DE LA SEMANA'), findsOneWidget);
      expect(find.text('Elegiste Café Aurora: ¡a jugar!'), findsOneWidget);
      expect(find.text('JUGAR'), findsOneWidget);
      expect(find.text('O elige otro negocio antes de jugar:'), findsOneWidget);
      expect(find.text('PIZZERÍA SOL'), findsOneWidget);
    });

    testWidgets('con el primer intento empezado ya no puede cambiar de negocio', (tester) async {
      await open(
        tester,
        const WeeklyStatus(
          state: 'playing',
          businesses: [_a, _b],
          current: WeeklyCurrent(inviteId: 'w1', businessId: 'a', businessName: 'Café Aurora', gameName: 'Ahorcado', status: 'playing'),
        ),
      );

      expect(find.text('SEGUIR JUGANDO'), findsOneWidget);
      expect(find.text('PIZZERÍA SOL'), findsNothing);
    });

    testWidgets('ganó: lo celebra y dice cuándo vuelve', (tester) async {
      await open(
        tester,
        WeeklyStatus(
          state: 'done',
          nextAt: DateTime(2026, 10, 26),
          current: const WeeklyCurrent(inviteId: 'w1', businessId: 'a', businessName: 'Café Aurora', gameName: 'Ahorcado', status: 'finished', result: 'won'),
        ),
      );

      expect(find.text('¡GANASTE!'), findsOneWidget);
      expect(find.text('Sumaste 1 punto en Café Aurora.'), findsOneWidget);
      expect(find.text('VUELVE EL LUNES'), findsOneWidget);
      expect(find.text('26/10'), findsOneWidget);
      expect(find.text('Entonces podrás elegir otro negocio.'), findsOneWidget);
    });

    testWidgets('perdió: pierde la semana pero el negocio sigue libre', (tester) async {
      await open(
        tester,
        WeeklyStatus(
          state: 'done',
          nextAt: DateTime(2026, 10, 26),
          current: const WeeklyCurrent(inviteId: 'w1', businessId: 'a', businessName: 'Café Aurora', gameName: 'Ahorcado', status: 'finished', result: 'lost'),
        ),
      );

      expect(find.text('ESTA SEMANA NO'), findsOneWidget);
      expect(find.textContaining('Café Aurora sigue libre'), findsOneWidget);
      expect(find.text('Entonces podrás jugar de nuevo.'), findsOneWidget);
    });
  });

  group('resultado de la partida semanal', () {
    Future<void> show(WidgetTester tester, GamePlay play) async {
      await tester.pumpWidget(spanishApp(Scaffold(body: GameResultView(play: play, onClose: () {}))));
      await tester.pump(const Duration(milliseconds: 600));
    }

    GamePlay play({required String result, bool weekly = true, String? claimCode}) => GamePlay(
          id: 'i',
          game: GameKey.hangman,
          gameName: 'Ahorcado',
          status: 'finished',
          result: result,
          weekly: weekly,
          businessName: 'Café Aurora',
          prizeLabel: weekly ? '1 punto en Café Aurora' : '20% de descuento',
          claimCode: claimCode,
        );

    testWidgets('ganó: dice los puntos sumados y no habla de gift card ni de código', (tester) async {
      await show(tester, play(result: 'won'));

      expect(find.text('Sumaste 1 punto en Café Aurora. La próxima semana juega en otro negocio.'), findsOneWidget);
      expect(find.text('TU CÓDIGO'), findsNothing);
      expect(find.textContaining('Mis regalos'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('perdió: vuelve el lunes', (tester) async {
      await show(tester, play(result: 'lost'));

      expect(find.textContaining('la próxima semana será'), findsOneWidget);
      expect(find.textContaining('Vuelve el lunes'), findsOneWidget);
    });

    testWidgets('un reto de un dueño sigue hablando de su gift card', (tester) async {
      await show(tester, play(result: 'won', weekly: false, claimCode: 'GFT-ABC234'));

      expect(find.text('Tu premio: 20% de descuento. Ya está en Mis regalos.'), findsOneWidget);
      expect(find.text('TU CÓDIGO'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('banner de Fido del juego semanal', () {
    Future<void> open(WidgetTester tester, WeeklyStatus status, {List<Override> overrides = const []}) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyGameRepositoryProvider.overrideWithValue(_FakeWeekly(status)),
            bannersRepositoryProvider.overrideWithValue(FakeBannersRepository()),
            gamesRepositoryProvider.overrideWithValue(_FakeGames()),
            cardSalesRepositoryProvider.overrideWithValue(_FakeSales()),
            ...overrides,
          ],
          child: spanishApp(const Scaffold(body: FidoBannerCarousel(autoPlay: false))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('disponible con 1 punto: sale el banner diseñado "Juega y gana"', (tester) async {
      await open(tester, _available());

      expect(bannerImage(BannerImages.play), findsOneWidget);
      expect(find.text('ELEGIR NEGOCIO'), findsNothing);
    });

    testWidgets('con otros puntos la imagen ya no vale: sale la nube con los puntos correctos', (tester) async {
      await open(tester, _available(points: 2));

      expect(bannerImage(BannerImages.play), findsNothing);
      expect(find.text('JUEGO DE LA SEMANA'), findsOneWidget);
      expect(find.text('Elige un negocio, juega y gana 2 puntos.'), findsOneWidget);
      expect(find.text('ELEGIR NEGOCIO'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'Fido'), findsOneWidget);
    });

    testWidgets('con la app en inglés no sale la imagen (trae el texto en español): sale la nube, que sí se traduce', (tester) async {
      await open(tester, _available(), overrides: [initialLanguageProvider.overrideWithValue(AppLanguage.en)]);

      expect(bannerImage(BannerImages.play), findsNothing);
      // (La prueba fija el idioma de los textos en español; lo que se comprueba es que cambia a la nube.)
      expect(find.text('JUEGO DE LA SEMANA'), findsOneWidget);
    });

    testWidgets('con el negocio ya elegido, dice cuál y pide jugar', (tester) async {
      await open(
        tester,
        const WeeklyStatus(
          state: 'playing',
          current: WeeklyCurrent(inviteId: 'w1', businessId: 'a', businessName: 'Café Aurora', gameName: 'Ahorcado', status: 'sent'),
        ),
      );

      // Ya eligió negocio: la imagen genérica no dice eso, sale la nube con el negocio.
      expect(bannerImage(BannerImages.play), findsNothing);
      expect(find.text('Elegiste Café Aurora: ¡a jugar y ganar 1 punto!'), findsOneWidget);
      expect(find.text('JUGAR'), findsOneWidget);
    });

    testWidgets('ya jugó esta semana, está apagado o no tiene negocios: sale el diseño "Juega y gana", sin mensaje del juego', (tester) async {
      for (final state in ['done', 'off', 'empty']) {
        await open(tester, WeeklyStatus(state: state));
        expect(find.text('JUEGO DE LA SEMANA'), findsNothing, reason: state);
        expect(bannerImage(BannerImages.play), findsOneWidget, reason: state);
      }
    });

    testWidgets('si no se pudo saber el estado del juego, no sale', (tester) async {
      await open(tester, WeeklyStatus(state: 'off'), overrides: [weeklyGameProvider.overrideWith((ref) => throw Exception('sin red'))]);

      expect(bannerImage(BannerImages.play), findsNothing);
    });

    testWidgets('al tocarlo abre el juego de la semana', (tester) async {
      await open(tester, _available());

      await tester.tap(bannerImage(BannerImages.play));
      await tester.pumpAndSettle();

      expect(find.byType(WeeklyGameScreen), findsOneWidget);
    });
  });
}
