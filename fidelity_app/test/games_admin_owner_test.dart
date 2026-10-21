import 'package:fidelity_app/features/admin/admin_games_screen.dart';
import 'package:fidelity_app/features/admin/widgets/admin_widgets.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:fidelity_app/features/games/games_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

class _FakeGamesRepository extends GamesRepository {
  GameAccess current;
  List<GameAccess> requestList = [];
  SentGames sentGames = const SentGames();
  SendResult sendResult = const SendResult(sent: 2, skipped: 0);

  final List<Map<String, Object?>> requested = [];
  final List<Map<String, Object?>> sends = [];
  final List<Map<String, Object?>> approvals = [];
  final List<Map<String, Object?>> rejections = [];

  _FakeGamesRepository(this.current);

  @override
  Future<GameAccess> access(String businessId) async => current;

  @override
  Future<GameAccess> request(String businessId, {String? note}) async {
    requested.add({'businessId': businessId, 'note': note});
    return current;
  }

  @override
  Future<SendResult> send(
    String businessId,
    GameKey game, {
    bool selected = false,
    List<String> recipientIds = const [],
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    sends.add({
      'game': game,
      'selected': selected,
      'recipientIds': recipientIds,
      'startsAt': startsAt,
      'endsAt': endsAt,
    });
    return sendResult;
  }

  @override
  Future<SentGames> sent(String businessId) async => sentGames;

  @override
  Future<List<GameAccess>> requests({String? status}) async => requestList;

  @override
  Future<void> approve(
    String id, {
    required List<GameKey> games,
    required bool discount,
    int? value,
    String? label,
  }) async {
    approvals.add({'id': id, 'games': games, 'discount': discount, 'value': value, 'label': label});
  }

  @override
  Future<void> reject(String id, String reason) async {
    rejections.add({'id': id, 'reason': reason});
  }
}

class _FakeCampaignsRepository extends CampaignsRepository {
  @override
  Future<List<CampaignCustomer>> customers(List<String> businessIds, {String? query}) async => const [
        CampaignCustomer(id: 'u1', fullName: 'Ana Paz', email: 'ana@mail.com'),
        CampaignCustomer(id: 'u2', fullName: 'Luis Mora', email: 'luis@mail.com'),
      ];
}

GameAccess _access(
  GameAccessStatus status, {
  String id = 'a1',
  String name = 'Café Aurora',
  List<GameKey> games = const [],
  GamePrize? prize,
  String? adminNote,
  String? note,
}) =>
    GameAccess(
      id: id,
      businessId: 'b1',
      status: status,
      games: games,
      prize: prize,
      adminNote: adminNote,
      note: note,
      businessName: name,
      ownerName: 'Aurora Zhuma',
      ownerEmail: 'aurora@mail.com',
    );

const _prize = GamePrize(type: 'discount_percent', value: 25, label: '25% de descuento');

Finder _pill(String label) =>
    find.byWidgetPredicate((w) => w is AdminFilterPill && w.label == label);

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GamesTab (el dueño)', () {
    Future<_FakeGamesRepository> open(WidgetTester tester, GameAccess access, {SentGames? sent}) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeGamesRepository(access);
      if (sent != null) repo.sentGames = sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamesRepositoryProvider.overrideWithValue(repo),
            campaignsRepositoryProvider.overrideWithValue(_FakeCampaignsRepository()),
          ],
          child: spanishApp(const Scaffold(body: GamesTab(businessId: 'b1'))),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('sin solicitud ofrece pedirlos al administrador', (tester) async {
      final repo = await open(tester, _access(GameAccessStatus.none));

      expect(find.textContaining('Pídelos al administrador'), findsOneWidget);

      await tester.tap(find.text('SOLICITAR MINIJUEGOS'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Quiero atraer más clientes');
      await tester.tap(find.text('SOLICITAR'));
      await tester.pumpAndSettle();

      expect(repo.requested, [
        {'businessId': 'b1', 'note': 'Quiero atraer más clientes'}
      ]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('cancelar el diálogo no envía nada', (tester) async {
      final repo = await open(tester, _access(GameAccessStatus.none));

      await tester.tap(find.text('SOLICITAR MINIJUEGOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.requested, isEmpty);
    });

    testWidgets('en revisión avisa que se espera al administrador', (tester) async {
      await open(tester, _access(GameAccessStatus.pending));

      expect(find.textContaining('está en revisión'), findsOneWidget);
      expect(find.text('SOLICITAR MINIJUEGOS'), findsNothing);
    });

    testWidgets('rechazada muestra el motivo y permite volver a pedirlos', (tester) async {
      await open(tester, _access(GameAccessStatus.rejected, adminNote: 'Aún no cumples los requisitos'));

      expect(find.textContaining('Aún no cumples los requisitos'), findsOneWidget);
      expect(find.text('VOLVER A SOLICITAR'), findsOneWidget);
    });

    testWidgets('aprobada: muestra el premio que fijó el admin y solo los juegos asignados', (tester) async {
      await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman, GameKey.flappy], prize: _prize),
      );

      expect(find.text('25% DE DESCUENTO'), findsOneWidget);
      expect(find.text('Lo fija el administrador. Quien gana recibe una gift card.'), findsOneWidget);
      expect(find.text('Ahorcado'), findsOneWidget);
      expect(find.text('Flappy Bird'), findsOneWidget);
      expect(find.text('Tres en raya'), findsNothing);
      expect(find.text('ENVIAR'), findsNWidgets(2));
    });

    testWidgets('enviar un juego a todos los clientes', (tester) async {
      final repo = await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize),
      );

      await tester.tap(find.text('ENVIAR'));
      await tester.pumpAndSettle();
      expect(find.text('ENVIAR AHORCADO'), findsOneWidget);

      await tester.tap(find.text('ENVIAR JUEGO'));
      await tester.pumpAndSettle();

      // Sin tocar el horario: empieza ya y dura lo de siempre (lo decide el servidor).
      expect(repo.sends, [
        {
          'game': GameKey.hangman,
          'selected': false,
          'recipientIds': <String>[],
          'startsAt': null,
          'endsAt': null,
        }
      ]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('la hoja de envío deja poner cuándo empieza y cuándo termina', (tester) async {
      await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize),
      );

      await tester.tap(find.text('ENVIAR'));
      await tester.pumpAndSettle();

      expect(find.text('¿CUÁNDO SE PUEDE JUGAR?'), findsOneWidget);
      expect(find.textContaining('3 intentos para ganar'), findsOneWidget);
      expect(_pill('Ahora'), findsOneWidget);
      expect(_pill('Programar'), findsOneWidget);
      expect(_pill('En 7 días'), findsOneWidget);
      expect(_pill('Elegir fecha'), findsOneWidget);
    });

    testWidgets('programar el inicio o elegir el fin sin poner la fecha no deja enviar', (tester) async {
      final repo = await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize),
      );

      await tester.tap(find.text('ENVIAR'));
      await tester.pumpAndSettle();

      // "Programar" abre el selector de fecha; se cierra sin elegir nada.
      await tester.tap(_pill('Programar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR JUEGO'));
      await tester.pumpAndSettle();
      expect(find.text('Elige cuándo empieza el juego.'), findsOneWidget);

      await tester.tap(_pill('Ahora'));
      await tester.pumpAndSettle();
      await tester.tap(_pill('Elegir fecha'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR JUEGO'));
      await tester.pumpAndSettle();
      expect(find.text('Elige cuándo termina el juego.'), findsOneWidget);

      expect(repo.sends, isEmpty);
    });

    testWidgets('la lista del dueño muestra los intentos y los juegos programados', (tester) async {
      await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize),
        sent: const SentGames(sent: 3, played: 1, won: 0, items: [
          SentGame(gameName: 'Ahorcado', userName: 'Ana', status: 'sent', attempts: 2),
          SentGame(gameName: 'Ahorcado', userName: 'Luis', status: 'upcoming'),
          SentGame(gameName: 'Ahorcado', userName: 'Zoe', status: 'finished', result: 'lost', attempts: 3),
        ]),
      );

      expect(find.text('INTENTO 2 DE 3'), findsOneWidget);
      expect(find.text('PROGRAMADO'), findsOneWidget);
      expect(find.text('PERDIÓ'), findsOneWidget);
    });

    testWidgets('enviar solo a clientes elegidos exige elegir al menos uno', (tester) async {
      final repo = await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.tictactoe], prize: _prize),
      );

      await tester.tap(find.text('ENVIAR'));
      await tester.pumpAndSettle();
      await tester.tap(_pill('Clientes elegidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR JUEGO'));
      await tester.pumpAndSettle();

      expect(find.text('Elige al menos un cliente.'), findsOneWidget);
      expect(repo.sends, isEmpty);

      await tester.tap(find.text('ELEGIR CLIENTES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Paz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR JUEGO'));
      await tester.pumpAndSettle();

      expect(repo.sends.single['selected'], true);
      expect(repo.sends.single['recipientIds'], ['u1']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('muestra cuántos enviaron, jugaron y ganaron', (tester) async {
      await open(
        tester,
        _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize),
        sent: const SentGames(
          sent: 5,
          played: 3,
          won: 1,
          items: [
            SentGame(gameName: 'Ahorcado', userName: 'Ana Paz', status: 'finished', result: 'won'),
            SentGame(gameName: 'Ahorcado', userName: 'Luis Mora', status: 'sent'),
          ],
        ),
      );

      expect(find.text('ENVIADOS'), findsOneWidget);
      expect(find.text('JUGARON'), findsOneWidget);
      expect(find.text('GANARON'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Ana Paz · Ahorcado'), findsOneWidget);
      expect(find.text('GANÓ'), findsOneWidget);
    });

    testWidgets('sin envíos lo explica', (tester) async {
      await open(tester, _access(GameAccessStatus.approved, games: [GameKey.hangman], prize: _prize));

      expect(find.textContaining('Todavía no has mandado ningún juego'), findsOneWidget);
    });
  });

  group('AdminGamesScreen (el administrador)', () {
    Future<_FakeGamesRepository> open(WidgetTester tester, List<GameAccess> list) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeGamesRepository(_access(GameAccessStatus.none))..requestList = list;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const AdminGamesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    final list = [
      _access(GameAccessStatus.pending, id: 'p1', name: 'Café Aurora', note: 'Quiero sorprender a mis clientes'),
      _access(GameAccessStatus.approved, id: 'p2', name: 'Barbería Pop', games: [GameKey.hangman], prize: _prize),
      _access(GameAccessStatus.rejected, id: 'p3', name: 'Pizzería Luna', adminNote: 'No'),
    ];

    testWidgets('por defecto muestra lo que falta revisar, con su contador', (tester) async {
      await open(tester, list);

      expect(_pill('Por revisar (1)'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('Aurora Zhuma · aurora@mail.com'), findsOneWidget);
      expect(find.text('Quiero sorprender a mis clientes'), findsOneWidget);
      expect(find.text('BARBERÍA POP'), findsNothing);
    });

    testWidgets('los filtros separan activos, rechazados y todos', (tester) async {
      await open(tester, list);

      await tester.tap(_pill('Activos'));
      await tester.pumpAndSettle();
      expect(find.text('BARBERÍA POP'), findsOneWidget);
      expect(find.text('AHORCADO'), findsOneWidget);
      expect(find.text('25% DE DESCUENTO'), findsOneWidget);

      await tester.tap(_pill('Rechazados'));
      await tester.pumpAndSettle();
      expect(find.text('PIZZERÍA LUNA'), findsOneWidget);

      await tester.tap(_pill('Todos'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminFilterPill), findsNWidgets(4));
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('BARBERÍA POP'), findsOneWidget);
    });

    testWidgets('sin solicitudes lo dice', (tester) async {
      await open(tester, const []);

      expect(find.text('SIN SOLICITUDES'), findsOneWidget);
    });

    testWidgets('aprobar: por defecto asigna los 3 juegos con un descuento', (tester) async {
      final repo = await open(tester, list);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();

      expect(repo.approvals, hasLength(1));
      final a = repo.approvals.single;
      expect(a['id'], 'p1');
      expect(a['games'], [GameKey.tictactoe, GameKey.hangman, GameKey.flappy]);
      expect(a['discount'], true);
      expect(a['value'], 20);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el admin elige los juegos y el premio', (tester) async {
      final repo = await open(tester, list);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.tap(_pill('Tres en raya')); // la quita
      await tester.tap(_pill('Flappy Bird')); // la quita
      await tester.tap(_pill('Mini premio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Mini premio (ej. Café pequeño gratis)'), ' Café gratis ');
      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();

      final a = repo.approvals.single;
      expect(a['games'], [GameKey.hangman]);
      expect(a['discount'], false);
      expect(a['label'], ' Café gratis ');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un descuento fuera de rango o sin juegos no se aprueba', (tester) async {
      final repo = await open(tester, list);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '20'), '150');
      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un valor entre 1 y 100'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '150'), '30');
      for (final g in ['Tres en raya', 'Ahorcado', 'Flappy Bird']) {
        await tester.tap(_pill(g));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('APROBAR'));
      await tester.pumpAndSettle();
      expect(find.text('Asigna al menos un juego.'), findsOneWidget);
      expect(repo.approvals, isEmpty);
    });

    testWidgets('rechazar pide un motivo', (tester) async {
      final repo = await open(tester, list);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('RECHAZAR SOLICITUD'), findsOneWidget);

      // Sin motivo no se rechaza.
      await tester.tap(find.widgetWithText(ElevatedButton, 'RECHAZAR'));
      await tester.pumpAndSettle();
      expect(repo.rejections, isEmpty);

      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog).last, matching: find.byType(TextFormField)),
        'Aún no tienes clientes',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'RECHAZAR'));
      await tester.pumpAndSettle();

      expect(repo.rejections, [
        {'id': 'p1', 'reason': 'Aún no tienes clientes'}
      ]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un negocio activo se puede editar o retirar', (tester) async {
      final repo = await open(tester, list);

      await tester.tap(_pill('Activos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BARBERÍA POP'));
      await tester.pumpAndSettle();

      // Trae sus juegos y su premio actuales.
      expect(find.text('GUARDAR'), findsOneWidget);
      expect(find.text('RETIRAR'), findsNothing); // el botón de retirar es de texto, no el del diálogo
      expect(find.widgetWithText(TextFormField, '25'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '25'), '40');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      final a = repo.approvals.single;
      expect(a['games'], [GameKey.hangman]);
      expect(a['value'], 40);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
