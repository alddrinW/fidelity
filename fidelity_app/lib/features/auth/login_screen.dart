import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
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

  Future<void> _showRecoveryDialog() async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecoveryDialog(initialEmail: _emailController.text),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
          backgroundColor: AppColors.black,
        ),
      );
    }
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

/// Recuperación de contraseña en dos pasos dentro de un diálogo: 1) el correo,
/// al que se envía un código de 6 dígitos; 2) el código y la nueva contraseña.
/// Cierra con `true` si la contraseña se cambió.
class _RecoveryDialog extends ConsumerStatefulWidget {
  final String initialEmail;

  const _RecoveryDialog({required this.initialEmail});

  @override
  ConsumerState<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends ConsumerState<_RecoveryDialog> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail.trim());
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {VoidCallback? onDone}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) onDone?.call();
    } catch (e) {
      if (mounted) setState(() => _error = AuthErrorTranslator.translate(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCode() => _run(
        () => ref.read(authRepositoryProvider).forgotPassword(_email.text),
        onDone: () => setState(() => _codeSent = true),
      );

  Future<void> _changePassword() => _run(
        () => ref.read(authRepositoryProvider).resetPassword(
              email: _email.text,
              code: _code.text,
              newPassword: _password.text,
            ),
        onDone: () => Navigator.of(context).pop(true),
      );

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
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _codeSent
                    ? 'Si el correo está registrado, te enviamos un código de 6 dígitos. '
                        'Vence en 15 minutos.'
                    : 'Te enviaremos un código para crear una nueva contraseña.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 15, weight: FontWeight.w300),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _email,
                hint: 'Correo electrónico',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _codeSent ? TextInputAction.next : TextInputAction.done,
                enabled: !_codeSent && !_isLoading,
                onSubmitted: (_) => _codeSent ? null : _sendCode(),
                validator: AppValidators.validateEmail,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _code,
                  hint: 'Código de 6 dígitos',
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) =>
                      RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Escribe los 6 dígitos',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _password,
                  hint: 'Nueva contraseña',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _changePassword(),
                  validator: AppValidators.validatePassword,
                ),
              ],
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (_codeSent ? _changePassword : _sendCode),
          child: Text(_codeSent ? 'CAMBIAR CONTRASEÑA' : 'ENVIAR CÓDIGO'),
        ),
      ],
    );
  }
}
