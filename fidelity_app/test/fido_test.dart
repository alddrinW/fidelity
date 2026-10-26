import 'package:fidelity_app/core/widgets/app_empty_state.dart';
import 'package:fidelity_app/core/widgets/app_message_dialog.dart';
import 'package:fidelity_app/core/widgets/fido_mascot.dart';
import 'package:fidelity_app/features/business/dashboard/widgets/fido_guide_strip.dart';
import 'package:fidelity_app/features/scanner/data/scanner_repository.dart';
import 'package:fidelity_app/features/scanner/scan_success_screen.dart';
import 'package:fidelity_app/features/scanner/scan_waiting_screen.dart';
import 'package:fidelity_app/features/scanner/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

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
      expect(find.text('¡Eso es! Cada punto te acerca a tu premio'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un premio ganado tiene su propia frase', (tester) async {
      await open(
        tester,
        const ScanResult(
          businessName: 'Café Aurora',
          rewardCompleted: true,
          rewardDescription: 'Café gratis',
        ),
      );

      expect(find.text('¡Lo lograste! Fido salta de la emoción'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un escaneo pendiente avisa que Fido ya avisó al local', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', isPending: true));

      expect(find.text('¡Buen trabajo! Fido ya avisó al local'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('resultado del escaneo (pantalla completa)', () {
    Future<void> open(WidgetTester tester, ScanResult result) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(child: spanishApp(ScanSuccessScreen(result: result))),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('un punto sumado dice "PUNTO SUMADO" y marca el avance con puntitos', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', currentPoints: 3, pointsRequired: 10));

      expect(find.text('¡PUNTO\nSUMADO!'), findsOneWidget);
      expect(find.byType(ScanProgressDots), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un premio ganado llena todos los puntitos y Fido se emociona', (tester) async {
      await open(
        tester,
        const ScanResult(businessName: 'Café Aurora', pointsRequired: 5, rewardCompleted: true, rewardDescription: 'Café gratis'),
      );

      expect(find.text('¡PREMIO\nGANADO!'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
      expect(
        find.byWidgetPredicate((w) => w is FidoMascot && w.mood == FidoMood.euphoric),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('un escaneo pendiente espera al local: sin puntitos y con Fido pensativo', (tester) async {
      await open(tester, const ScanResult(businessName: 'Café Aurora', isPending: true, pointsRequired: 10));

      expect(find.text('ESPERANDO\nAL LOCAL'), findsOneWidget);
      expect(find.byType(ScanProgressDots), findsNothing);
      expect(find.byType(FidoCooldownBanner), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('con muchos sellos los puntitos pasan a una barra', (tester) async {
      await tester.pumpWidget(spanishApp(const Scaffold(body: ScanProgressDots(done: 5, total: 30))));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('la pantalla de espera muestra lo que dijo el servidor y vuelve con el botón', (tester) async {
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
      expect(find.byType(FidoCooldownBanner), findsOneWidget);

      await tester.tap(find.byTooltip('Entendido'));
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
