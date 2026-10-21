import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/l10n/tr_text.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'delete_account_dialog.dart';

/// Acción "Cerrar sesión" (con su confirmación). Vive en las preguntas
/// frecuentes: ahí el usuario la encuentra cuando la necesita.
class AccountLogoutAction extends ConsumerWidget {
  const AccountLogoutAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPrimaryButton(
      label: 'Cerrar sesión',
      onPressed: () => _confirmLogout(context, ref),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.logout_rounded,
        title: '¿Cerrar sesión?',
        message: '¿Estás seguro de que deseas salir de tu cuenta?',
        primaryLabel: 'Cerrar sesión',
        onPrimary: () => ref.read(authStateProvider.notifier).logout(),
        secondaryLabel: 'Cancelar',
      ),
    );
  }
}

/// Acción "Eliminar mi cuenta" (con la confirmación que pide escribir
/// ELIMINAR). También vive en las preguntas frecuentes.
class AccountDeleteAction extends ConsumerWidget {
  const AccountDeleteAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _delete(context, ref),
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        label: const Text('ELIMINAR MI CUENTA'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label(size: 12, tracking: 2),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final isBusinessOwner =
        ref.read(authRepositoryProvider).currentUser?.role == 'business';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteAccountDialog(
        detail: isBusinessOwner
            ? 'Se borrarán tus datos, tu negocio, los premios y los puntos acumulados.'
            : 'Se borrarán todos tus datos personales.',
      ),
    );
    if (confirm != true || !context.mounted) return;

    final success = await ref.read(userProfileProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(userProfileProvider).error ?? 'No se pudo eliminar la cuenta.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
