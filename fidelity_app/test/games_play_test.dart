import 'dart:math' as math;

import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:fidelity_app/features/games/flappy_physics.dart';
import 'package:fidelity_app/features/games/game_invite_screen.dart';
import 'package:fidelity_app/features/games/widgets/flappy_game.dart';
import 'package:fidelity_app/features/games/widgets/game_result_view.dart';
import 'package:fidelity_app/features/games/widgets/hangman_game.dart';
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/games/widgets/tic_tac_toe_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Datos de prueba en lugar de la red.
class _FakeGamesRepository extends GamesRepository {
  GamePlay current;
  List<GameInvite> invites = [];
  final List<String> calls = [];
  GamePlay Function(String letter)? onGuess;
  GamePlay Function(int cell)? onMove;
  GamePlay Function(int score)? onFinish;
  GamePlay Function()? onStart;

  _FakeGamesRepository(this.current);

  @override
  Future<GamePlay> invite(String id) async => current;

  @override
  Future<GamePlay> start(String id) async {
    calls.add('start');
    return current = onStart!();
  }

  @override
  Future<GamePlay> guess(String id, String letter) async {
    calls.add('guess:$letter');
    return current = onGuess!(letter);
  }

  @override
  Future<GamePlay> move(String id, int cell) async {
    calls.add('move:$cell');
    return current = onMove!(cell);
  }

  @override
  Future<GamePlay> finish(String id, int score) async {
    calls.add('finish:$score');
    return current = onFinish!(score);
  }

  @override
  Future<List<GameInvite>> myInvites() async => invites;
}

