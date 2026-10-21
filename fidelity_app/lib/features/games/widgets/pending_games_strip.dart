import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/games_repository.dart';
import '../game_invite_screen.dart';

/// Los juegos que los locales le mandaron al cliente y todavía no ha jugado,
/// para que no dependan de que abra la notificación. Si no hay ninguno, no
/// ocupa espacio.
class PendingGamesStrip extends ConsumerWidget {
  const PendingGamesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myGameInvitesProvider).valueOrNull ?? const <GameInvite>[];
    final open = invites.where((i) => i.isOpen).toList();
    if (open.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Semantics(
              header: true,
              child: Text('JUEGA Y GANA', style: AppTypography.label(size: 16, tracking: 0.5)),
            ),
          ),
          for (final invite in open) ...[
            _InviteTile(
              invite: invite,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GameInviteScreen(inviteId: invite.id)),
                );
                ref.invalidate(myGameInvitesProvider);
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final GameInvite invite;
  final VoidCallback onTap;

  const _InviteTile({required this.invite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${invite.gameName} de ${invite.businessName ?? 'un local'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                  child: Icon(invite.game?.icon ?? Icons.sports_esports_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.gameName.toUpperCase(),
                        style: AppTypography.display(size: 22, color: AppColors.white),
                      ),
                      Text(
                        '${invite.businessName ?? 'Un local'}'
                        '${invite.prizeLabel == null ? '' : ' · Gana: ${invite.prizeLabel}'}'
                        ' · ${invite.attemptsLeft == 1 ? 'Te queda 1 intento' : 'Te quedan ${invite.attemptsLeft} intentos'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: AppColors.black),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
