import 'dart:io';

import 'package:fidelity_app/features/splash/intro_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un video de mentira: se controla desde la prueba.
class _FakeVideo extends IntroVideoSource {
  bool _ready = false;
  bool _ended = false;
  bool _error = false;
  bool disposed = false;
  bool started = false;
  Object? failStartWith;

  @override
  Future<void> start() async {
    started = true;
    if (failStartWith != null) throw failStartWith!;
  }

  void becomeReady() {
    _ready = true;
    notifyListeners();
  }

  void end() {
    _ended = true;
    notifyListeners();
  }

  void fail() {
    _error = true;
    notifyListeners();
  }

  @override
  bool get isReady => _ready;

  @override
  bool get ended => _ended;

  @override
  bool get hasError => _error;

  @override
  Size get size => const Size(1080, 1920);

  @override
  Widget buildView() => const ColoredBox(key: ValueKey('video'), color: Colors.pink);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

Widget _host(Widget child, {bool reduceMotion = false, Size size = const Size(390, 844)}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  tearDown(FidelityIntroOverlay.debugReset);

  group('IntroVideo', () {
    testWidgets('empieza el video sin sonido y, mientras carga, deja la pantalla en blanco', (tester) async {
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () {}, sourceFactory: () => video)));

      expect(video.started, isTrue);
      expect(find.byKey(const ValueKey('video')), findsNothing);

      video.becomeReady();
      await tester.pump();
      expect(find.byKey(const ValueKey('video')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('al terminar el video avisa una sola vez', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () => finished++, sourceFactory: () => video)));
      video.becomeReady();
      await tester.pump();
      expect(finished, 0);

      video.end();
      await tester.pump();
      expect(finished, 1);

      video.end();
      await tester.pump(const Duration(seconds: 5));
      expect(finished, 1);
    });

    testWidgets('un toque lo salta', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () => finished++, sourceFactory: () => video)));
      video.becomeReady();
      await tester.pump();

      await tester.tap(find.byType(IntroVideo));
      await tester.pump();
      expect(finished, 1);

      await tester.tap(find.byType(IntroVideo));
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('si el video no se puede reproducir, sigue a la app (no se queda trabada)', (tester) async {
      var finished = 0;
      final video = _FakeVideo()..failStartWith = Exception('sin códec');
      await tester.pumpWidget(_host(IntroVideo(onFinished: () => finished++, sourceFactory: () => video)));
      await tester.pump();

      expect(finished, 1);
    });

    testWidgets('si falla a mitad de camino, también sigue', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () => finished++, sourceFactory: () => video)));
      video.becomeReady();
      await tester.pump();

      video.fail();
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('si tarda demasiado en cargar, sigue sin él', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(
        onFinished: () => finished++,
        sourceFactory: () => video,
        loadTimeout: const Duration(seconds: 2),
      )));

      await tester.pump(const Duration(milliseconds: 1900));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, 1);
    });

    testWidgets('si ya cargó, el tiempo de espera no lo corta a medio video', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(
        onFinished: () => finished++,
        sourceFactory: () => video,
        loadTimeout: const Duration(seconds: 2),
      )));
      video.becomeReady();
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      expect(finished, 0);

      video.end();
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('con "reducir movimiento" no se reproduce: sigue directo a la app', (tester) async {
      var finished = 0;
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () => finished++, sourceFactory: () => video), reduceMotion: true));
      await tester.pump();

      expect(finished, 1);
      expect(video.started, isFalse);
    });

    testWidgets('en un celular llena la pantalla; en una pantalla ancha se ve entero', (tester) async {
      Future<BoxFit> fitFor(Size size) async {
        final video = _FakeVideo();
        await tester.pumpWidget(_host(IntroVideo(onFinished: () {}, sourceFactory: () => video), size: size));
        video.becomeReady();
        await tester.pump();
        final fit = tester.widget<FittedBox>(find.byType(FittedBox)).fit;
        await tester.pump(const Duration(seconds: 5));
        return fit;
      }

      expect(await fitFor(const Size(390, 844)), BoxFit.cover);
      expect(await fitFor(const Size(1280, 720)), BoxFit.contain);
    });

    testWidgets('al cerrarse libera el video', (tester) async {
      final video = _FakeVideo();
      await tester.pumpWidget(_host(IntroVideo(onFinished: () {}, sourceFactory: () => video)));
      await tester.pumpWidget(_host(const SizedBox()));

      expect(video.disposed, isTrue);
    });
  });

  group('FidelityIntroOverlay', () {
    Widget app({bool enabled = true, required _FakeVideo video}) => _host(
          FidelityIntroOverlay(
            enabled: enabled,
            sourceFactory: () => video,
            child: const Center(child: Text('login')),
          ),
        );

    testWidgets('pone el video encima de la app y, al terminar, se desvanece y queda la app (login o cuenta)', (tester) async {
      final video = _FakeVideo();
      await tester.pumpWidget(app(video: video));
      video.becomeReady();
      await tester.pump();

      expect(find.byType(IntroVideo), findsOneWidget);
      expect(find.text('login'), findsOneWidget); // ya está debajo, preparándose

      video.end();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(IntroVideo), findsNothing);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('mientras se desvanece ya no responde a toques (no se traga los de la app)', (tester) async {
      final video = _FakeVideo();
      await tester.pumpWidget(app(video: video));
      video.becomeReady();
      await tester.pump();

      video.end();
      await tester.pump(const Duration(milliseconds: 100));

      final ignore = tester.widget<IgnorePointer>(find.descendant(of: find.byType(FidelityIntroOverlay), matching: find.byType(IgnorePointer)).first);
      expect(ignore.ignoring, isTrue);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('solo una vez por apertura: al reconstruirse no vuelve a sonar', (tester) async {
      final first = _FakeVideo();
      await tester.pumpWidget(app(video: first));
      first.becomeReady();
      first.end();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(IntroVideo), findsNothing);

      await tester.pumpWidget(_host(const SizedBox()));
      final second = _FakeVideo();
      await tester.pumpWidget(app(video: second));
      await tester.pump();

      expect(find.byType(IntroVideo), findsNothing);
      expect(second.started, isFalse);
    });

    testWidgets('apagada (enabled: false) no muestra nada', (tester) async {
      final video = _FakeVideo();
      await tester.pumpWidget(app(enabled: false, video: video));

      expect(find.byType(IntroVideo), findsNothing);
      expect(find.text('login'), findsOneWidget);
    });
  });

  group('el video que viene con la app', () {
    test('existe, es liviano y está declarado como recurso', () {
      final file = File(kIntroVideoAsset);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), lessThan(3 * 1024 * 1024));
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/videos/'));
    });
  });
}
