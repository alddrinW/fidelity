import 'package:fidelity_app/features/cards/widgets/missions_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

Finder stamps(String kind) => find.byWidgetPredicate(
      (w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('stamp-$kind-'),
    );

Map<String, dynamic> card({
  String name = 'Café Aurora',
  int points = 3,
  int required = 10,
  String? reward = 'Café gratis',
  List<Map<String, dynamic>> rewards = const [],
  int pendingScans = 0,
  String? logo,
}) =>
    {
      'id': 'c-$name',
      'current_points': points,
      'pending_scans': pendingScans,
      'rewards': rewards,
      'businesses': {
        'id': 'b-$name',
        'name': name,
        'points_required': required,
        'reward_description': reward,
        'logo_url': logo,
        'business_categories': {'name': 'Cafeterías'},
      },
    };

/// Un PNG de 1x1 en data URI: sirve para comprobar que el logo se pinta.
const tinyLogo =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Mission', () {
    test('lee el avance de una tarjeta', () {
      final m = Mission.fromCard(card(points: 3, required: 10));

      expect(m.name, 'Café Aurora');
      expect(m.points, 3);
      expect(m.required, 10);
      expect(m.progress, 0.3);
      expect(m.pointsLeft, 7);
      expect(m.reward, 'Café gratis');
      expect(m.hasReadyReward, isFalse);
    });

    test('un premio sin entregar cuenta como premio listo; uno entregado no', () {
      final ready = Mission.fromCard(card(rewards: [
        {'status': 'pending'},
        {'status': 'approved'},
      ]));

      expect(ready.readyRewards, 1);
      expect(ready.hasReadyReward, isTrue);
    });

    test('datos faltantes no rompen la ruta', () {
      final m = Mission.fromCard({'current_points': 2, 'businesses': {'name': 'X', 'points_required': 0}});

      expect(m.required, 1); // nunca divide por cero
      expect(m.progress, 1.0);
      expect(m.reward, isNull);
    });

    test('el avance nunca pasa de 100 %', () {
      expect(Mission.fromCard(card(points: 14, required: 10)).progress, 1.0);
    });
  });

  group('nextMission', () {
    test('sin misiones no hay próxima', () {
      expect(nextMission(const []), isNull);
    });

    test('destaca la que está más cerca de completarse', () {
      final missions = [
        Mission.fromCard(card(name: 'A', points: 2, required: 10)),
        Mission.fromCard(card(name: 'B', points: 8, required: 10)),
        Mission.fromCard(card(name: 'C', points: 5, required: 10)),
      ];

      expect(nextMission(missions)!.name, 'B');
    });

    test('un premio listo manda sobre el avance', () {
      final missions = [
        Mission.fromCard(card(name: 'A', points: 9, required: 10)),
        Mission.fromCard(card(name: 'B', points: 0, required: 10, rewards: [
          {'status': 'pending'}
        ])),
      ];

      expect(nextMission(missions)!.name, 'B');
    });
  });

  group('MissionsRoute', () {
    Future<List<Mission>> open(
      WidgetTester tester,
      List<Map<String, dynamic>> cards, {
      Size size = const Size(390, 900),
      ValueChanged<Mission>? onOpen,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final missions = [for (final c in cards) Mission.fromCard(c)];
      await tester.pumpWidget(
        spanishApp(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: MissionsRoute(missions: missions, onOpen: onOpen ?? (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return missions;
    }

    testWidgets('muestra cada negocio como un nodo con su avance', (tester) async {
      await open(tester, [
        card(name: 'Café Aurora', points: 3, required: 10),
        card(name: 'Barbería Pop', points: 1, required: 5, reward: 'Corte gratis'),
      ]);

      expect(find.text('MI RUTA DE MISIONES'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('BARBERÍA POP'), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets('el aviso dice cuánto falta para el próximo premio', (tester) async {
      await open(tester, [
        card(name: 'Café Aurora', points: 3, required: 10),
        card(name: 'Barbería Pop', points: 4, required: 5, reward: 'Corte gratis'),
      ]);

      expect(find.text('¡Te falta 1 punto en Barbería Pop!'), findsOneWidget);
      expect(find.text('Y ganas: Corte gratis'), findsOneWidget);
    });

    testWidgets('un premio listo se avisa y se marca', (tester) async {
      await open(tester, [
        card(name: 'Café Aurora', points: 0, rewards: [
          {'status': 'pending'}
        ]),
      ]);

      expect(find.text('¡Premio listo en Café Aurora!'), findsOneWidget);
      expect(find.text('PREMIO LISTO'), findsOneWidget);
      expect(find.byIcon(Icons.card_giftcard_rounded), findsWidgets);
    });

    testWidgets('un escaneo pendiente se indica junto al avance', (tester) async {
      await open(tester, [card(points: 2, required: 10, pendingScans: 1)]);

      expect(find.text('2/10 · PENDIENTE'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('los sellos reflejan los puntos ganados y los que faltan', (tester) async {
      await open(tester, [card(points: 3, required: 6)]);

      expect(stamps('on'), findsNWidgets(3));
      expect(stamps('off'), findsNWidgets(3));
    });

    testWidgets('con muchos sellos se resume en una barra', (tester) async {
      await open(tester, [card(points: 5, required: 20)]);

      expect(stamps('on'), findsNothing);
      expect(find.byType(ProgressBar), findsWidgets);
    });

    testWidgets('el nodo muestra el logo completo y sin anillo de avance', (tester) async {
      await open(tester, [card(name: 'Café Aurora', logo: tinyLogo)]);

      final node = find.byType(MissionNode);

      // El logo entra entero: no se recorta.
      final image = tester.widget<Image>(
        find.descendant(of: node, matching: find.byType(Image)),
      );
      expect(image.fit, BoxFit.contain);

      // Y ya no hay anillo de progreso alrededor.
      expect(
        find.descendant(of: node, matching: find.byType(CustomPaint)),
        findsNothing,
      );
    });

    testWidgets('tocar un nodo abre su tarjeta', (tester) async {
      Mission? opened;
      await open(
        tester,
        [card(name: 'Café Aurora')],
        onOpen: (m) => opened = m,
      );

      await tester.tap(find.byType(MissionNode));
      expect(opened?.name, 'Café Aurora');

      opened = null;
      await tester.tap(find.byType(NextRewardBanner));
      expect(opened?.name, 'Café Aurora');
    });

    testWidgets('cabe en un celular angosto con varios negocios (sin desbordes)', (tester) async {
      await open(
        tester,
        [
          for (var i = 0; i < 6; i++)
            card(name: 'Negocio con un nombre bastante largo $i', points: i, required: 8, reward: 'Un premio con descripción larga'),
        ],
        size: const Size(340, 900),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MissionNode), findsNWidgets(6));
    });
  });
}
