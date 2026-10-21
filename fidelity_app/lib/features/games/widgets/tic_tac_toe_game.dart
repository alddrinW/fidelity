import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Tres en raya contra la computadora. El cliente es la X y empieza; la
/// computadora responde desde el servidor. El tablero llega de `play`:
/// `board` (9 casillas: "", "X" u "O") y `line` (la línea ganadora, si hay).
class TicTacToeGame extends StatelessWidget {
  final Map<String, dynamic> play;

  /// Si se puede jugar (la partida sigue y no se está esperando respuesta).
  final bool enabled;

  final ValueChanged<int> onMove;

  const TicTacToeGame(
      {super.key,
      required this.play,
      required this.onMove,
      this.enabled = true});

  List<String> get _board => ((play['board'] as List?) ?? List.filled(9, ''))
      .map((c) => c.toString())
      .toList();

  Set<int> get _line => ((play['line'] as List?) ?? const [])
      .map((i) => (i as num).toInt())
      .toSet();

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final line = _line;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          enabled ? 'TU TURNO · ERES LA X' : 'JUEGA LA COMPUTADORA…',
          style: AppTypography.label(size: 13, tracking: 3),
        ),
        const SizedBox(height: 16),
        // El tablero no pasa de 360 px: en una pantalla ancha no ocupa todo el alto.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 9; i++)
                  _Cell(
                    key: ValueKey('cell-$i'),
                    mark: board[i],
                    highlighted: line.contains(i),
                    onTap: enabled && board[i].isEmpty ? () => onMove(i) : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String mark;
  final bool highlighted;
  final VoidCallback? onTap;

  const _Cell(
      {super.key,
      required this.mark,
      required this.highlighted,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: mark.isEmpty ? 'Casilla vacía' : 'Casilla con $mark',
      excludeSemantics: true,
      child: Material(
        color: highlighted ? AppColors.pink : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.black, width: 1.4),
        ),
        child: InkWell(
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          onTap: onTap,
          child: Center(
            child: AnimatedScale(
              scale: mark.isEmpty ? 0.4 : 1,
              duration: const Duration(milliseconds: 180),
              child: Text(
                mark,
                style: AppTypography.display(size: 64, color: AppColors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
