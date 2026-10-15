// lib/features/business/rewards/rewards_management_screen.dart
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/realtime_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/person_avatar.dart';
import '../dashboard/widgets/dashboard_animated_toast.dart';
import 'providers/rewards_management_provider.dart';
import '../../../core/l10n/tr_text.dart';

/// Premios ganados por los clientes: el negocio los marca como entregados (o
/// los rechaza) cuando el cliente se presenta en el local.
class RewardsManagementScreen extends ConsumerStatefulWidget {
  final String businessId;
  const RewardsManagementScreen({super.key, required this.businessId});

  @override
  ConsumerState<RewardsManagementScreen> createState() => _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends ConsumerState<RewardsManagementScreen> {
  StreamSubscription<void>? _rewardsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rewardsManagementProvider.notifier).init(widget.businessId);
    });

    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) {
        ref.read(rewardsManagementProvider.notifier).init(widget.businessId);
      }
    });
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    super.dispose();
  }

  Future<void> _approveReward(String rewardId) async {
    final success = await ref.read(rewardsManagementProvider.notifier).approveReward(rewardId);
    if (!mounted) return;
    if (success) {
      DashboardAnimatedToast.show(context, 'Premio marcado como entregado');
    } else {
      final error = ref.read(rewardsManagementProvider).error;
      DashboardAnimatedToast.show(context, 'Error: $error', isError: true);
    }
  }

  Future<void> _rejectReward(String rewardId) async {
    final success = await ref.read(rewardsManagementProvider.notifier).rejectReward(rewardId);
    if (!mounted) return;
    if (success) {
      DashboardAnimatedToast.show(context, 'Premio rechazado');
    } else {
      final error = ref.read(rewardsManagementProvider).error;
      DashboardAnimatedToast.show(context, 'Error: $error', isError: true);
    }
  }

  void _confirmReject(String rewardId) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.block_rounded,
        title: '¿Rechazar premio?',
        message: 'El cliente será avisado de que su premio fue rechazado.',
        primaryLabel: 'Rechazar',
        onPrimary: () => _rejectReward(rewardId),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardsManagementProvider);

    if (state.isLoading && state.rewards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.rewards.isEmpty) {
      return AppEmptyState(title: 'Algo salió mal', message: state.error!);
    }
    if (state.rewards.isEmpty) {
      return const AppEmptyState(
        title: 'Sin premios aún',
        message: 'Aquí verás los premios por entregar y los ya entregados.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      itemCount: state.rewards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final reward = state.rewards[index];
        final name = (reward['display_name'] ?? 'Usuario').toString();
        final status = (reward['status'] ?? 'pending').toString();
        final date = EcuadorDateUtils.formatEcuadorTime(reward['earned_at']).toUpperCase();
        final isTransferred = reward['is_transferred'] == true;
        final description = reward['description']?.toString();

        final AppChip chip = switch (status) {
          'approved' || 'claimed' => const AppChip(label: 'Entregado', style: AppChipStyle.dark),
          'rejected' => const AppChip(label: 'Rechazado', style: AppChipStyle.outline),
          _ => const AppChip(label: 'Por entregar'),
        };

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PersonAvatar(
                    name: name,
                    avatarUrl: reward['avatar_url']?.toString(),
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.display(size: 20),
                        ),
                        Text(
                          isTransferred
                              ? 'Recibido de ${reward['from_name']}'
                              : (description == null || description.isEmpty ? 'Ganó un premio' : description),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(size: 14, weight: FontWeight.w300),
                        ),
                        Text(
                          date,
                          style: AppTypography.body(
                            size: 11,
                            weight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  chip,
                ],
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmReject(reward['id']),
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
                        onPressed: () => _approveReward(reward['id']),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: AppTypography.label(size: 12, tracking: 2),
                        ),
                        child: const Text('ENTREGAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        )
            .animate(delay: (index.clamp(0, 6) * 50).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic);
      },
    );
  }
}
