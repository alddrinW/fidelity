import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/l10n/translator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../campaigns/widgets/schedule_row.dart';
import '../data/games_repository.dart';

/// Un juego que un local le mandó al cliente, con su estado: para jugar,
/// programado, ganado, perdido o vencido. Tocarlo abre el juego (o su resultado).
class GameInviteTile extends StatelessWidget {
  final GameInvite invite;
  final VoidCallback onTap;

  const GameInviteTile({super.key, required this.invite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, style) = switch (invite.status) {
      'finished' => invite.result == 'won' ? ('Ganaste', AppChipStyle.dark) : ('Perdiste', AppChipStyle.outline),
      'expired' => ('Venció', AppChipStyle.outline),
      'upcoming' => ('Programado', AppChipStyle.pink),
      _ => ('Jugar', AppChipStyle.dark),
    };

    return Semantics(
      button: true,
      label: '${invite.gameName}: ${context.tr(label)}',
      excludeSemantics: true,
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
              child: Icon(invite.game?.icon ?? Icons.sports_esports_rounded, color: AppColors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.gameName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(size: 22),
                  ),
                  if (invite.prizeLabel != null)
                    Text(
                      'Gana: ${invite.prizeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(size: 13, weight: FontWeight.w300),
                    ),
                  if (_detail != null)
                    Text(
                      _detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(size: 12, weight: FontWeight.w300, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppChip(label: label, style: style),
          ],
        ),
      ),
    );
  }

  /// La línea de abajo: cuándo empieza o cuántos intentos y hasta cuándo.
  String? get _detail {
    if (invite.status == 'upcoming' && invite.startsAt != null) {
      return 'Empieza ${formatCampaignDateTime(invite.startsAt!)}';
    }
    if (invite.isOpen) {
      final left = invite.attemptsLeft == 1 ? 'Te queda 1 intento' : 'Te quedan ${invite.attemptsLeft} intentos';
      return invite.expiresAt == null ? left : '$left · Hasta el ${formatCampaignDateTime(invite.expiresAt!)}';
    }
    return null;
  }
}

/// Los juegos que [businessId] le mandó al cliente: primero los que puede jugar
/// ahora, luego los programados y al final los que ya terminaron o vencieron.
List<GameInvite> invitesOfBusiness(List<GameInvite> invites, String businessId) {
  int rank(GameInvite i) => i.isOpen ? 0 : (i.isUpcoming ? 1 : 2);
  final mine = [for (final i in invites) if (i.businessId == businessId) i];
  // Dart ordena de forma estable: dentro de cada grupo queda el orden del servidor.
  mine.sort((a, b) => rank(a).compareTo(rank(b)));
  return mine;
}
