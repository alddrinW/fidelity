import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../l10n/translator.dart';
import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';

/// Cabecera de pantalla: flecha de retroceso a la izquierda y título Anton
/// centrado. El título se reduce si no cabe, sin invadir la flecha.
class AppPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  /// Acción al extremo derecho (p. ej. el check de guardar). Ocupa el mismo
  /// espacio que la flecha para que el título quede centrado.
  final Widget? trailing;

  /// Ancho de la acción de la derecha (y del hueco de la flecha, para que el
  /// título siga centrado). Se amplía cuando hay más de un botón.
  final double trailingWidth;

  const AppPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.trailingWidth = _slot,
  });

  static const double _slot = 56;

  @override
  Widget build(BuildContext context) {
    final canPop = onBack != null || Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: trailingWidth,
            child: canPop
                ? IconButton(
                    tooltip: context.tr('Volver'),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      size: 40,
                      color: AppColors.black,
                    ),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                : null,
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: 48),
                ),
              ),
            ),
          ),
          SizedBox(width: trailingWidth, child: trailing),
        ],
      ),
    );
  }
}
