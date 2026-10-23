import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// El diseño de la plantilla de cumpleaños: fondo rosa de la marca con
/// confeti. Ya viene puesto: el dueño no elige imagen.
class BirthdayArt extends StatelessWidget {
  const BirthdayArt({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ConfettiPainter());
  }
}

/// Un trozo de confeti en posiciones relativas (0 a 1), fijas para que el
/// diseño se vea igual siempre.
class _Piece {
  final double x;
  final double y;
  final double size;
  final double turns;
  final int shape; // 0 círculo, 1 rectángulo, 2 trazo
  final int tone; // 0 negro, 1 blanco, 2 rosa fuerte

  const _Piece(this.x, this.y, this.size, this.turns, this.shape, this.tone);
}

const _pieces = <_Piece>[
  _Piece(.04, .10, 7, .1, 0, 1),
  _Piece(.11, .78, 9, .3, 1, 0),
  _Piece(.18, .30, 6, .6, 2, 2),
  _Piece(.25, .90, 7, .2, 0, 1),
  _Piece(.31, .12, 9, .8, 1, 1),
  _Piece(.38, .62, 6, .4, 2, 0),
  _Piece(.44, .88, 8, .7, 0, 2),
  _Piece(.50, .06, 7, .5, 1, 2),
  _Piece(.57, .72, 6, .9, 0, 1),
  _Piece(.63, .20, 8, .15, 2, 0),
  _Piece(.69, .92, 9, .55, 1, 1),
  _Piece(.74, .45, 6, .35, 0, 0),
  _Piece(.80, .08, 8, .65, 1, 2),
  _Piece(.86, .66, 7, .25, 2, 1),
  _Piece(.92, .26, 9, .85, 0, 2),
  _Piece(.96, .84, 6, .45, 1, 0),
  _Piece(.02, .52, 6, .75, 2, 1),
  _Piece(.47, .40, 5, .05, 0, 1),
];

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pink, Color(0xFFFFE3F0)],
        ).createShader(rect),
    );

    for (final piece in _pieces) {
      final color = switch (piece.tone) {
        0 => AppColors.black.withValues(alpha: 0.85),
        1 => AppColors.white,
        _ => const Color(0xFFF58FBF),
      };
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      canvas.save();
      canvas.translate(piece.x * size.width, piece.y * size.height);
      canvas.rotate(piece.turns * 6.2832);
      switch (piece.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, piece.size / 2, paint);
        case 1:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.55),
              const Radius.circular(1.5),
            ),
            paint,
          );
        default:
          canvas.drawLine(Offset(-piece.size / 2, 0), Offset(piece.size / 2, 0), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
