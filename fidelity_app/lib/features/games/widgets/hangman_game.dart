import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

/// Ahorcado. La palabra la tiene el servidor: llega de `play` solo con los
/// guiones (`masked`), las letras ya probadas (`guessed`), los errores (`wrong`
/// de `maxWrong`) y, si el cliente perdió, la palabra completa (`word`).
class HangmanGame extends StatelessWidget {
  final Map<String, dynamic> play;
  final bool enabled;
  final ValueChanged<String> onGuess;

  const HangmanGame({super.key, required this.play, required this.onGuess, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final masked = ((play['masked'] as List?) ?? const []).map((c) => c.toString()).toList();
    final guessed = ((play['guessed'] as List?) ?? const []).map((c) => c.toString()).toSet();
    final wrong = (play['wrong'] as num?)?.toInt() ?? 0;
    final maxWrong = (play['maxWrong'] as num?)?.toInt() ?? 6;
    final word = play['word']?.toString();
    final word0 = word?.split('');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 170,
          child: CustomPaint(
            size: const Size(180, 170),
            painter: _GallowsPainter(wrong),
          ),
        ),
        Text(
          'ERRORES: $wrong DE $maxWrong',
          style: AppTypography.label(size: 12, tracking: 3, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          key: const ValueKey('masked-word'),
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < masked.length; i++)
              Container(
                width: 34,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.black, width: 2.4)),
                ),
                child: Text(
                  masked[i] == '_' ? (word0 != null ? word0[i] : '') : masked[i],
                  style: AppTypography.display(
                    size: 34,
                    // La palabra que faltó se muestra en gris.
                    color: masked[i] == '_' && word0 != null
                        ? AppColors.textSecondary
                        : AppColors.black,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final letter in _letters)
              _Key(
                letter: letter,
                used: guessed.contains(letter),
                hit: guessed.contains(letter) && masked.contains(letter),
                onTap: enabled && !guessed.contains(letter) ? () => onGuess(letter) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String letter;
  final bool used;
  final bool hit;
  final VoidCallback? onTap;

  const _Key({required this.letter, required this.used, required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: used ? 'Letra $letter, ${hit ? 'acertada' : 'fallada'}' : 'Letra $letter',
      excludeSemantics: true,
      child: Material(
        color: used ? (hit ? AppColors.pink : AppColors.surfaceMuted) : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: used && !hit ? AppColors.placeholderIcon : AppColors.black, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 42,
            child: Center(
              child: Text(
                letter,
                style: AppTypography.display(
                  size: 22,
                  color: used && !hit ? AppColors.placeholderIcon : AppColors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La horca: se va dibujando una parte del muñeco por cada error.
class _GallowsPainter extends CustomPainter {
  final int wrong;

  _GallowsPainter(this.wrong);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final cx = w / 2 + 14;

    // Base, poste y brazo.
    canvas.drawLine(Offset(cx - 70, h - 6), Offset(cx + 20, h - 6), stroke);
    canvas.drawLine(Offset(cx - 40, h - 6), Offset(cx - 40, 8), stroke);
    canvas.drawLine(Offset(cx - 40, 8), Offset(cx + 20, 8), stroke);
    canvas.drawLine(Offset(cx + 20, 8), Offset(cx + 20, 34), stroke);

    if (wrong >= 1) canvas.drawCircle(Offset(cx + 20, 50), 16, stroke);
    if (wrong >= 2) canvas.drawLine(Offset(cx + 20, 66), Offset(cx + 20, 108), stroke);
    if (wrong >= 3) canvas.drawLine(Offset(cx + 20, 76), Offset(cx + 2, 96), stroke);
    if (wrong >= 4) canvas.drawLine(Offset(cx + 20, 76), Offset(cx + 38, 96), stroke);
    if (wrong >= 5) canvas.drawLine(Offset(cx + 20, 108), Offset(cx + 4, 136), stroke);
    if (wrong >= 6) canvas.drawLine(Offset(cx + 20, 108), Offset(cx + 36, 136), stroke);
  }

  @override
  bool shouldRepaint(_GallowsPainter old) => old.wrong != wrong;
}
