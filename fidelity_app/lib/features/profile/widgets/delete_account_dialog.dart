import 'package:flutter/material.dart' hide Text;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/l10n/tr_text.dart';

/// Confirmación para eliminar la cuenta: exige escribir "ELIMINAR".
/// Cierra con `true` solo si el usuario confirma.
class DeleteAccountDialog extends StatefulWidget {
  /// Texto adicional según el rol (p. ej. mencionar que se borra el negocio).
  final String detail;

  const DeleteAccountDialog({super.key, required this.detail});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  static const _keyword = 'ELIMINAR';
  final _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim().toUpperCase() == _keyword;
      if (ok != _canConfirm) setState(() => _canConfirm = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        '¿ELIMINAR MI CUENTA?',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esta acción es irreversible. ${widget.detail}',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15),
            ),
            const SizedBox(height: 20),
            Text(
              'Escribe "$_keyword" para confirmar:',
              style: AppTypography.body(size: 13, weight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.label(size: 16, tracking: 4),
              decoration: const InputDecoration(hintText: _keyword),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
            foregroundColor: AppColors.white,
            disabledForegroundColor: AppColors.white,
          ),
          child: const Text('ELIMINAR'),
        ),
      ],
    );
  }
}
