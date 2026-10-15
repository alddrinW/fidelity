import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../../payments/data/payments_repository.dart';

/// Pregunta de confirmación: devuelve `true` solo si se pulsa el botón principal.
Future<bool> _confirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
}) {
  final answer = Completer<bool>();
  showDialog<void>(
    context: context,
    builder: (_) => AppMessageDialog(
      icon: icon,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: () => answer.complete(true),
      secondaryLabel: 'Cancelar',
    ),
  ).then((_) {
    // Cerrar tocando fuera del diálogo equivale a cancelar.
    if (!answer.isCompleted) answer.complete(false);
  });
  return answer.future;
}

/// El administrador valida el pago: activa la cuenta y emite el comprobante.
/// Devuelve `true` si el pago quedó validado.
Future<bool> reviewValidate(
  BuildContext context,
  PaymentOrder payment,
  PaymentsRepository repository,
) async {
  final confirmed = await _confirm(
    context,
    icon: Icons.verified_rounded,
    title: '¿Validar pago?',
    message: 'Confirmas que recibiste ${payment.amountLabel} de '
        '${payment.businessName}. Se activará su cuenta y recibirá su comprobante.',
    primaryLabel: 'Sí, validar',
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await repository.validate(payment.id);
    if (context.mounted) {
      DashboardAnimatedToast.show(context, 'Pago validado: cuenta activada');
    }
    return true;
  } catch (e) {
    if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    return false;
  }
}

/// El administrador rechaza el pago con un motivo que verá el dueño. Devuelve
/// `true` si el pago quedó rechazado.
Future<bool> reviewReject(
  BuildContext context,
  PaymentOrder payment,
  PaymentsRepository repository,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const RejectReasonDialog(),
  );
  if (reason == null || !context.mounted) return false;

  try {
    await repository.reject(payment.id, reason);
    if (context.mounted) DashboardAnimatedToast.show(context, 'Pago rechazado');
    return true;
  } catch (e) {
    if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    return false;
  }
}

class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({super.key});

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'RECHAZAR PAGO',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'El dueño verá este motivo y podrá reportar su pago de nuevo.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              hint: 'Motivo del rechazo',
              icon: Icons.edit_note_rounded,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Escribe el motivo';
                if (text.length > 300) return 'Máximo 300 caracteres';
                return null;
              },
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('RECHAZAR')),
      ],
    );
  }
}
