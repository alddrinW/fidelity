import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_chip.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_message_dialog.dart';
import '../../../../../core/widgets/person_avatar.dart';
import '../../providers/dashboard_provider.dart';
import '../../../../../core/l10n/tr_text.dart';

/// Escaneos de clientes por aprobar. Al aprobar se suma el punto; al rechazar
/// no se suma nada y el cliente queda en su tiempo de espera.
class TabPendingScans extends ConsumerWidget {
  const TabPendingScans({super.key});

  void _confirmReject(BuildContext context, WidgetRef ref, String scanId) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.block_rounded,
        title: '¿Rechazar escaneo?',
        message: 'El cliente no recibirá el punto y tendrá que esperar el tiempo '
            'de espera de tu local para volver a escanear.',
        primaryLabel: 'Rechazar',
        onPrimary: () => ref.read(dashboardProvider.notifier).rejectScan(scanId),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingScans = ref.watch(dashboardProvider).pendingScans;

    if (pendingScans.isEmpty) {
      return const AppEmptyState(
        title: '¡Todo al día!',
        message: 'No hay escaneos por aprobar.',
      );
    }

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: () => ref.read(dashboardProvider.notifier).loadData(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        itemCount: pendingScans.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Aprueba el escaneo para sumarle el punto al cliente.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            );
          }

          final scan = pendingScans[index - 1];
          final profile = scan['profiles'];
          final name = (profile?['full_name'] ?? 'Usuario').toString();

          return AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PersonAvatar(
                      name: name,
                      avatarUrl: profile?['avatar_url']?.toString(),
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.display(size: 20),
                                ),
                              ),
                              if (profile?['is_demo'] == true) ...[
                                const SizedBox(width: 8),
                                const AppChip(label: 'Demo', style: AppChipStyle.outline),
                              ],
                            ],
                          ),
                          Text(
                            EcuadorDateUtils.formatEcuadorTime(scan['scanned_at']).toUpperCase(),
                            style: AppTypography.body(
                              size: 12,
                              weight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmReject(context, ref, scan['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.black,
                          side: const BorderSide(color: AppColors.black, width: 1.2),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: AppTypography.label(size: 12, tracking: 2),
                        ),
                        child: const Text('RECHAZAR'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => ref
                            .read(dashboardProvider.notifier)
                            .approveScan(scan['id'], scan['loyalty_card_id']),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: AppTypography.label(size: 12, tracking: 2),
                        ),
                        child: const Text('APROBAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate(delay: ((index - 1).clamp(0, 6) * 50).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}
