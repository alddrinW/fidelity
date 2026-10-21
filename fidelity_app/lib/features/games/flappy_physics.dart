import 'dart:math' as math;

/// Física de Flappy Bird, sin nada de Flutter, para poder probarla.
///
/// El tubo que se pasa cada ~1.5 s es a propósito: el servidor no deja ganar
/// si el puntaje no es creíble para el tiempo que pasó.
class FlappyConfig {
  final double width;
  final double height;

  /// Gravedad (px/s²) e impulso de cada aleteo (px/s, hacia arriba es negativo).
  final double gravity;
  final double flapVelocity;

  /// Velocidad de los tubos (px/s) y distancia entre uno y el siguiente.
  final double pipeSpeed;
  final double pipeSpacing;

  final double pipeWidth;

  /// Alto del hueco por el que se pasa.
  final double gap;

  final double birdRadius;

  /// Posición horizontal del pájaro.
  final double birdX;

  /// Cuánto espacio hay antes del primer tubo.
  final double firstPipeDistance;

  const FlappyConfig({
    this.width = 360,
    this.height = 520,
    this.gravity = 1400,
    this.flapVelocity = -420,
    this.pipeSpeed = 140,
    this.pipeSpacing = 210,
    this.pipeWidth = 58,
    this.gap = 175,
    this.birdRadius = 16,
    this.firstPipeDistance = 260,
  }) : birdX = width * 0.28;

  /// Segundos que tarda en llegar cada tubo.
  double get secondsPerPipe => pipeSpacing / pipeSpeed;
}

class FlappyPipe {
  /// Borde izquierdo.
  final double x;

  /// Centro del hueco.
  final double gapY;
  final bool passed;

  const FlappyPipe({required this.x, required this.gapY, this.passed = false});

  FlappyPipe copyWith({double? x, bool? passed}) =>
      FlappyPipe(x: x ?? this.x, gapY: gapY, passed: passed ?? this.passed);
}

class FlappyState {
  final double birdY;
  final double birdVelocity;
  final List<FlappyPipe> pipes;
  final int score;
  final bool dead;

  const FlappyState({
    required this.birdY,
    required this.birdVelocity,
    required this.pipes,
    required this.score,
    required this.dead,
  });

  factory FlappyState.initial(FlappyConfig config, math.Random random) => FlappyState(
        birdY: config.height / 2,
        birdVelocity: 0,
        pipes: [_newPipe(config, random, config.width + config.firstPipeDistance)],
        score: 0,
        dead: false,
      );

  FlappyState copyWith({
    double? birdY,
    double? birdVelocity,
    List<FlappyPipe>? pipes,
    int? score,
    bool? dead,
  }) =>
      FlappyState(
        birdY: birdY ?? this.birdY,
        birdVelocity: birdVelocity ?? this.birdVelocity,
        pipes: pipes ?? this.pipes,
        score: score ?? this.score,
        dead: dead ?? this.dead,
      );
}

FlappyPipe _newPipe(FlappyConfig c, math.Random random, double x) {
  const margin = 50.0;
  final min = c.gap / 2 + margin;
  final max = c.height - c.gap / 2 - margin;
  return FlappyPipe(x: x, gapY: min + random.nextDouble() * (max - min));
}

/// Un aleteo: el pájaro sube de golpe.
FlappyState flap(FlappyState state, FlappyConfig config) =>
    state.dead ? state : state.copyWith(birdVelocity: config.flapVelocity);

/// ¿El pájaro choca con el techo, el suelo o un tubo?
bool collides(FlappyState s, FlappyConfig c) {
  final r = c.birdRadius;
  if (s.birdY - r < 0 || s.birdY + r > c.height) return true;
  for (final p in s.pipes) {
    final overlapsX = c.birdX + r > p.x && c.birdX - r < p.x + c.pipeWidth;
    if (!overlapsX) continue;
    final gapTop = p.gapY - c.gap / 2;
    final gapBottom = p.gapY + c.gap / 2;
    if (s.birdY - r < gapTop || s.birdY + r > gapBottom) return true;
  }
  return false;
}

/// Avanza el juego [dt] segundos.
FlappyState step(FlappyState state, double dt, FlappyConfig c, math.Random random) {
  if (state.dead) return state;

  final velocity = state.birdVelocity + c.gravity * dt;
  final birdY = state.birdY + velocity * dt;

  var score = state.score;
  final pipes = <FlappyPipe>[];
  for (final p in state.pipes) {
    final moved = p.copyWith(x: p.x - c.pipeSpeed * dt);
    if (moved.x + c.pipeWidth < -1) continue; // ya salió de la pantalla
    if (!moved.passed && moved.x + c.pipeWidth < c.birdX - c.birdRadius) {
      score++;
      pipes.add(moved.copyWith(passed: true));
    } else {
      pipes.add(moved);
    }
  }
  // Aparece un tubo nuevo cuando el último ya avanzó lo suficiente.
  if (pipes.isEmpty || pipes.last.x <= c.width + c.pipeWidth - c.pipeSpacing) {
    pipes.add(_newPipe(c, random, c.width + c.pipeWidth));
  }

  final next = state.copyWith(birdY: birdY, birdVelocity: velocity, pipes: pipes, score: score);
  return collides(next, c) ? next.copyWith(dead: true) : next;
}