GamePlay _play({
  GameKey game = GameKey.hangman,
  String status = 'sent',
  String? result,
  String? claimCode,
  int? score,
  Map<String, dynamic> play = const {},
  int attempts = 0,
  int attemptsLeft = 3,
  String? lastAttempt,
  DateTime? startsAt,
  DateTime? expiresAt,
}) =>
    GamePlay(
      id: 'i1',
      game: game,
      gameName: game.label,
      businessName: 'Café Aurora',
      prizeLabel: '20% de descuento',
      status: status,
      result: result,
      claimCode: claimCode,
      score: score,
      play: play,
      attempts: attempts,
      attemptsLeft: attemptsLeft,
      lastAttempt: lastAttempt,
      startsAt: startsAt,
      expiresAt: expiresAt,
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GameKey y modelos', () {
    test('conoce los tres juegos', () {
      expect(GameKey.values.map((g) => g.apiValue), ['tictactoe', 'hangman', 'flappy']);
      expect(GameKey.parse('flappy'), GameKey.flappy);
      expect(GameKey.parse('otro'), isNull);
    });

    test('una solicitud lee sus juegos, premio y datos del negocio', () {
      final a = GameAccess.fromJson({
        'id': 'a1',
        'businessId': 'b1',
        'status': 'approved',
        'games': ['hangman', 'flappy', 'raro'],
        'prize': {'type': 'discount_percent', 'value': 25, 'label': '25% de descuento'},
        'business': {'name': 'Café Aurora'},
        'owner': {'fullName': 'Aurora', 'email': 'a@mail.com'},
        'requestedAt': '2026-10-21T15:00:00.000Z',
      });

      expect(a.isApproved, isTrue);
      expect(a.games, [GameKey.hangman, GameKey.flappy]); // el juego desconocido se ignora
      expect(a.prize?.isDiscount, isTrue);
      expect(a.prize?.value, 25);
      expect(a.businessName, 'Café Aurora');
      expect(a.ownerEmail, 'a@mail.com');
    });

    test('sin solicitud el estado es "none"', () {
      expect(GameAccess.fromJson({'status': 'none', 'games': []}).status, GameAccessStatus.none);
      expect(GameAccessStatus.parse(null), GameAccessStatus.none);
    });

    test('un reto abierto se puede jugar; uno vencido o terminado no', () {
      GameInvite invite(String status) =>
          GameInvite.fromJson({'id': '1', 'game': 'hangman', 'gameName': 'Ahorcado', 'status': status});

      expect(invite('sent').isOpen, isTrue);
      expect(invite('playing').isOpen, isTrue);
      expect(invite('finished').isOpen, isFalse);
      expect(invite('expired').isOpen, isFalse);
      // Uno programado todavía no se puede jugar.
      expect(invite('upcoming').isOpen, isFalse);
      expect(invite('upcoming').isUpcoming, isTrue);
    });

    test('un reto lee su horario y sus intentos (3 si el servidor no dice)', () {
      final i = GameInvite.fromJson({
        'id': '1',
        'status': 'sent',
        'startsAt': '2026-10-21T15:00:00.000Z',
        'expiresAt': '2026-10-28T15:00:00.000Z',
        'attempts': 1,
        'maxAttempts': 3,
        'attemptsLeft': 2,
      });

      expect(i.startsAt, isNotNull);
      expect(i.expiresAt!.isAfter(i.startsAt!), isTrue);
      expect(i.attempts, 1);
      expect(i.attemptsLeft, 2);
      expect(GameInvite.fromJson({'id': '2'}).maxAttempts, 3);
    });

    test('una partida sabe si perdió el último intento y aún puede reintentar', () {
      final retry = GamePlay.fromJson({
        'id': 'i1',
        'game': 'hangman',
        'status': 'sent',
        'attempts': 1,
        'maxAttempts': 3,
        'attemptsLeft': 2,
        'lastAttempt': 'lost',
      });
      final over = GamePlay.fromJson({
        'id': 'i1',
        'game': 'hangman',
        'status': 'finished',
        'result': 'lost',
        'attempts': 3,
        'attemptsLeft': 0,
      });

      expect(retry.lostLastAttempt, isTrue);
      expect(retry.attemptsLeft, 2);
      expect(over.lostLastAttempt, isFalse);
      expect(over.isFinished, isTrue);
      expect(GamePlay.fromJson({'id': 'i1', 'status': 'upcoming'}).isUpcoming, isTrue);
    });

    test('una partida lee su resultado y su gift card', () {
      final p = GamePlay.fromJson({
        'id': 'i1',
        'game': 'tictactoe',
        'gameName': 'Tres en raya',
        'status': 'finished',
        'result': 'won',
        'claimCode': 'GFT-ABC234',
        'play': {'board': List.filled(9, '')},
      });

      expect(p.isFinished, isTrue);
      expect(p.isWon, isTrue);
      expect(p.claimCode, 'GFT-ABC234');
      expect((p.play['board'] as List), hasLength(9));
    });

    test('los envíos del dueño leen cifras y lista', () {
      final s = SentGames.fromJson({
        'stats': {'sent': 5, 'played': 3, 'won': 1},
        'items': [
          {'gameName': 'Ahorcado', 'userName': 'Ana', 'status': 'finished', 'result': 'won'}
        ],
      });

      expect(s.sent, 5);
      expect(s.won, 1);
      expect(s.items.single.userName, 'Ana');
    });
  });

  group('física de Flappy Bird', () {
    const config = FlappyConfig();
    final random = math.Random(7);

    test('cada tubo tarda al menos 1.2 s (el servidor no acepta menos de 1.1 s)', () {
      expect(config.secondsPerPipe, greaterThanOrEqualTo(1.2));
    });

    test('la gravedad hace caer al pájaro', () {
      final s = FlappyState.initial(config, random);
      final next = step(s, 0.1, config, random);

      expect(next.birdY, greaterThan(s.birdY));
      expect(next.birdVelocity, greaterThan(0));
    });

    test('aletear lo hace subir', () {
      var s = FlappyState.initial(config, random);
      s = flap(s, config);
      final next = step(s, 0.1, config, random);

      expect(next.birdVelocity, lessThan(0));
      expect(next.birdY, lessThan(s.birdY));
    });

    test('los tubos avanzan hacia la izquierda', () {
      final s = FlappyState.initial(config, random);
      final next = step(s, 0.5, config, random);

      expect(next.pipes.first.x, closeTo(s.pipes.first.x - config.pipeSpeed * 0.5, 0.001));
    });

    test('caer al suelo o subir al techo es chocar', () {
      final s = FlappyState.initial(config, random);

      expect(collides(s.copyWith(birdY: config.height), config), isTrue);
      expect(collides(s.copyWith(birdY: 0), config), isTrue);
      expect(collides(s.copyWith(birdY: config.height / 2), config), isFalse);
    });

    test('chocar con un tubo, pero no pasar por el hueco', () {
      const pipe = FlappyPipe(x: 90, gapY: 260);
      final base = FlappyState(
        birdY: 260,
        birdVelocity: 0,
        pipes: const [pipe],
        score: 0,
        dead: false,
      );

      expect(collides(base, config), isFalse); // por el centro del hueco
      expect(collides(base.copyWith(birdY: 260 - config.gap / 2), config), isTrue); // contra el tubo de arriba
      expect(collides(base.copyWith(birdY: 260 + config.gap / 2), config), isTrue); // contra el de abajo
    });

    test('pasar un tubo suma un punto, una sola vez', () {
      const pipe = FlappyPipe(x: 40, gapY: 260);
      var s = FlappyState(birdY: 260, birdVelocity: 0, pipes: const [pipe], score: 0, dead: false);

      // El pájaro se mantiene a la altura del hueco mientras el tubo lo pasa.
      for (var i = 0; i < 60 && s.score == 0; i++) {
        s = s.copyWith(birdY: 260, birdVelocity: 0);
        s = step(s, 0.02, config, random);
      }
      expect(s.score, 1);

      for (var i = 0; i < 5; i++) {
        s = s.copyWith(birdY: 260, birdVelocity: 0);
        s = step(s, 0.02, config, random);
      }
      expect(s.score, 1);
    });

    test('aparecen tubos nuevos y los que salieron se descartan', () {
      var s = FlappyState.initial(config, math.Random(3));
      for (var i = 0; i < 600; i++) {
        // Mantiene vivo al pájaro en el centro para probar solo los tubos.
        s = s.copyWith(birdY: config.height / 2, birdVelocity: 0, dead: false);
        s = step(s, 0.02, config, math.Random(3));
      }

      expect(s.pipes, isNotEmpty);
      expect(s.pipes.every((p) => p.x + config.pipeWidth > -1), isTrue);
      expect(s.pipes.length, lessThan(5));
    });

    test('los huecos quedan siempre dentro de la pantalla', () {
      final r = math.Random(11);
      for (var i = 0; i < 200; i++) {
        final s = FlappyState.initial(config, r);
        final p = s.pipes.first;
        expect(p.gapY - config.gap / 2, greaterThanOrEqualTo(40));
        expect(p.gapY + config.gap / 2, lessThanOrEqualTo(config.height - 40));
      }
    });

    test('un pájaro muerto no se mueve ni aletea', () {
      final s = FlappyState.initial(config, random).copyWith(dead: true);

      expect(step(s, 0.1, config, random), same(s));
      expect(flap(s, config), same(s));
    });

    test('soltado sin aletear, el pájaro muere en pocos segundos', () {
      var s = FlappyState.initial(config, random);
      for (var i = 0; i < 300 && !s.dead; i++) {
        s = step(s, 0.02, config, random);
      }

      expect(s.dead, isTrue);
      expect(s.score, 0);
    });
  });

  group('FlappyGame (widget)', () {
    testWidgets('al tocar empieza; sin aletear choca y avisa su puntaje una sola vez', (tester) async {
      final scores = <int>[];
      await tester.pumpWidget(spanishApp(Scaffold(body: FlappyGame(onFinished: scores.add, seed: 1))));

      expect(find.text('TOCA PARA VOLAR'), findsOneWidget);
      await tester.tap(find.byType(FlappyGame));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(scores, [0]);
    });

    testWidgets('al llegar a la meta termina y avisa', (tester) async {
      final scores = <int>[];
      await tester.pumpWidget(
        spanishApp(Scaffold(body: FlappyGame(target: 0, onFinished: scores.add, seed: 1))),
      );

      await tester.tap(find.byType(FlappyGame));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(scores, hasLength(1));
    });
  });

  group('TicTacToeGame', () {
    Future<List<int>> open(WidgetTester tester, Map<String, dynamic> play, {bool enabled = true}) async {
      final moves = <int>[];
      await tester.pumpWidget(
        spanishApp(Scaffold(body: TicTacToeGame(play: play, enabled: enabled, onMove: moves.add))),
      );
      return moves;
    }

    testWidgets('un tablero vacío deja jugar en cualquier casilla', (tester) async {
      final moves = await open(tester, {'board': List.filled(9, '')});

      expect(find.text('TU TURNO · ERES LA X'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cell-4')));
      await tester.tap(find.byKey(const ValueKey('cell-0')));

      expect(moves, [4, 0]);
    });

    testWidgets('una casilla ocupada no se puede tocar', (tester) async {
      final moves = await open(tester, {'board': ['X', '', '', '', 'O', '', '', '', '']});

      await tester.tap(find.byKey(const ValueKey('cell-0')));
      await tester.tap(find.byKey(const ValueKey('cell-4')));

      expect(moves, isEmpty);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('mientras responde la computadora no se juega', (tester) async {
      final moves = await open(tester, {'board': List.filled(9, '')}, enabled: false);

      await tester.tap(find.byKey(const ValueKey('cell-2')));

      expect(moves, isEmpty);
      expect(find.text('JUEGA LA COMPUTADORA…'), findsOneWidget);
    });
  });

  group('HangmanGame', () {
    Future<List<String>> open(WidgetTester tester, Map<String, dynamic> play, {bool enabled = true}) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final guesses = <String>[];
      await tester.pumpWidget(
        spanishApp(Scaffold(body: SingleChildScrollView(child: HangmanGame(play: play, enabled: enabled, onGuess: guesses.add)))),
      );
      return guesses;
    }

    testWidgets('muestra los guiones, los errores y el teclado', (tester) async {
      await open(tester, {
        'masked': ['M', '_', '_', 'A'],
        'guessed': ['M', 'A', 'Z'],
        'wrong': 1,
        'maxWrong': 6,
      });

      expect(find.text('ERRORES: 1 DE 6'), findsOneWidget);
      expect(find.text('M'), findsWidgets);
      for (final l in ['A', 'B', 'Ñ', 'Z']) {
        expect(find.text(l), findsWidgets);
      }
    });

    testWidgets('tocar una letra la prueba; una ya usada no', (tester) async {
      final guesses = await open(tester, {
        'masked': ['_', '_'],
        'guessed': ['E'],
        'wrong': 1,
        'maxWrong': 6,
      });

      await tester.tap(find.widgetWithText(InkWell, 'B'));
      await tester.tap(find.widgetWithText(InkWell, 'E')); // ya probada

      expect(guesses, ['B']);
    });

    testWidgets('si perdió, muestra la palabra que faltaba', (tester) async {
      await open(tester, {
        'masked': ['_', '_', '_', '_'],
        'guessed': ['B', 'C', 'D', 'F', 'G', 'H'],
        'wrong': 6,
        'maxWrong': 6,
        'word': 'MESA',
      });

      for (final l in ['M', 'E', 'S', 'A']) {
        expect(find.descendant(of: find.byKey(const ValueKey('masked-word')), matching: find.text(l)), findsOneWidget);
      }
    });

    testWidgets('con la respuesta pendiente el teclado no responde', (tester) async {
      final guesses = await open(tester, {'masked': ['_'], 'guessed': <String>[], 'wrong': 0, 'maxWrong': 6}, enabled: false);

      await tester.tap(find.widgetWithText(InkWell, 'A'));

      expect(guesses, isEmpty);
    });
  });

  group('GameResultView', () {
    Future<void> open(WidgetTester tester, GamePlay play, {VoidCallback? onGifts}) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        spanishApp(Scaffold(body: GameResultView(play: play, onClose: () {}, onOpenGifts: onGifts))),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('ganó: celebra, muestra el premio y su código', (tester) async {
      var gifts = 0;
      await open(
        tester,
        _play(status: 'finished', result: 'won', claimCode: 'GFT-ZZ9988'),
        onGifts: () => gifts++,
      );

      expect(find.text('¡GANASTE!'), findsOneWidget);
      expect(find.text('Tu premio: 20% de descuento. Ya está en Mis regalos.'), findsOneWidget);
      expect(find.text('GFT-ZZ9988'), findsOneWidget);

      await tester.tap(find.text('VER MI REGALO'));
      expect(gifts, 1);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('ganó un premio que ya tenía: lo dice y no ofrece regalo', (tester) async {
      await open(tester, _play(status: 'finished', result: 'won'));

      expect(find.text('Ganaste, pero este premio ya lo tenías.'), findsOneWidget);
      expect(find.text('VER MI REGALO'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('perdió el último intento: Fido lo anima y avisa que ya usó los tres', (tester) async {
      await open(tester, _play(status: 'finished', result: 'lost', attempts: 3, attemptsLeft: 0));

      expect(find.text('ESTA VEZ NO'), findsOneWidget);
      expect(find.textContaining('Usaste tus 3 intentos'), findsOneWidget);
      // Fido lo acompaña triste.
      expect(find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'Fido triste'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('en Flappy cuenta los tubos que pasó', (tester) async {
      await open(tester, _play(game: GameKey.flappy, status: 'finished', result: 'lost', score: 4));

      expect(find.text('Pasaste 4 tubos.'), findsOneWidget);
    });
  });

  group('GameInviteScreen (el cliente abre el reto)', () {
    Future<_FakeGamesRepository> open(WidgetTester tester, GamePlay initial) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeGamesRepository(initial);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const GameInviteScreen(inviteId: 'i1')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return repo;
    }

    testWidgets('presenta el reto: quién lo manda, el juego y el premio', (tester) async {
      await open(tester, _play());

      expect(find.text('CAFÉ AURORA TE RETA A JUGAR'), findsOneWidget);
      expect(find.text('20% DE DESCUENTO'), findsOneWidget);
      expect(find.text('Tienes 3 intentos para ganar.'), findsOneWidget);
      expect(find.text('Te quedan 3 intentos'), findsOneWidget);
      expect(find.text('JUGAR'), findsOneWidget);
    });

    testWidgets('muestra hasta cuándo se puede jugar', (tester) async {
      await open(tester, _play(expiresAt: DateTime(2026, 12, 10, 18, 30)));

      expect(find.textContaining('Disponible hasta el'), findsOneWidget);
    });

    testWidgets('si perdió un intento y le quedan, puede intentarlo de nuevo', (tester) async {
      final repo = await open(
        tester,
        _play(attempts: 1, attemptsLeft: 2, lastAttempt: 'lost'),
      );

      expect(find.text('ESTA VEZ NO'), findsOneWidget);
      expect(find.textContaining('Perdiste ese intento'), findsOneWidget);
      expect(find.text('Te quedan 2 intentos'), findsOneWidget);
      expect(find.text('INTENTAR DE NUEVO'), findsOneWidget);
      expect(find.text('JUGAR'), findsNothing);

      repo.onStart = () => _play(
            status: 'playing',
            attempts: 2,
            attemptsLeft: 1,
            play: {'masked': ['_', '_'], 'guessed': <String>[], 'wrong': 0, 'maxWrong': 6},
          );
      await tester.tap(find.text('INTENTAR DE NUEVO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.calls, ['start']);
      expect(find.text('INTENTO 2 DE 3'), findsOneWidget);
    });

    testWidgets('con un solo intento restante lo dice en singular', (tester) async {
      await open(tester, _play(attempts: 2, attemptsLeft: 1, lastAttempt: 'lost'));

      expect(find.text('Te queda 1 intento'), findsOneWidget);
    });

    testWidgets('un juego programado todavía no se puede jugar', (tester) async {
      final repo = await open(
        tester,
        _play(status: 'upcoming', startsAt: DateTime.now().add(const Duration(hours: 3))),
      );

      expect(find.text('TODAVÍA NO EMPIEZA'), findsOneWidget);
      expect(find.textContaining('Este juego empieza el'), findsOneWidget);
      expect(find.text('JUGAR'), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('Ahorcado completo: empieza, adivina y gana su gift card', (tester) async {
      final repo = await open(tester, _play());
      repo.onStart = () => _play(
            status: 'playing',
            play: {'masked': ['_', '_'], 'guessed': <String>[], 'wrong': 0, 'maxWrong': 6},
          );
      repo.onGuess = (letter) => _play(
            status: 'finished',
            result: 'won',
            claimCode: 'GFT-LKDGV4',
            play: {'masked': ['S', 'I'], 'guessed': ['S', 'I'], 'wrong': 0, 'maxWrong': 6},
          );

      await tester.tap(find.text('JUGAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.calls, ['start']);
      expect(find.text('ERRORES: 0 DE 6'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'S'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.calls, ['start', 'guess:S']);
      expect(find.text('¡GANASTE!'), findsOneWidget);
      expect(find.text('GFT-LKDGV4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Tres en raya: la jugada va al servidor y se ve el tablero que devuelve', (tester) async {
      final repo = await open(tester, _play(game: GameKey.tictactoe, status: 'playing', play: {'board': List.filled(9, '')}));
      repo.onMove = (cell) => _play(
            game: GameKey.tictactoe,
            status: 'playing',
            play: {'board': ['', '', '', '', 'X', '', '', '', 'O']},
          );

      await tester.tap(find.byKey(const ValueKey('cell-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.calls, ['move:4']);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('Tres en raya perdido: muestra "esta vez no" sin gift card', (tester) async {
      final repo = await open(tester, _play(game: GameKey.tictactoe, status: 'playing', play: {'board': List.filled(9, '')}));
      repo.onMove = (_) => _play(game: GameKey.tictactoe, status: 'finished', result: 'lost');

      await tester.tap(find.byKey(const ValueKey('cell-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ESTA VEZ NO'), findsOneWidget);
    });

    testWidgets('un reto ya jugado abre directo el resultado', (tester) async {
      await open(tester, _play(status: 'finished', result: 'lost'));

      expect(find.text('ESTA VEZ NO'), findsOneWidget);
      expect(find.text('JUGAR'), findsNothing);
    });

    testWidgets('un reto vencido lo explica', (tester) async {
      await open(tester, _play(status: 'expired'));

      expect(find.text('RETO VENCIDO'), findsOneWidget);
    });

    testWidgets('si la jugada falla muestra el error y vuelve a leer el reto', (tester) async {
      final repo = await open(tester, _play(game: GameKey.tictactoe, status: 'playing', play: {'board': List.filled(9, '')}));
      repo.onMove = (_) => throw Exception('Esa casilla ya está ocupada');

      await tester.tap(find.byKey(const ValueKey('cell-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('ocupada'), findsOneWidget);
      expect(find.byKey(const ValueKey('cell-4')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('FidoBannerCarousel (juegos pendientes en el inicio)', () {
    Future<void> open(WidgetTester tester, List<GameInvite> invites) async {
      final repo = _FakeGamesRepository(_play())..invites = invites;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const Scaffold(body: FidoBannerCarousel(autoPlay: false))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    GameInvite invite(String id, String status, {String game = 'hangman', String name = 'Ahorcado'}) => GameInvite(
          id: id,
          game: GameKey.parse(game),
          gameName: name,
          status: status,
          businessName: 'Café Aurora',
          prizeLabel: '20% de descuento',
        );

    testWidgets('muestra solo los retos que se pueden jugar, uno por mensaje', (tester) async {
      await open(tester, [
        invite('1', 'sent'),
        invite('2', 'finished'),
        invite('3', 'expired'),
        invite('4', 'playing', game: 'flappy', name: 'Flappy Bird'),
      ]);

      expect(find.text('JUEGA Y GANA'), findsOneWidget);
      expect(find.textContaining('Ahorcado de Café Aurora'), findsOneWidget);
      expect(find.text('JUGAR'), findsOneWidget);

      // El segundo reto está al deslizar; los terminados y vencidos nunca salen.
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flappy Bird de Café Aurora'), findsOneWidget);
      expect(find.textContaining('Te quedan'), findsOneWidget);
    });

    testWidgets('sin retos abiertos no ocupa espacio', (tester) async {
      await open(tester, [invite('1', 'finished')]);

      expect(find.text('JUEGA Y GANA'), findsNothing);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('tocar un reto abre su juego', (tester) async {
      await open(tester, [invite('1', 'sent')]);

      await tester.tap(find.text('JUGAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GameInviteScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 6)); // deja terminar las animaciones
    });
  });
}
