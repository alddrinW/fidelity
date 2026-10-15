import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_selector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/auth_error_translator.dart';
import '../../core/validators/app_validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_wordmark.dart';
import '../../core/widgets/fido_dome.dart';
import 'data/auth_repository.dart';
import 'register_choice_screen.dart';
import '../../core/l10n/tr_text.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AuthErrorTranslator.translate(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      // AuthWrapper detecta automáticamente el cambio de sesión a través del notifier
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisa tu correo para recuperar la contraseña.'),
            backgroundColor: AppColors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _showRecoveryDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _RecoveryDialog(initialEmail: _emailController.text),
    );
    if (email != null && mounted) await _resetPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final domeHeight =
                  (constraints.maxHeight * 0.26).clamp(120.0, 260.0);

              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: LanguageButton(),
                                ),
                                const AppWordmark(size: 72)
                                    .animate()
                                    .scale(
                                      duration: AppTheme.animDurationSlow,
                                      curve: AppTheme.animCurveElastic,
                                    )
                                    .fadeIn(),
                                const SizedBox(height: 40),
                                AppTextField(
                                  controller: _emailController,
                                  hint: 'Correo electrónico',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Ingresa tu correo electrónico'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _passwordController,
                                  hint: 'Contraseña',
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => _isLoading ? null : _login(),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Ingresa tu contraseña'
                                      : null,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showRecoveryDialog,
                                    child: Text(
                                      '¿Olvidaste tu contraseña?',
                                      style: AppTypography.body(
                                        size: 14,
                                        weight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AppPrimaryButton(
                                  label: 'Iniciar sesión',
                                  onPressed: _login,
                                  isLoading: _isLoading,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: AppTextAction(
                                    label: 'Registrarme',
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterChoiceScreen(),
                                              ),
                                            ),
                                  ),
                                ),
                              ]
                                  .animate(interval: 80.ms)
                                  .slideY(
                                    begin: 0.1,
                                    duration: AppTheme.animDurationQuick,
                                    curve: AppTheme.animCurveStandard,
                                  )
                                  .fadeIn(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!keyboardOpen) FidoDome(height: domeHeight),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Diálogo de recuperación de contraseña. Es un widget propio para que el
/// controlador del campo viva y se libere junto con el diálogo.
class _RecoveryDialog extends StatefulWidget {
  final String initialEmail;

  const _RecoveryDialog({required this.initialEmail});

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail.trim());
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
        'RECUPERAR CONTRASEÑA',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 24),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Te enviaremos un enlace para crear una nueva contraseña.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _controller,
              hint: 'Correo electrónico',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: AppValidators.validateEmail,
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
        ElevatedButton(
          onPressed: _submit,
          child: const Text('ENVIAR'),
        ),
      ],
    );
  }
}
