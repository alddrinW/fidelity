import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Domo rosa con la cara de Fido que asoma por el borde inferior de la
/// pantalla (login). Se dibuja en código para escalar a cualquier ancho.
class FidoDome extends StatelessWidget {
  final double height;

  const FidoDome({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRect(child: CustomPaint(painter: _FidoDomePainter())),
      ),
    );
  }
}

class _FidoDomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Domo: óvalo más ancho que la pantalla, recortado por el borde inferior.
    final dome = Rect.fromLTWH(-0.12 * w, 0, 1.24 * w, h * 2);
    canvas.drawOval(dome, Paint()..color = AppColors.pink);

    final ink = Paint()..color = AppColors.black;
    final eyeRadius = (w * 0.041).clamp(0.0, h * 0.08);
    final eyeY = h * 0.72;
    canvas.drawCircle(Offset(w * 0.37, eyeY), eyeRadius, ink);
    canvas.drawCircle(Offset(w * 0.61, eyeY), eyeRadius, ink);

    final smile = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = eyeRadius * 0.9;
    final smileWidth = w * 0.15;
    final smileRect = Rect.fromCenter(
      center: Offset(w * 0.49, h * 0.83),
      width: smileWidth,
      height: smileWidth * 0.9,
    );
    canvas.drawArc(smileRect, 0.15, 2.85, false, smile);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
