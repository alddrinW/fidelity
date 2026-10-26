import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/referrals_repository.dart';
import 'points_text.dart';

/// Para quien ya tiene cuenta y un amigo le pasó su código: lo escribe aquí y
/// cuenta como amigo de quien lo invitó.
Future<void> showRedeemReferralDialog(BuildContext context, ReferralsRepository repository) async {
  final result = await showDialog<ReferralRedeemed>(
    context: context,
    builder: (_) => RedeemReferralDialog(repository: repository),
  );
  if (result != null && context.mounted) {
    final message = result.friendPoints > 0
        ? '¡Listo! Con tu primer escaneo ganas ${pointsText(result.friendPoints)} de invitación'
        : (result.referrerName == null || result.referrerName!.isEmpty
            ? '¡Listo! Tu amigo ya cuenta contigo'
            : '¡Listo! ${result.referrerName} ya cuenta contigo');
    DashboardAnimatedToast.show(context, message);
  }
}

class RedeemReferralDialog extends StatefulWidget {
  final ReferralsRepository repository;

  const RedeemReferralDialog({super.key, required this.repository});

  @override
  State<RedeemReferralDialog> createState() => _RedeemReferralDialogState();
}

class _RedeemReferralDialogState extends State<RedeemReferralDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String? _validate(String? value) =>
      (value ?? '').trim().length < 6 ? 'Escribe el código de tu amigo' : null;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.redeem(_controller.text);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'CÓDIGO DE UN AMIGO',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Si un amigo te invitó a Fidelity, escribe su código para que cuentes como su amigo invitado.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 15, weight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _controller,
                hint: 'AMG-XXXXXX',
                icon: Icons.group_add_rounded,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                onSubmitted: (_) => _send(),
                validator: _validate,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _send,
          child: const Text('USAR CÓDIGO'),
        ),
      ],
    );
  }
}
