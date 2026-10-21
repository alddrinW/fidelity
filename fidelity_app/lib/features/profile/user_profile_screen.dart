import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_selector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/validators/app_validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_nav_row.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/user_avatar_circle.dart';
import '../auth/data/auth_repository.dart';
import '../campaigns/my_gifts_screen.dart';
import '../feedback/data/feedback_repository.dart';
import '../feedback/feedback_inbox_screen.dart';
import '../help/business_faqs_screen.dart';
import '../help/faqs_screen.dart';
import '../notifications/notifications_screen.dart';
import 'providers/user_profile_provider.dart';
import 'widgets/change_password_dialog.dart';
import '../../core/l10n/tr_text.dart';

/// Ajustes de mi perfil: datos personales, foto, contraseña, ayuda y cuenta.
/// Sirve tanto al cliente como al dueño de un negocio ("Ajustar mis datos").
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: UserProfileView());
  }
}

/// El contenido de "Mi perfil" sin su propio [Scaffold], para poder usarlo
/// también como pestaña del panel de usuario.
class UserProfileView extends ConsumerStatefulWidget {
  const UserProfileView({super.key});

  @override
  ConsumerState<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends ConsumerState<UserProfileView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  /// Foto elegida y aún no guardada.
  PickedImage? _newAvatar;

  bool get _isBusinessOwner =>
      ref.read(authRepositoryProvider).currentUser?.role == 'business';

  @override
  void initState() {
    super.initState();
    final state = ref.read(userProfileProvider);
    _fullNameController = TextEditingController(text: state.fullName);
    _phoneController = TextEditingController(text: state.phone);
    _emailController = TextEditingController(text: state.email ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await pickImageFromGallery();
      if (picked != null && mounted) setState(() => _newAvatar = picked);
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(userProfileProvider.notifier).saveProfile(
          fullName: _fullNameController.text,
          phone: _phoneController.text,
          avatarDataUri: _newAvatar?.dataUri,
        );

    if (!mounted) return;
    if (success) {
      await _showSavedAnimation();
      // Solo se vuelve atrás si esta vista se abrió como pantalla propia
      // (como pestaña del panel no hay a dónde volver).
      if (mounted && Navigator.of(context).canPop()) Navigator.pop(context, true);
    } else {
      final error = ref.read(userProfileProvider).error;
      if (error != null) _showError(error);
    }
  }

  /// Animación de éxito tras guardar. Se cierra sola a los ~1.4 s y recién
  /// entonces volvemos a la pantalla anterior.
  Future<void> _showSavedAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogCtx) {
        final navigator = Navigator.of(dialogCtx);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (navigator.canPop()) navigator.pop();
        });
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.pink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.black,
                    size: 48,
                  ),
                ).animate().scale(
                      duration: 450.ms,
                      curve: const Cubic(0.34, 1.56, 0.64, 1),
                    ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: Text(
                    'PERFIL ACTUALIZADO',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(size: 24),
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 250.ms).scale(
              begin: const Offset(0.85, 0.85),
              curve: Curves.easeOut,
            );
      },
    );
  }

  Future<void> _changePassword() async {
    final change = await showDialog<PasswordChange>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (change == null) return;

    final success = await ref.read(userProfileProvider.notifier).changePassword(
          currentPassword: change.current,
          newPassword: change.next,
        );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada'),
          backgroundColor: AppColors.black,
        ),
      );
    } else {
      _showError(ref.read(userProfileProvider).error ?? 'No se pudo cambiar la contraseña.');
    }
  }

  void _openMyGifts() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyGiftsScreen()));
  }

  void _openMyFeedback() {
    final repository = ref.read(feedbackRepositoryProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackInboxScreen(
          title: 'Mis opiniones',
          load: repository.listMine,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openFaqs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _isBusinessOwner ? const BusinessFaqsScreen() : const FaqsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserProfileState>(userProfileProvider, (previous, next) {
      if (previous?.fullName != next.fullName && next.fullName.isNotEmpty) {
        _fullNameController.text = next.fullName;
      }
      if (previous?.phone != next.phone && next.phone.isNotEmpty) {
        _phoneController.text = next.phone;
      }
      if (previous?.email != next.email && (next.email ?? '').isNotEmpty) {
        _emailController.text = next.email!;
      }
    });

    final state = ref.watch(userProfileProvider);

    return SafeArea(
      bottom: false,
      child: AppResponsiveBody(
        child: Column(
          children: [
            const AppPageHeader(title: 'Mi perfil'),
            Expanded(
              child: state.isLoading && state.fullName.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _AvatarEditor(
                                avatarUrl: state.avatarUrl,
                                newAvatarBytes: _newAvatar?.bytes,
                                onTap: _pickImage,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 12),
                              child: Text(
                                'MIS DATOS',
                                style: AppTypography.label(size: 13, tracking: 5),
                              ),
                            ),
                            AppTextField(
                              controller: _fullNameController,
                              hint: 'Nombres y apellidos',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: AppValidators.validateName,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _emailController,
                              hint: 'Correo electrónico',
                              icon: Icons.mail_outline_rounded,
                              readOnly: true,
                              trailing: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _phoneController,
                              hint: 'Teléfono',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: AppValidators.validateEcuadorPhone,
                            ),
                            const SizedBox(height: 16),
                            AppNavRow(
                              icon: Icons.lock_outline_rounded,
                              label: 'Cambiar contraseña',
                              onTap: _changePassword,
                            ),
                            const SizedBox(height: 16),
                            if (!_isBusinessOwner) ...[
                              AppNavRow(
                                icon: Icons.notifications_none_rounded,
                                label: 'Notificaciones',
                                onTap: _openNotifications,
                              ),
                              const SizedBox(height: 16),
                              AppNavRow(
                                icon: Icons.card_giftcard_rounded,
                                label: 'Mis regalos',
                                onTap: _openMyGifts,
                              ),
                              const SizedBox(height: 16),
                              AppNavRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Mis sugerencias y reclamos',
                                onTap: _openMyFeedback,
                              ),
                              const SizedBox(height: 16),
                            ],
                            const LanguageRow(),
                            const SizedBox(height: 16),
                            AppNavRow(
                              icon: Icons.help_outline_rounded,
                              label: 'Preguntas frecuentes',
                              onTap: _openFaqs,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '¿Necesitas cerrar sesión o eliminar tu cuenta?',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                size: 13,
                                weight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ]
                              .animate(interval: 50.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.05),
                        ),
                      ),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 8, 48, 24),
              child: AppPrimaryButton(
                label: 'Guardar',
                isLoading: state.isLoading,
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto de perfil con lápiz de edición y leyenda. Conserva el `Hero` que enlaza
/// con el avatar de Inicio para que vuele como una sola pieza.
class _AvatarEditor extends StatelessWidget {
  final String? avatarUrl;
  final Uint8List? newAvatarBytes;
  final VoidCallback onTap;

  const _AvatarEditor({
    required this.avatarUrl,
    required this.newAvatarBytes,
    required this.onTap,
  });

  static const double _size = 100;

  @override
  Widget build(BuildContext context) {
    Widget avatar() => UserAvatarCircle(
          avatarUrl: avatarUrl,
          newAvatarBytes: newAvatarBytes,
        );

    final photo = SizedBox(width: _size, height: _size, child: avatar());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Cambiar foto de perfil',
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Hero(
                  tag: 'user_avatar',
                  flightShuttleBuilder: (_, __, ___, ____, _____) => avatar(),
                  child: photo,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.black, width: 1),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'FOTO DE PERFIL',
          style: AppTypography.body(size: 12, weight: FontWeight.w300),
        ),
      ],
    );
  }
}
