import 'package:fidelity_app/features/splash/fidelity_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _opacity(WidgetTester tester, String key) =>
    tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('FidelityIntro', () {
    testWidgets('dura unos 4,6 segundos y avisa una sola vez al terminar', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () => finished++)));

      await tester.pump(const Duration(milliseconds: 4000));
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 700));
      expect(finished, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(finished, 1);
    });

    testWidgets('empieza con Fido dibujado y sin el nombre, y termina con el logo final', (tester) async {
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_opacity(tester, 'intro-final-fido'), 0);
      expect(_opacity(tester, 'intro-wordmark'), lessThan(0.2));

      await tester.pump(const Duration(milliseconds: 4600));

      // Al final: Fido con los brazos cruzados (el logo) y "FIDELITY" a la vista.
      expect(_opacity(tester, 'intro-final-fido'), 1);
      expect(_opacity(tester, 'intro-wordmark'), 1);
      expect(_opacity(tester, 'intro-drawn-fido'), 0);
    });

    testWidgets('pasa por todas las escenas: lee el código, esconde el teléfono y guiña', (tester) async {
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () {})));

      // Escaneando (el teléfono está en las manos): todavía no se ve el logo final.
      await tester.pump(const Duration(milliseconds: 2000));
      expect(_opacity(tester, 'intro-final-fido'), 0);
      expect(_opacity(tester, 'intro-drawn-fido'), 1);

      // Ya escondió el teléfono y está pasando al logo con el guiño.
      await tester.pump(const Duration(milliseconds: 1700));
      final cross = _opacity(tester, 'intro-final-fido');
      expect(cross, greaterThan(0));
      expect(cross, lessThan(1));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('un toque la salta y avisa una sola vez', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () => finished++)));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(FidelityIntro));
      await tester.pump();
      expect(finished, 1);

      await tester.tap(find.byType(FidelityIntro));
      await tester.pump(const Duration(seconds: 5));
      expect(finished, 1);
    });

    testWidgets('con "reducir movimiento" muestra el logo final y termina enseguida', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () => finished++), reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_opacity(tester, 'intro-final-fido'), greaterThan(0.5));

      await tester.pump(const Duration(milliseconds: 1000));
      expect(finished, 1);
    });

    testWidgets('la aparición del nombre y del logo final es gradual (sin saltos)', (tester) async {
      await tester.pumpWidget(_host(FidelityIntro(onFinished: () {})));

      var lastFinal = 0.0;
      var lastWord = 0.0;
      var maxFinalJump = 0.0;
      var maxWordJump = 0.0;
      for (var ms = 0; ms < 4700; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        final f = _opacity(tester, 'intro-final-fido');
        final w = _opacity(tester, 'intro-wordmark');
        maxFinalJump = maxFinalJump > (f - lastFinal).abs() ? maxFinalJump : (f - lastFinal).abs();
        maxWordJump = maxWordJump > (w - lastWord).abs() ? maxWordJump : (w - lastWord).abs();
        lastFinal = f;
        lastWord = w;
      }

      expect(maxFinalJump, lessThan(0.15));
      expect(maxWordJump, lessThan(0.15));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('dibuja todos los instantes sin errores (también en pantallas angostas)', (tester) async {
      for (final size in const [Size(320, 560), Size(1200, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final t in [0.0, 0.1, 0.2, 0.3, 0.45, 0.58, 0.7, 0.8, 0.9, 1.0]) {
          await tester.pumpWidget(_host(Center(child: FidelityIntroScene(t: t, unit: 0.2))));
          expect(tester.takeException(), isNull, reason: 't=$t');
        }
      }
      addTearDown(tester.view.reset);
    });
  });

  group('FidelityIntroOverlay', () {
    setUp(FidelityIntroOverlay.debugReset);

    testWidgets('muestra la animación encima de la app y luego deja ver la app', (tester) async {
      await tester.pumpWidget(_host(const FidelityIntroOverlay(child: Center(child: Text('La app')))));

      expect(find.byType(FidelityIntro), findsOneWidget);
      expect(find.text('La app'), findsOneWidget); // ya va cargando por debajo

      await tester.pump(const Duration(milliseconds: 4700)); // termina
      await tester.pump(const Duration(milliseconds: 500)); // se desvanece
      await tester.pump();

      expect(find.byType(FidelityIntro), findsNothing);
      expect(find.text('La app'), findsOneWidget);
    });

    testWidgets('solo se muestra la primera vez que se abre la app', (tester) async {
      await tester.pumpWidget(_host(const FidelityIntroOverlay(child: Text('La app'))));
      await tester.tap(find.byType(FidelityIntro));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // La app se reconstruye (otro idioma, otro tema...): no vuelve a sonar.
      await tester.pumpWidget(_host(const FidelityIntroOverlay(key: ValueKey('otra'), child: Text('La app'))));

      expect(find.byType(FidelityIntro), findsNothing);
    });

    testWidgets('desactivada no muestra nada', (tester) async {
      await tester.pumpWidget(_host(const FidelityIntroOverlay(enabled: false, child: Text('La app'))));

      expect(find.byType(FidelityIntro), findsNothing);
      expect(find.text('La app'), findsOneWidget);
    });

    testWidgets('mientras suena no deja tocar la app de abajo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        FidelityIntroOverlay(
          child: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('Entrar'))),
        ),
      ));

      await tester.tap(find.text('Entrar'), warnIfMissed: false);
      await tester.pump();

      // El toque lo recibió la animación (y la saltó), no el botón.
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
