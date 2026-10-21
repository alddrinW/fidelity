import 'package:flutter/material.dart' hide Text;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/user_avatar_circle.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../core/l10n/tr_text.dart';

/// El saludo del cliente: su foto, su nombre y la campana de la bandeja.
///
/// Vive en la parte superior del panel, arriba de las pestañas, igual que la
/// cabecera del panel del dueño de un local.
class CustomerGreeting extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;

  /// Al tocar la foto se abre el perfil.
  final VoidCallback onAvatarTap;

  const CustomerGreeting({
    super.key,
    required this.displayName,
    required this.onAvatarTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Mi perfil',
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Hero: anima la transición del avatar al entrar al perfil.
                  // El mismo widget vuela como UNA sola pieza (child +
                  // flightShuttleBuilder), sin rearmarse.
                  Hero(
                    tag: 'user_avatar',
                    flightShuttleBuilder: (_, __, ___, ____, _____) =>
                        UserAvatarCircle(avatarUrl: avatarUrl),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: UserAvatarCircle(avatarUrl: avatarUrl),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.black, width: 1),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 11,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (displayName.isNotEmpty)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hola, $displayName',
                  style: AppTypography.display(size: 34),
                ),
              ),
            )
          else
            const Spacer(),
          const NotificationBell(),
        ],
      ),
    );
  }
}
