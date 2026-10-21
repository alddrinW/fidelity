import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Una tarjeta que se raspa para revelar lo que hay debajo.
///
/// El usuario arrastra el dedo (o el mouse) y la capa que tapa el premio se
/// borra donde pasa. Cuando ya se rascó suficiente, la capa desaparece y el
/// premio queda a la vista.
class ScratchCard extends StatefulWidget {
  /// Lo que se revela al raspar.
  final Widget child;

  /// Pista que se ve en la capa (se borra al rascarla).
  final String hint;

  /// Color de la capa.
  final Color coverColor;

  /// Color de la pista.
  final Color hintColor;

  /// Se avisa cuando el premio queda completamente a la vista.
  final VoidCallback? onRevealed;

  /// Si es `true` ya no hay nada que raspar (p. ej. la gift card está canjeada).
  final bool revealed;

  /// Grosor del raspado.
  final double strokeWidth;

  const ScratchCard({
    super.key,
    required this.child,
    this.hint = 'RASPE AQUÍ',
    this.coverColor = AppColors.pink,
    this.hintColor = AppColors.black,
    this.onRevealed,
    this.revealed = false,
    this.strokeWidth = 44,
  });

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  final List<Path> _strokes = [];
  Offset? _last;
  double _scratched = 0;
  bool _done = false;

  bool get _isRevealed => widget.revealed || _done;

  void _onStart(DragStartDetails details) {
    if (_isRevealed) return;
    final path = Path()..moveTo(details.localPosition.dx, details.localPosition.dy);
    setState(() {
      _strokes.add(path);
      _last = details.localPosition;
    });
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_isRevealed || _last == null) return;
    final moved = (details.localPosition - _last!).distance;
    _last = details.localPosition;

    setState(() {
      _strokes.last.lineTo(details.localPosition.dx, details.localPosition.dy);
      _scratched += moved;
    });

    // Raspó bastante: el premio queda a la vista.
    final width = context.size?.width ?? 0;
    if (width > 0 && _scratched > width * 0.8 && !_done) {
      setState(() => _done = true);
      widget.onRevealed?.call();
    }
  }

  void _onEnd(DragEndDetails details) {
    _last = null;
  }

  void _onCancel() {
    _last = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (!_isRevealed)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _done,
              child: AnimatedOpacity(
                opacity: _done ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onStart,
                  onPanUpdate: _onUpdate,
                  onPanEnd: _onEnd,
                  onPanCancel: _onCancel,
                  child: CustomPaint(
                    painter: _ScratchPainter(
                      strokes: _strokes,
                      coverColor: widget.coverColor,
                      hint: widget.hint,
                      hintColor: widget.hintColor,
                      strokeWidth: widget.strokeWidth,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dibuja la capa que tapa el premio y borra por donde se raspa.
class _ScratchPainter extends CustomPainter {
  final List<Path> strokes;
  final Color coverColor;
  final String hint;
  final Color hintColor;
  final double strokeWidth;

  _ScratchPainter({
    required this.strokes,
    required this.coverColor,
    required this.hint,
    required this.hintColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja en una capa aparte para poder borrar con BlendMode.clear.
    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(Offset.zero & size, Paint()..color = coverColor);

    // La pista "raspe aquí".
    final hintPainter = TextPainter(
      text: TextSpan(
        text: hint,
        style: AppTypography.label(size: 13, tracking: 4, color: hintColor),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 16);
    hintPainter.paint(
      canvas,
      Offset(
        (size.width - hintPainter.width) / 2,
        (size.height - hintPainter.height) / 2,
      ),
    );

    // Lo raspado se borra.
    final erase = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      canvas.drawPath(stroke, erase);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScratchPainter old) =>
      old.strokes.length != strokes.length || old.coverColor != coverColor;
}

/// Un borde troquelado con muescas, como el de un cheque: separa la parte
/// izquierda de la derecha del cheque.
class PerforatedDivider extends StatelessWidget {
  final double width;

  const PerforatedDivider({super.key, this.width = 2});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: CustomPaint(
        painter: _PerforationPainter(width: width),
        size: Size.infinite,
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  final double width;

  _PerforationPainter({required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final dash = Paint()
      ..color = AppColors.black
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // La línea punteada.
    double y = 12;
    while (y < size.height - 12) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 6, size.height - 12)), dash);
      y += 12;
    }

    // Las muescas de arriba y de abajo.
    final notch = Paint()..color = AppColors.white;
    canvas.drawCircle(Offset(x, 0), 11, notch);
    canvas.drawCircle(Offset(x, size.height), 11, notch);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.width != width;
}
