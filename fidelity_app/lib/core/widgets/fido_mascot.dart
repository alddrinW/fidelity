import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';

/// Estados de ánimo de Fido (la mascota guía de Fidelity).
enum FidoMood {
  /// Reposo: flota suavemente. Estados vacíos, guías y asistentes.
  calm,

  /// Victoria: salta con los brazos arriba. Escaneo exitoso.
  celebrate,

  /// Reflexivo: se inclina pensativo. Tiempo de espera (cooldown).
  thinking,

  /// Euforia: saltos rápidos y meneo. Canje o premio ganado.
  euphoric,

  /// Tristeza: se encorva y se balancea despacio. Errores, juegos perdidos,
  /// retos vencidos y cosas que no salieron bien.
  sad;

  bool get usesCelebrationPose => this == celebrate || this == euphoric;
}

/// Fido animado según su [FidoMood]. Las animaciones se repiten unas cuantas
/// veces y se detienen (no giran para siempre) y se omiten si el usuario pidió
/// reducir el movimiento.
class FidoMascot extends StatelessWidget {
  final FidoMood mood;
  final double? height;
  final double? width;

  const FidoMascot({
    super.key,
    this.mood = FidoMood.calm,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final fido = Image.asset(
      switch (mood) {
        FidoMood.celebrate || FidoMood.euphoric => 'assets/images/fido_celebra.png',
        FidoMood.sad => 'assets/images/fido_triste.png',
        _ => 'assets/images/logo_transparente.png',
      },
      height: height,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: switch (mood) {
        FidoMood.celebrate || FidoMood.euphoric => 'Fido celebrando',
        FidoMood.thinking => 'Fido pensativo',
        FidoMood.sad => 'Fido triste',
        FidoMood.calm => 'Fido',
      },
    );

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return fido;

    return switch (mood) {
      FidoMood.calm => fido
          .animate(onPlay: (c) => c.repeat(reverse: true, count: 8))
          .moveY(begin: 0, end: -5, duration: 1600.ms, curve: Curves.easeInOut),
      FidoMood.celebrate => fido
          .animate(onPlay: (c) => c.repeat(count: 5))
          .moveY(begin: 0, end: -26, duration: 300.ms, curve: Curves.easeOut)
          .then()
          .moveY(begin: 0, end: 26, duration: 300.ms, curve: Curves.easeIn)
          .then(delay: 500.ms),
      FidoMood.euphoric => fido
          .animate(onPlay: (c) => c.repeat(count: 8))
          .moveY(begin: 0, end: -22, duration: 220.ms, curve: Curves.easeOut)
          .rotate(begin: -0.02, end: 0.02, duration: 220.ms)
          .then()
          .moveY(begin: 0, end: 22, duration: 220.ms, curve: Curves.easeIn)
          .rotate(begin: 0, end: -0.02, duration: 220.ms)
          .then(delay: 150.ms),
      // Un suspiro: se encorva un poco y se balancea, despacio.
      FidoMood.sad => fido
          .animate(onPlay: (c) => c.repeat(reverse: true, count: 6))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 0.96),
            duration: 1800.ms,
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
          )
          .rotate(
            begin: -0.02,
            end: 0.02,
            duration: 2600.ms,
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
          ),
      FidoMood.thinking => fido
          .animate(onPlay: (c) => c.repeat(reverse: true, count: 6))
          .rotate(
            begin: -0.015,
            end: 0.015,
            duration: 1400.ms,
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
          ),
    };
  }
}

/// Reloj de arena que se voltea una y otra vez (tiempo de espera).
class FidoHourglass extends StatelessWidget {
  final double size;

  const FidoHourglass({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.hourglass_top_rounded, size: size, color: AppColors.black);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return icon;
    return icon
        .animate(onPlay: (c) => c.repeat(count: 6))
        .rotate(begin: 0, end: 0.5, duration: 1500.ms, curve: Curves.easeInOut)
        .then(delay: 500.ms);
  }
}

/// Fido pensativo junto a un reloj de arena animado: la imagen del "espera un
/// poco" cuando un local aún no permite otro escaneo.
class FidoCooldownBanner extends StatelessWidget {
  const FidoCooldownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const FidoMascot(mood: FidoMood.thinking, height: 120),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
          child: const FidoHourglass(),
        ),
      ],
    );
  }
}
