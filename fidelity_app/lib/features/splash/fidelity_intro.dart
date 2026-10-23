import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Animación de entrada de la app: aparece Fido, escanea un código con su
/// teléfono, lo esconde, guiña un ojo y se queda con los brazos cruzados junto
/// a "FIDELITY" (el logo de la marca).
///
/// Se dibuja con vectores, sin videos: pesa poco y se ve nítida en cualquier
/// pantalla. Un toque la salta. Con "reducir movimiento" solo se muestra el
/// logo final un instante.
///
/// Para que se sienta fluida: las escenas se traslapan (la siguiente empieza
/// antes de que acabe la anterior), los movimientos usan resortes y curvas
/// suaves, y Fido nunca queda quieto del todo (respira y parpadea).
class FidelityIntro extends StatefulWidget {
  /// Se llama una sola vez, cuando la animación termina (o se salta).
  final VoidCallback onFinished;

  /// Cuánto dura la animación completa.
  final Duration duration;

  const FidelityIntro({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 4600),
  });

  @override
  State<FidelityIntro> createState() => _FidelityIntroState();
}

class _FidelityIntroState extends State<FidelityIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  bool _finished = false;
  bool _started = false;
  bool _hapticDone = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_haptics);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Las imágenes se cargan mientras suenan las primeras escenas, para que
    // nada "aparezca de golpe" a mitad de la animación.
    precacheImage(const AssetImage('assets/images/fidelity_wordmark.png'), context).ignore();
    precacheImage(const AssetImage('assets/images/logo_transparente.png'), context).ignore();

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // Sin movimiento: directo al logo final, un instante.
      _controller.value = FidoIntroTimeline.finalPose;
      _controller.animateTo(1, duration: const Duration(milliseconds: 900));
    } else {
      _controller.forward();
    }
  }

  /// Una vibración suave cuando el teléfono lee el código.
  void _haptics() {
    if (!_hapticDone && _controller.value >= FidoIntroTimeline.successStart) {
      _hapticDone = true;
      HapticFeedback.lightImpact();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fidelity',
      button: true,
      onTapHint: 'Saltar la animación',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _controller.stop();
          _finish();
        },
        child: ColoredBox(
          color: AppColors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // La escena (Fido y el nombre) cabe en un 78 % del ancho y un 60 % del alto.
              final u = math.min(
                math.min(constraints.maxWidth * 0.78, 460) / FidoIntroTimeline.sceneWidth,
                constraints.maxHeight * 0.6 / FidoIntroTimeline.sceneHeight,
              );
              final width = FidoIntroTimeline.sceneWidth * u;
              final height = FidoIntroTimeline.sceneHeight * u;

              return Stack(
                children: [
                  // Un resplandor rosa muy suave detrás de Fido (en su propia capa:
                  // no se vuelve a pintar cuando Fido se mueve).
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.15),
                              radius: 0.75,
                              colors: [
                                AppColors.pink.withValues(alpha: 0.30 * FidoIntroTimeline.glow(_controller.value)),
                                AppColors.pink.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -constraints.maxHeight * 0.03),
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => FidelityIntroScene(t: _controller.value, unit: u),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Un resorte amortiguado: sube pasándose un poco de 1 y se asienta.
class _Spring extends Curve {
  const _Spring();

  @override
  double transformInternal(double t) => 1 - math.exp(-7 * t) * math.cos(11 * t);
}

/// Los tiempos de la animación (de 0 a 1) y la geometría de la escena. Las
/// medidas están en el sistema del logo (2048 × 2048).
///
/// Las escenas se traslapan a propósito: cada una arranca mientras la anterior
/// termina, así no hay "pausas" entre una y otra.
class FidoIntroTimeline {
  FidoIntroTimeline._();

  // Escena: de x 368 a 1676 y de y 200 a 2200.
  static const double sceneLeft = 368;
  static const double sceneTop = 200;
  static const double sceneWidth = 1308;
  static const double sceneHeight = 2000;

  /// Fido aparece (con resorte).
  static const double popEnd = 0.20;

  /// El nombre sube.
  static const double wordStart = 0.04;
  static const double wordEnd = 0.26;

  /// Sube el teléfono mientras Fido todavía se asienta.
  static const double phoneStart = 0.15;
  static const double phoneEnd = 0.31;

  /// Escanea: la línea sube y baja suavemente.
  static const double scanStart = 0.27;
  static const double scanEnd = 0.60;

  /// Lee el código: visto, destellos y sonrisa grande (empieza antes de que
  /// la línea termine).
  static const double successStart = 0.55;
  static const double successEnd = 0.66;

  /// Esconde el teléfono (en arco) mientras los destellos se apagan.
  static const double hideStart = 0.65;
  static const double hideEnd = 0.80;

  /// Desde aquí el logo final (guiño y brazos cruzados) aparece sobre el dibujo.
  static const double crossStart = 0.77;
  static const double crossEnd = 0.87;

  /// El instante en que ya se ve la pose final.
  static const double finalPose = 0.88;

  static double seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  static double glow(double t) => seg(t, 0.0, 0.30, Curves.easeOut);

  /// Una respiración suave (se nota poco, pero evita que Fido se vea "congelado").
  static double breath(double t) => math.sin(t * 2 * math.pi * 4.5);
}

/// La escena en un instante [t] (de 0 a 1): el dibujo de Fido, el logo final y
/// el nombre. [unit] son los píxeles por unidad del logo.
class FidelityIntroScene extends StatelessWidget {
  final double t;
  final double unit;

  const FidelityIntroScene({super.key, required this.t, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cross = FidoIntroTimeline.seg(t, FidoIntroTimeline.crossStart, FidoIntroTimeline.crossEnd, Curves.easeInOutCubic);
    // Un saltito al guiñar y luego respira.
    final hop = math.sin(
      FidoIntroTimeline.seg(t, FidoIntroTimeline.crossStart + 0.02, FidoIntroTimeline.crossEnd + 0.05, Curves.easeInOut) * math.pi,
    );
    final settle = FidoIntroTimeline.seg(t, FidoIntroTimeline.crossEnd, 1.0);
    final breath = 0.005 * FidoIntroTimeline.breath(t) * settle;

    // La imagen del logo mide 2048 × 2048; se coloca con su esquina en la escena.
    final image = Positioned(
      left: -FidoIntroTimeline.sceneLeft * unit,
      top: -FidoIntroTimeline.sceneTop * unit,
      width: 2048 * unit,
      height: 2048 * unit,
      child: Opacity(
        key: const ValueKey('intro-final-fido'),
        opacity: cross,
        child: Transform.scale(
          scale: 1 + 0.03 * hop + breath,
          alignment: const Alignment(0, 0.78),
          child: Image.asset('assets/images/logo_transparente.png', fit: BoxFit.fill, gaplessPlayback: true),
        ),
      ),
    );

    // El nombre: sube desde abajo con un pequeño sobrepaso mientras aparece.
    const wordTop = 1900.0;
    const wordWidth = FidoIntroTimeline.sceneWidth;
    final wordHeight = wordWidth * 374 / 1654;
    final rise = FidoIntroTimeline.seg(t, FidoIntroTimeline.wordStart, FidoIntroTimeline.wordEnd, Curves.easeOutBack);
    final wordmark = Positioned(
      left: 0,
      top: (wordTop - FidoIntroTimeline.sceneTop + 150 * (1 - rise)) * unit,
      width: wordWidth * unit,
      height: wordHeight * unit,
      child: Opacity(
        key: const ValueKey('intro-wordmark'),
        opacity: FidoIntroTimeline.seg(t, FidoIntroTimeline.wordStart, FidoIntroTimeline.wordEnd - 0.06, Curves.easeOut),
        child: Image.asset('assets/images/fidelity_wordmark.png', fit: BoxFit.fill, gaplessPlayback: true),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // El dibujo se queda completamente opaco hasta que el logo final cubre todo:
        // así el rosa no "se aclara" a mitad del cambio.
        Positioned.fill(
          child: Opacity(
            key: const ValueKey('intro-drawn-fido'),
            opacity: cross >= 1 ? 0 : FidoIntroTimeline.seg(t, 0, 0.05),
            child: CustomPaint(
              painter: FidoIntroPainter(t: t, unit: unit),
            ),
          ),
        ),
        image,
        wordmark,
      ],
    );
  }
}

/// Dibuja a Fido con su teléfono: aparece, escanea un código, lo esconde.
class FidoIntroPainter extends CustomPainter {
  final double t;
  final double unit;

  const FidoIntroPainter({required this.t, required this.unit});

  static const Offset _disc = Offset(1024, 884);
  static const double _discRadius = 652;
  static const Color _pink = Color(0xFFFEC3DD);
  static const Color _pinkSoft = Color(0xFFFFE9F3);
  static const Color _ink = Colors.black;
  static const Offset _phoneCenter = Offset(1024, 1280);
  static const Size _phoneSize = Size(380, 640);
  static const _spring = _Spring();

  // Los módulos del código QR (9 × 9): tres esquinas fijas y el resto al azar,
  // siempre igual.
  static final List<List<bool>> _qr = _buildQr();

  static List<List<bool>> _buildQr() {
    const n = 9;
    final random = math.Random(7);
    final grid = List.generate(n, (_) => List.filled(n, false));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        grid[y][x] = random.nextBool();
      }
    }
    void finder(int ox, int oy) {
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          grid[oy + y][ox + x] = !(x == 1 && y == 1);
        }
      }
    }

    finder(0, 0);
    finder(n - 3, 0);
    finder(0, n - 3);
    return grid;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = FidoIntroTimeline.seg;

    canvas.save();
    canvas.scale(unit);
    canvas.translate(-FidoIntroTimeline.sceneLeft, -FidoIntroTimeline.sceneTop);

    // Aparece desde los pies: crece con un resorte (se estira al pasarse y se
    // aplasta al empezar) y después respira.
    final pop = _spring.transform(s(t, 0, FidoIntroTimeline.popEnd));
    final grow = 0.5 + 0.5 * pop;
    final stretch = 0.05 * (pop - 1);
    final breath = 0.006 * FidoIntroTimeline.breath(t) * s(t, FidoIntroTimeline.popEnd - 0.05, FidoIntroTimeline.popEnd + 0.05);
    canvas.translate(_disc.dx, 1824);
    canvas.scale(grow * (1 - stretch) * (1 + breath), grow * (1 + stretch) * (1 - breath));
    canvas.translate(-_disc.dx, -1824);

    final reach = s(t, FidoIntroTimeline.phoneStart, FidoIntroTimeline.phoneEnd, Curves.easeOutBack);
    final retreat = s(t, FidoIntroTimeline.hideStart, FidoIntroTimeline.hideEnd, Curves.easeInOutCubic);
    final scan = s(t, FidoIntroTimeline.scanStart, FidoIntroTimeline.scanEnd);
    final success = s(t, FidoIntroTimeline.successStart, FidoIntroTimeline.successEnd, Curves.easeOutBack);
    // Un parpadeo a mitad del escaneo.
    final blink = (1 - ((t - 0.43).abs() / 0.014)).clamp(0.0, 1.0);

    _legs(canvas);
    canvas.drawCircle(_disc, _discRadius, Paint()..color = _pink);
    _face(canvas, looking: reach * (1 - retreat), happy: success, blink: blink);
    _arms(canvas, reach: reach, retreat: retreat);
    _phone(canvas, reach: reach, retreat: retreat, scan: scan, success: success);
    _sparkles(canvas, s(t, FidoIntroTimeline.successStart + 0.01, FidoIntroTimeline.successEnd + 0.12, Curves.easeOut));

    canvas.restore();
  }

  Paint _stroke({double width = 24, double alpha = 1}) => Paint()
    ..color = _ink.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _legs(Canvas canvas) {
    final fill = Paint()..color = Colors.white;
    final line = _stroke();
    for (final mirror in [false, true]) {
      double x(double v) => mirror ? 2048 - v : v;
      final path = Path()
        ..moveTo(x(790), 1440)
        ..lineTo(x(790), 1770)
        ..lineTo(x(752), 1814)
        ..lineTo(x(982), 1814)
        ..lineTo(x(980), 1440);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);
    }
  }

  void _face(Canvas canvas, {required double looking, required double happy, required double blink}) {
    final dy = 16 * looking; // mira hacia el teléfono
    final dot = Paint()..color = _ink;
    final eyeHeight = 25 * (1 - 0.92 * blink);
    for (final cx in [853.0, 1172.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, 776 + dy), width: 50, height: eyeHeight * 2), dot);
    }

    // La sonrisa se hace más grande al leer el código.
    final w = 70 + 22 * happy;
    final smile = Path()
      ..moveTo(1008 - w, 838 + dy)
      ..quadraticBezierTo(1008, 960 + 22 * happy + dy, 1008 + w, 838 + dy);
    canvas.drawPath(smile, _stroke(width: 22));
  }

  /// Los brazos suben a sostener el teléfono y, al esconderlo, bajan y se
  /// desvanecen (para que el logo final con los brazos cruzados entre limpio).
  void _arms(Canvas canvas, {required double reach, required double retreat}) {
    final r = reach * (1 - retreat);
    final alpha = 1 - FidoIntroTimeline.seg(retreat, 0.55, 1.0, Curves.easeIn);
    if (alpha <= 0.01) return;
    final line = _stroke(alpha: alpha);
    for (final mirror in [false, true]) {
      double x(double v) => mirror ? 2048 - v : v;
      // Reposo: colgando al costado. Con el teléfono: las manos en sus bordes.
      final hand = Offset.lerp(Offset(x(440), 1360), Offset(x(842), 1330), r)!;
      final c1 = Offset.lerp(Offset(x(380), 1110), Offset(x(330), 1200), r)!;
      final c2 = Offset.lerp(Offset(x(400), 1260), Offset(x(560), 1400), r)!;
      final path = Path()
        ..moveTo(x(392), 1010)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, hand.dx, hand.dy);
      canvas.drawPath(path, line);
      if (r > 0.05) {
        canvas.drawCircle(hand, 30 * r, Paint()..color = _pink.withValues(alpha: alpha));
        canvas.drawCircle(hand, 30 * r, _stroke(width: 18, alpha: alpha));
      }
    }
  }

  void _phone(Canvas canvas, {required double reach, required double retreat, required double scan, required double success}) {
    final appear = reach * (1 - retreat);
    if (appear <= 0.01) return;

    canvas.save();
    // Sube desde abajo al aparecer; al esconderlo se va en arco (sube un poco y
    // cae) hacia la espalda, girando y encogiéndose.
    final lift = 170 * (1 - reach);
    final arc = Offset(520 * retreat, 300 * retreat - 240 * math.sin(retreat * math.pi));
    canvas.translate(_phoneCenter.dx + arc.dx, _phoneCenter.dy + lift + arc.dy);
    // Un leve bamboleo al apuntar y un "pulso" al leer el código.
    final wobble = 0.012 * math.sin(scan * math.pi * 6) * (1 - success.clamp(0.0, 1.0));
    canvas.rotate(0.55 * retreat + wobble);
    final pulse = 1 + 0.07 * math.sin(FidoIntroTimeline.seg(t, FidoIntroTimeline.successStart, FidoIntroTimeline.successStart + 0.07) * math.pi);
    canvas.scale(math.max(appear, 0.001) * pulse);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: _phoneSize.width, height: _phoneSize.height),
      const Radius.circular(64),
    );
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(body, _stroke());

    // La cámara y la pantalla.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -270), width: 90, height: 16), const Radius.circular(8)),
      Paint()..color = _ink,
    );
    final screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 14), width: 300, height: 520),
      const Radius.circular(36),
    );
    canvas.drawRRect(screen, Paint()..color = _pinkSoft);

    // El código QR.
    const qrSize = 230.0;
    const cell = qrSize / 9;
    const qrTop = -115.0 + 14;
    const qrLeft = -qrSize / 2;
    final dark = Paint()..color = _ink;
    for (var y = 0; y < 9; y++) {
      for (var x = 0; x < 9; x++) {
        if (!_qr[y][x]) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(qrLeft + x * cell + 1.5, qrTop + y * cell + 1.5, cell - 3, cell - 3),
            const Radius.circular(4),
          ),
          dark,
        );
      }
    }

    // Las esquinas del visor: se cierran un poco al leer el código.
    final bracket = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    const pad = 22.0;
    final half = qrSize / 2 + pad - 8 * success.clamp(0.0, 1.0);
    const cy = qrTop + qrSize / 2;
    const len = 46.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final corner = Offset(sx * half, cy + sy * half);
        canvas.drawLine(corner, corner.translate(-sx * len, 0), bracket);
        canvas.drawLine(corner, corner.translate(0, -sy * len), bracket);
      }
    }

    // La línea de escaneo sube y baja con suavidad (una vuelta y media): se
    // frena en los extremos en vez de rebotar de golpe, y entra y sale
    // desvaneciéndose.
    if (scan > 0 && scan < 1) {
      final pos = 0.5 - 0.5 * math.cos(math.pi * 3 * scan);
      final fade = FidoIntroTimeline.seg(scan, 0, 0.08) * (1 - FidoIntroTimeline.seg(scan, 0.9, 1));
      final y = qrTop + pos * qrSize;
      final glow = Rect.fromLTWH(qrLeft - 10, y - 60, qrSize + 20, 60);
      canvas.drawRect(
        glow,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pink.withValues(alpha: 0), _pink.withValues(alpha: 0.95 * fade)],
          ).createShader(glow),
      );
      canvas.drawLine(Offset(qrLeft - 10, y), Offset(qrLeft + qrSize + 10, y), _stroke(width: 12, alpha: fade));
    }

    // El visto de "leído".
    if (success > 0) {
      final badge = Offset(qrLeft + qrSize + 10, qrTop - 10);
      canvas.save();
      canvas.translate(badge.dx, badge.dy);
      canvas.scale(success);
      canvas.drawCircle(Offset.zero, 64, Paint()..color = _pink);
      canvas.drawCircle(Offset.zero, 64, _stroke(width: 14));
      final check = Path()
        ..moveTo(-26, 2)
        ..lineTo(-8, 22)
        ..lineTo(28, -20);
      canvas.drawPath(check, _stroke(width: 16));
      canvas.restore();
    }

    canvas.restore();
  }

  /// Destellos que salen al leer el código.
  void _sparkles(Canvas canvas, double p) {
    if (p <= 0 || p >= 1) return;
    final fade = 1 - p;
    final stars = <(double angle, double distance, double size)>[
      (-2.5, 520, 52),
      (-0.7, 560, 40),
      (0.35, 500, 56),
      (2.2, 470, 44),
      (-1.6, 640, 36),
    ];
    for (final (angle, distance, size) in stars) {
      final c = _phoneCenter + Offset(math.cos(angle), math.sin(angle)) * (distance * (0.55 + 0.45 * p));
      final r = size * (0.5 + 0.7 * math.sin(p * math.pi));
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(path, Paint()..color = _ink.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(covariant FidoIntroPainter old) => old.t != t || old.unit != unit;
}

/// Pone la animación de entrada encima de toda la app (incluidos los diálogos)
/// la primera vez que se abre. Mientras suena, la app ya va cargando debajo; al
/// terminar se desvanece con un pequeño acercamiento, como si entráramos a la
/// app. Un toque la salta.
class FidelityIntroOverlay extends StatefulWidget {
  final Widget child;

  /// Si es `false` no se muestra (p. ej. en pruebas).
  final bool enabled;

  const FidelityIntroOverlay({super.key, required this.child, this.enabled = true});

  /// Para que las pruebas puedan volver a ver la animación.
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
                child: AnimatedScale(
                  scale: _fading ? 1.08 : 1,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInCubic,
                  child: FidelityIntro(onFinished: () => setState(() => _fading = true)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
