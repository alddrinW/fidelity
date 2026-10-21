import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../flappy_physics.dart';

/// Flappy Bird con la cara de Fido. Toca (o pulsa la barra espaciadora) para
/// aletear. Al chocar, o al pasar los tubos de la meta, avisa el puntaje.
class FlappyGame extends StatefulWidget {
  /// Tubos que hay que pasar para ganar.
  final int target;

  /// Se llama una sola vez, al terminar la partida, con el puntaje.
  final ValueChanged<int> onFinished;

  /// Semilla del azar (para pruebas).
  final int? seed;

  const FlappyGame({super.key, required this.onFinished, this.target = 10, this.seed});

  @override
  State<FlappyGame> createState() => _FlappyGameState();
}

class _FlappyGameState extends State<FlappyGame> with SingleTickerProviderStateMixin {
  static const _config = FlappyConfig();

  late final math.Random _random = math.Random(widget.seed);
  late final Ticker _ticker = createTicker(_onTick);
  late FlappyState _state = FlappyState.initial(_config, _random);

  Duration _last = Duration.zero;
  bool _started = false;
  bool _finished = false;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    final next = step(_state, dt, _config, _random);
    setState(() => _state = next);

    if (!_finished && (next.dead || next.score >= widget.target)) {
      _finished = true;
      _ticker.stop();
      widget.onFinished(next.score);
    }
  }

  void _tap() {
    if (_finished) return;
    if (!_started) {
      _started = true;
      _last = Duration.zero;
      _ticker.start();
    }
    setState(() => _state = flap(_state, _config));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event.logicalKey.keyLabel == ' ' && event is KeyDownEvent) {
          _tap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Semantics(
          button: true,
          label: 'Flappy Bird: toca para aletear. Puntaje ${_state.score} de ${widget.target}',
          child: AspectRatio(
            aspectRatio: _config.width / _config.height,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.black, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _config.width,
                  height: _config.height,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(_config.width, _config.height),
                        painter: _FlappyPainter(_state, _config),
                      ),
                      Positioned(
                        top: 18,
                        left: 0,
                        right: 0,
                        child: Text(
                          '${_state.score}',
                          textAlign: TextAlign.center,
                          style: AppTypography.display(size: 56),
                        ),
                      ),
                      if (!_started)
                        Positioned(
                          bottom: 36,
                          left: 0,
                          right: 0,
                          child: Text(
                            'TOCA PARA VOLAR',
                            textAlign: TextAlign.center,
                            style: AppTypography.label(size: 16, tracking: 4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlappyPainter extends CustomPainter {
  final FlappyState state;
  final FlappyConfig config;

  _FlappyPainter(this.state, this.config);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = AppColors.black;
    final pink = Paint()..color = AppColors.pink;

    for (final p in state.pipes) {
      final top = p.gapY - config.gap / 2;
      final bottom = p.gapY + config.gap / 2;
      RRect rrect(double y, double h) => RRect.fromRectAndRadius(
            Rect.fromLTWH(p.x, y, config.pipeWidth, h),
            const Radius.circular(10),
          );
      canvas.drawRRect(rrect(-20, top + 20), ink);
      canvas.drawRRect(rrect(bottom, config.height - bottom + 20), ink);
      // Borde rosa del hueco.
      canvas.drawRect(Rect.fromLTWH(p.x, top - 6, config.pipeWidth, 6), pink);
      canvas.drawRect(Rect.fromLTWH(p.x, bottom, config.pipeWidth, 6), pink);
    }

    // Fido: círculo rosa con contorno, ojos y sonrisa.
    final c = Offset(config.birdX, state.birdY);
    final tilt = (state.birdVelocity / 900).clamp(-0.5, 0.7);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.drawCircle(Offset.zero, config.birdRadius, pink);
    canvas.drawCircle(
      Offset.zero,
      config.birdRadius,
      Paint()
        ..color = AppColors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(const Offset(-5, -3), 2.4, ink);
    canvas.drawCircle(const Offset(5, -3), 2.4, ink);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 3), width: 12, height: 9),
      0.2,
      2.7,
      false,
      Paint()
        ..color = AppColors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlappyPainter old) => old.state != state;
}
