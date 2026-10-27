import 'package:fidelity_app/core/theme/app_colors.dart';
import 'package:fidelity_app/core/widgets/app_empty_state.dart';
import 'package:fidelity_app/core/widgets/app_message_dialog.dart';
import 'package:fidelity_app/core/widgets/fido_mascot.dart';
import 'package:fidelity_app/features/business/dashboard/widgets/fido_guide_strip.dart';
import 'package:fidelity_app/features/cards/card_history_screen.dart';
import 'package:fidelity_app/features/cards/providers/my_cards_provider.dart';
import 'package:fidelity_app/features/scanner/data/scanner_repository.dart';
import 'package:fidelity_app/features/scanner/scan_success_screen.dart';
import 'package:fidelity_app/features/scanner/scan_waiting_screen.dart';
import 'package:fidelity_app/features/scanner/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Las tarjetas del cliente de mentira (y cuántas veces se pidió refrescarlas).
class _FakeCards extends MyCardsNotifier {
  final List<Map<String, dynamic>> initial;
  int refreshed = 0;

  _FakeCards(this.initial);

  @override
  MyCardsState build() => MyCardsState(isLoading: false, cards: initial);

  @override
  Future<void> refreshCards({bool silent = false}) async => refreshed++;
}

String? _assetOf(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image).first);
  return (image.image as AssetImage).assetName;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FidoMascot', () {
    testWidgets('en calma y pensativo usa la pose neutra', (tester) async {
      for (final mood in [FidoMood.calm, FidoMood.thinking]) {
        await tester.pumpWidget(spanishApp(FidoMascot(mood: mood, height: 80)));
        expect(_assetOf(tester), 'assets/images/logo_transparente.png');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('al celebrar o en euforia usa la pose de brazos arriba', (tester) async {
      for (final mood in [FidoMood.celebrate, FidoMood.euphoric]) {
        await tester.pumpWidget(spanishApp(FidoMascot(mood: mood, height: 80)));
        expect(_assetOf(tester), 'assets/images/fido_celebra.png');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('sus animaciones terminan solas (no giran para siempre)', (tester) async {
      for (final mood in FidoMood.values) {
        await tester.pumpWidget(spanishApp(FidoMascot(mood: mood, height: 80)));
        // pumpAndSettle falla por tiempo si la animación no termina.
        await tester.pumpAndSettle();
      }
    });

    testWidgets('con movimiento reducido se queda quieto', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: spanishApp(const FidoMascot(mood: FidoMood.euphoric, height: 80)),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('el estado vacío muestra a Fido en calma', (tester) async {
    await tester.pumpWidget(
      spanishApp(const AppEmptyState(title: 'Sin pagos', message: 'No hay pagos.')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FidoMascot), findsOneWidget);
    expect(find.text('SIN PAGOS'), findsOneWidget);
  });

  group('tiempo de espera (cooldown)', () {
    test('el mensaje del servidor se dice con calma', () {
      expect(
        friendlyCooldownMessage('Ya escaneaste en Café Aurora. Vuelve en 3h 20min'),
        'Tu próximo punto en Café Aurora estará listo en 3h 20min.',
      );
    });

    test('un mensaje con otro formato se muestra tal cual', () {
      expect(friendlyCooldownMessage('Algo distinto'), 'Algo distinto');
    });

    testWidgets('Fido pensativo y el reloj de arena acompañan el aviso', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        spanishApp(
          const AppMessageDialog(
            icon: Icons.hourglass_top_rounded,
            leading: FidoCooldownBanner(),
            title: '¡Paciencia!',
            message: 'Tu próximo punto en Café Aurora estará listo en 3h 20min.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FidoCooldownBanner), findsOneWidget);
      expect(find.byType(FidoHourglass), findsOneWidget);
      expect(find.text('¡PACIENCIA!'), findsOneWidget);
      expect(find.text('Tu próximo punto en Café Aurora estará listo en 3h 20min.'), findsOneWidget);
    });
  });

  group('escaneo exitoso', () {
    Future<void> open(WidgetTester tester, ScanResult result) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(child: spanishApp(ScanSuccessScreen(result: result))),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('un punto sumado: Fido celebra y anima', (tester) async {
      await open(
        tester,
        const ScanResult(businessName: 'Café Aurora', currentPoints: 3, pointsRequired: 10),
      );

      expect(
        find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.celebrate),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un premio ganado: Fido se emociona', (tester) async {
      await open(
        tester,
        const ScanResult(
          businessName: 'Café Aurora',
          rewardCompleted: true,
          rewardDescription: 'Café gratis',
        ),
      );

      expect(
        find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.euphoric),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un escaneo pendiente: Fido triste, sin confeti', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', isPending: true));

      expect(
        find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.sad),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('resultado del escaneo (pantalla completa)', () {
    late _FakeCards cards;

    Future<void> open(WidgetTester tester, ScanResult result, {List<Map<String, dynamic>> myCards = const []}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      cards = _FakeCards(myCards);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myCardsProvider.overrideWith(() => cards)],
          child: spanishApp(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ScanSuccessScreen(result: result)),
                    ),
                    child: const Text('inicio'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('inicio'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Map<String, dynamic> card({String id = 'c1', String businessId = 'b1'}) => {
          'id': id,
          'current_points': 3,
          'rewards': const [],
          'businesses': {'id': businessId, 'name': 'Café Aurora', 'points_required': 10},
        };

    testWidgets('un punto sumado: fondo rosa, el local, los puntitos, "3 de 10 puntos" y VER MI TARJETA', (tester) async {
      await open(tester, const ScanResult(businessId: 'b1', businessName: 'Café Aurora', currentPoints: 3, pointsRequired: 10));

      expect(find.text('¡PUNTO\nSUMADO!'), findsOneWidget);
      expect(find.text('Café Aurora'), findsOneWidget);
      expect(find.byType(ScanProgressDots), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      expect(find.text('3 de 10 puntos'), findsOneWidget);
      expect(find.text('VER MI TARJETA'), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, AppColors.pink);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('tarjeta completa: "¡COMPLETASTE TU TARJETA!", el premio en una caja negra y VER MI PREMIO', (tester) async {
      await open(
        tester,
        const ScanResult(businessId: 'b1', businessName: 'Café Aurora', pointsRequired: 5, rewardCompleted: true, rewardDescription: 'Café gratis'),
      );

      expect(find.text('¡COMPLETASTE\nTU TARJETA!'), findsOneWidget);
      expect(find.text('Café gratis en Café Aurora. Pídelo en el local mostrando tu premio.'), findsOneWidget);
      // La caja negra lleva el premio (no un código: los premios de puntos no tienen).
      expect(find.text('TU PREMIO'), findsOneWidget);
      expect(find.text('CAFÉ GRATIS'), findsOneWidget);
      expect(find.text('VER MI PREMIO'), findsOneWidget);
      expect(find.text('VER MI TARJETA'), findsNothing);
      expect(find.byType(ScanProgressDots), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('si el local no describió el premio, la caja dice "Premio ganado"', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', pointsRequired: 5, rewardCompleted: true));

      expect(find.text('Ganaste un premio en Café Aurora. Pídelo en el local mostrando tu premio.'), findsOneWidget);
      expect(find.text('PREMIO GANADO'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un escaneo pendiente: fondo blanco, Fido triste, el aviso, "Suele tardar unos minutos" y ENTENDIDO', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', isPending: true, pointsRequired: 10));

      expect(find.text('ESPERANDO\nAL LOCAL'), findsOneWidget);
      expect(find.text('Tu escaneo en Café Aurora está pendiente. Te avisaremos cuando lo aprueben.'), findsOneWidget);
      expect(find.text('Suele tardar unos minutos'), findsOneWidget);
      expect(find.text('ENTENDIDO'), findsOneWidget);
      expect(find.byType(ScanProgressDots), findsNothing);
      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, AppColors.white);

      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanSuccessScreen), findsNothing);
      expect(find.text('inicio'), findsOneWidget);
    });

    testWidgets('VER MI TARJETA vuelve al inicio y abre la tarjeta de ese local', (tester) async {
      await open(
        tester,
        const ScanResult(businessId: 'b1', businessName: 'Café Aurora', currentPoints: 3, pointsRequired: 10),
        myCards: [card(), card(id: 'c2', businessId: 'b2')],
      );

      await tester.tap(find.text('VER MI TARJETA'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ScanSuccessScreen), findsNothing);
      final screen = tester.widget<CardHistoryScreen>(find.byType(CardHistoryScreen));
      expect(screen.loyaltyCardId, 'c1');
      expect(screen.businessId, 'b1');
      expect(screen.businessName, 'Café Aurora');
      expect(screen.initialTabIndex, CardHistoryScreen.rewardsTab);
      expect(cards.refreshed, greaterThan(0));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('VER MI PREMIO abre la tarjeta en la pestaña de premios', (tester) async {
      await open(
        tester,
        const ScanResult(businessId: 'b1', businessName: 'Café Aurora', pointsRequired: 10, rewardCompleted: true, rewardDescription: 'Café gratis'),
        myCards: [card()],
      );

      await tester.tap(find.text('VER MI PREMIO'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.widget<CardHistoryScreen>(find.byType(CardHistoryScreen)).initialTabIndex, CardHistoryScreen.rewardsTab);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('si la tarjeta no se encuentra, igual vuelve al inicio sin romperse', (tester) async {
      await open(tester, const ScanResult(businessId: 'b9', businessName: 'Otro', currentPoints: 1, pointsRequired: 10), myCards: [card()]);

      await tester.tap(find.text('VER MI TARJETA'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CardHistoryScreen), findsNothing);
      expect(find.text('inicio'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('en inglés, las tres pantallas salen traducidas', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> show(ScanResult r) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: ScanSuccessScreen(result: r),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
      }

      await show(const ScanResult(businessName: 'Café Aurora', currentPoints: 3, pointsRequired: 10));
      expect(find.text('POINT\nADDED!'), findsOneWidget);
      expect(find.text('3 of 10 points'), findsOneWidget);
      expect(find.text('SEE MY CARD'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));

      await show(const ScanResult(businessName: 'Café Aurora', rewardCompleted: true, rewardDescription: 'Free coffee'));
      expect(find.text('YOU COMPLETED\nYOUR CARD!'), findsOneWidget);
      expect(find.text('YOUR PRIZE'), findsOneWidget);
      expect(find.text('SEE MY PRIZE'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));

      await show(const ScanResult(businessName: 'Café Aurora', isPending: true));
      expect(find.text('WAITING FOR\nTHE BUSINESS'), findsOneWidget);
      expect(find.text('Your scan at Café Aurora is pending. We will let you know when they approve it.'), findsOneWidget);
      expect(find.text('It usually takes a few minutes'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('con muchos sellos los puntitos pasan a una barra', (tester) async {
      await tester.pumpWidget(spanishApp(const Scaffold(body: ScanProgressDots(done: 5, total: 30))));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('sobre el rosa los puntos ganados van negros', (tester) async {
      await tester.pumpWidget(spanishApp(const Scaffold(body: ScanProgressDots(done: 2, total: 4, onPink: true))));
      await tester.pump();

      // Los dos puntos ganados llevan el visto en blanco (sobre negro); sobre blanco iría negro.
      final ticks = tester.widgetList<Icon>(find.byIcon(Icons.check_rounded)).toList();
      expect(ticks.length, 2);
      expect(ticks.every((i) => i.color == AppColors.white), isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('la pantalla de espera muestra lo que dijo el servidor, Fido triste y vuelve con ENTENDIDO', (tester) async {
      await tester.pumpWidget(spanishApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScanWaitingScreen(message: 'Tu escaneo en Café Aurora espera su aprobación.'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('ESPERANDO\nAL LOCAL'), findsOneWidget);
      expect(find.text('Tu escaneo en Café Aurora espera su aprobación.'), findsOneWidget);
      expect(find.text('Suele tardar unos minutos'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.sad), findsOneWidget);

      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanWaitingScreen), findsNothing);
    });
  });

  group('guía de Fido para el dueño', () {
    testWidgets('cabe en un celular angosto con 3 accesos y un mensaje largo', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        spanishApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FidoGuideStrip(
                message: 'Tienes 12 escaneos por aprobar. Apruébalos para que tus clientes sumen su punto.',
                onDismiss: () {},
                actions: [
                  FidoGuideAction(label: 'Aprobar escaneos', icon: Icons.pending_actions_rounded, onTap: () {}),
                  FidoGuideAction(label: 'Crear campaña', icon: Icons.campaign_outlined, onTap: () {}),
                  FidoGuideAction(label: 'Mis sucursales', icon: Icons.account_tree_outlined, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Un desbordamiento (overflow) haría fallar la prueba.
      expect(tester.takeException(), isNull);
      expect(find.text('Aprobar escaneos'), findsOneWidget);
    });

    testWidgets('muestra el mensaje, ofrece accesos directos y se puede cerrar', (tester) async {
      var created = 0;
      var dismissed = 0;

      await tester.pumpWidget(
        spanishApp(
          Scaffold(
            body: FidoGuideStrip(
              message: '¡Hola Ana! ¿Qué hacemos hoy?',
              onDismiss: () => dismissed++,
              actions: [
                FidoGuideAction(
                  label: 'Crear campaña',
                  icon: Icons.campaign_outlined,
                  onTap: () => created++,
                ),
                FidoGuideAction(
                  label: 'Mis sucursales',
                  icon: Icons.account_tree_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¡Hola Ana! ¿Qué hacemos hoy?'), findsOneWidget);
      expect(find.text('Mis sucursales'), findsOneWidget);

      await tester.tap(find.text('Crear campaña'));
      expect(created, 1);

      await tester.tap(find.byTooltip('Cerrar'));
      expect(dismissed, 1);
    });
  });
}
