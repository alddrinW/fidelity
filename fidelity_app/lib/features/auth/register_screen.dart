import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/auth_error_translator.dart';
import '../../core/validators/app_validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_photo_picker.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import 'data/auth_repository.dart';
import '../../core/l10n/tr_text.dart';

/// Datos personales del registro. [role] llega desde la pantalla de elección:
/// 'client' (usuario) o 'business' (negocio).
class RegisterScreen extends ConsumerStatefulWidget {
  final String role;

  const RegisterScreen({super.key, this.role = 'client'});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _avatarBytes;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (mounted) setState(() => _avatarBytes = bytes);
    } catch (e) {
      debugPrint('No se pudo seleccionar la imagen: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        role: widget.role,
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;
      _showSuccessToast();
      // Si es cliente, cerramos la sesión para obligarlo a iniciar sesión
      if (widget.role == 'client') {
        await authRepo.signOut();
      }

      Future.delayed(1500.ms, () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthErrorTranslator.translate(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(milliseconds: 2500),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CUENTA CREADA CON ÉXITO',
                  style: AppTypography.label(
                    size: 13,
                    tracking: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Registro'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AppPhotoPicker(
                              caption: 'Foto de perfil',
                              image: _avatarBytes == null
                                  ? null
                                  : MemoryImage(_avatarBytes!),
                              onTap: _pickAvatar,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 12),
                            child: Text(
                              'DATOS PERSONALES',
                              style: AppTypography.label(size: 13, tracking: 5),
                            ),
                          ),
                          AppTextField(
                            controller: _fullNameController,
                            hint: 'Nombres y apellidos',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: AppValidators.validateName,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailController,
                            hint: 'Correo electrónico',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: AppValidators.validateEmail,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _phoneController,
                            hint: 'Teléfono',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: AppValidators.validateEcuadorPhone,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            helperText: 'Mínimo 6 caracteres',
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: AppValidators.validatePassword,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _confirmPasswordController,
                            hint: 'Confirma tu contraseña',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _isLoading ? null : _register(),
                            validator: (v) => AppValidators.validateConfirmPassword(
                              v,
                              _passwordController.text,
                            ),
                          ),
                        ]
                            .animate(interval: 60.ms)
                            .fadeIn()
                            .slideY(begin: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 32, 32),
                  child: AppCircleButton(
                    tooltip: widget.role == 'business'
                        ? 'Continuar con los datos del negocio'
                        : 'Crear mi cuenta',
                    isLoading: _isLoading,
                    onPressed: _register,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
