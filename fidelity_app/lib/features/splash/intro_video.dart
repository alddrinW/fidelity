import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// El video de entrada de la app (2 segundos, vertical).
const String kIntroVideoAsset = 'assets/videos/intro.mp4';

/// De dónde sale el video de entrada. Es una capa delgada sobre el reproductor para que
/// las pruebas puedan poner uno de mentira (en las pruebas no hay video real).
abstract class IntroVideoSource extends ChangeNotifier {
  /// Prepara el video y lo empieza a reproducir, sin sonido. Falla si no se puede.
  Future<void> start();

  /// Ya terminó de reproducirse.
  bool get ended;

  /// Falló la reproducción.
  bool get hasError;

  /// Ya hay imagen para mostrar.
  bool get isReady;

  /// Alto y ancho del video.
  Size get size;

  /// El video para ponerlo en pantalla.
  Widget buildView();
}

/// El video que viene con la app, reproducido con `video_player`.
class AssetIntroVideo extends IntroVideoSource {
  final VideoPlayerController _controller = VideoPlayerController.asset(
    kIntroVideoAsset,
    // No le quita el sonido a la música ni a las llamadas que ya estén sonando.
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );

  AssetIntroVideo() {
    _controller.addListener(notifyListeners);
  }

  @override
  Future<void> start() async {
    await _controller.initialize();
    // Mudo: una entrada que suena sola al abrir la app molesta, y en el navegador
    // ni siquiera se deja reproducir con sonido.
    await _controller.setVolume(0);
    await _controller.setLooping(false);
    await _controller.play();
  }

  @override
  bool get isReady => _controller.value.isInitialized;

  @override
  bool get hasError => _controller.value.hasError;

  @override
  bool get ended {
    final v = _controller.value;
    return v.isInitialized && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
  }

  @override
  Size get size => _controller.value.size;

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _controller.dispose();
    super.dispose();
  }
}

/// La entrada de la app: un video corto a pantalla completa que, al terminar (o al tocarlo),
/// deja ver el login o la cuenta ya iniciada que hay debajo.
///
/// Nunca se queda trabada: si el video no carga a tiempo, falla, o el dispositivo pide
/// reducir el movimiento, se salta sola y la app sigue.
class IntroVideo extends StatefulWidget {
  /// Se llama una sola vez, cuando el video termina, falla o se salta.
  final VoidCallback onFinished;

  /// El video (si es `null`, el que viene con la app).
  final IntroVideoSource Function()? sourceFactory;

  /// Cuánto se espera a que cargue antes de seguir sin él.
  final Duration loadTimeout;

  const IntroVideo({
    super.key,
    required this.onFinished,
    this.sourceFactory,
    this.loadTimeout = const Duration(seconds: 4),
  });

  @override
  State<IntroVideo> createState() => _IntroVideoState();
}

class _IntroVideoState extends State<IntroVideo> {
  late final IntroVideoSource _video = widget.sourceFactory?.call() ?? AssetIntroVideo();
  Timer? _timeout;
  bool _finished = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onVideoChanged);
    _timeout = Timer(widget.loadTimeout, () {
      if (!_video.isReady) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // Quien pidió menos movimiento no ve el video: directo a la app.
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    _video.start().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      debugPrint('No se pudo reproducir el video de entrada: $e');
      _finish();
    });
  }

  void _onVideoChanged() {
    if (_video.hasError || _video.ended) {
      _finish();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timeout?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _video.removeListener(_onVideoChanged);
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _video.size;
    final ready = _video.isReady && size.width > 0 && size.height > 0;
    final media = MediaQuery.sizeOf(context);
    // En un celular (vertical) el video llena la pantalla; en una pantalla ancha (PC,
    // tableta) se ve entero en el centro, sin recortarlo.
    final portrait = media.height >= media.width;

    return GestureDetector(
      // Un toque lo salta.
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Semantics(
        label: 'Fidelity',
        button: true,
        child: ColoredBox(
          color: portrait ? Colors.white : Colors.black,
          child: ready
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: portrait ? BoxFit.cover : BoxFit.contain,
                    child: SizedBox(width: size.width, height: size.height, child: _video.buildView()),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Pone la entrada (el video) encima de toda la app, una sola vez cada vez que se abre.
/// Mientras suena, la app de abajo (el login o la cuenta iniciada) ya se va preparando;
/// al terminar, el video se desvanece y queda a la vista.
class FidelityIntroOverlay extends StatefulWidget {
  final Widget child;

  /// Si es `false` no se muestra (p. ej. en pruebas).
  final bool enabled;

  /// El video (si es `null`, el que viene con la app); para las pruebas.
  final IntroVideoSource Function()? sourceFactory;

  const FidelityIntroOverlay({super.key, required this.child, this.enabled = true, this.sourceFactory});

  /// Para que las pruebas puedan volver a ver la entrada.
  @visibleForTesting
  static void debugReset() => _FidelityIntroOverlayState._played = false;

  @override
  State<FidelityIntroOverlay> createState() => _FidelityIntroOverlayState();
}

class _FidelityIntroOverlayState extends State<FidelityIntroOverlay> {
  /// Solo una vez por apertura de la app (no cada vez que se reconstruye).
  static bool _played = false;

  late bool _visible;
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.enabled && !_played;
    if (_visible) _played = true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fading,
              child: AnimatedOpacity(
                opacity: _fading ? 0 : 1,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOut,
                onEnd: () {
                  if (_fading && mounted) setState(() => _visible = false);
                },
                child: IntroVideo(
                  sourceFactory: widget.sourceFactory,
                  onFinished: () => setState(() => _fading = true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
