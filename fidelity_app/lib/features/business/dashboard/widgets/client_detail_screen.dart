import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/fidely_badge.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_responsive_body.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../rewards/rewards_management_screen.dart';
import '../../../../core/l10n/tr_text.dart';

/// La ficha de un cliente del local: sus puntos y sus premios.
///
/// Al abrir un cliente desde la pestaña CLIENTES, aquí están sus premios (los
/// que puede entregarle) en vez de una pestaña aparte en el panel.
class ClientDetailScreen extends ConsumerWidget {
  /// La tarjeta del cliente (la de `dashboardProvider`).
  final Map<String, dynamic> card;

  /// Los datos del local (para saber cuántos puntos pide el premio).
  final Map<String, dynamic> business;

  const ClientDetailScreen({
    super.key,
    required this.card,
    required this.business,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = card['profiles'];
    final name = (profile?['full_name'] ?? 'Usuario').toString();
    final points = (card['current_points'] as num?)?.toInt() ?? 0;
    final total = (card['total_points_lifetime'] as num?)?.toInt() ?? 0;
    final claimed = (card['rewards_claimed'] as num?)?.toInt() ?? 0;
    final required = (business['points_required'] as num?)?.toInt() ?? 10;
    final userId = card['user_id']?.toString();

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(title: 'Cliente'),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: AppCard(
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PersonAvatar(
                            name: name,
                            avatarUrl: profile?['avatar_url']?.toString(),
                            size: 64,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toUpperCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.display(size: 24),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    AppChip(
                                      label: '$points/$required PUNTOS',
                                      style: AppChipStyle.dark,
                                    ),
                                    if (card['is_fidely'] == true) const FidelyBadge(),
                                    if (profile?['is_demo'] == true)
                                      const AppChip(label: 'Demo', style: AppChipStyle.outline),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _Stat(label: 'En total', value: '$total')),
                          Expanded(child: _Stat(label: 'Premios', value: '$claimed')),
                          Expanded(child: _Stat(label: 'Meta', value: '$required')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('PREMIOS', style: AppTypography.label(size: 13, tracking: 4)),
                ),
              ),
              Expanded(
                child: RewardsList(
                  businessId: business['id'].toString(),
                  userId: userId,
                  emptyTitle: 'Sin premios',
                  emptyMessage: 'Este cliente todavía no ha ganado premios.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un dato del cliente.
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.display(size: 24)),
        Text(
          label.toUpperCase(),
          style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
