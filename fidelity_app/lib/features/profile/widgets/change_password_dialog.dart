import 'package:flutter/material.dart' hide Text;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validators/app_validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/l10n/tr_text.dart';

typedef PasswordChange = ({String current, String next});

/// Pide la contraseña actual y la nueva. Cierra devolviendo [PasswordChange]
/// o `null` si el usuario cancela. Es un widget propio para que los
/// controladores se liberen junto con el diálogo.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      current: _currentController.text,
      next: _newController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'CAMBIAR CONTRASEÑA',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _currentController,
                hint: 'Contraseña actual',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _newController,
                hint: 'Nueva contraseña',
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                helperText: 'Mínimo 8 caracteres, con letras y números',
                textInputAction: TextInputAction.next,
                validator: AppValidators.validatePassword,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _confirmController,
                hint: 'Confirma la nueva contraseña',
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) =>
                    AppValidators.validateConfirmPassword(v, _newController.text),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('GUARDAR')),
      ],
    );
  }
}
