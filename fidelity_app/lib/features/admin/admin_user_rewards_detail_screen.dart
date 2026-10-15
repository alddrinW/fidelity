import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import 'widgets/admin_widgets.dart';
import '../../core/l10n/tr_text.dart';

class AdminUserRewardsDetailScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final List<Map<String, dynamic>> rewards;

  const AdminUserRewardsDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rewards,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Premios',
      body: rewards.isEmpty
          ? const AppEmptyState(
              title: 'Sin premios',
              message: 'Este usuario no tiene premios registrados.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: rewards.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) return _UserHeader(name: userName, email: userEmail);
                return _RewardCard(reward: rewards[index - 1])
                    .animate(delay: Duration(milliseconds: 40 * (index % 8)))
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.06);
              },
            ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String name;
  final String email;

  const _UserHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.toUpperCase(), style: AppTypography.display(size: 30)),
        if (email.isNotEmpty)
          Text(
            email,
            style: AppTypography.body(
              size: 14,
              weight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final description = (reward['reward_description'] ?? 'Premio').toString();
    final businessName = reward['business_name'] ?? 'Negocio desconocido';
    final earnedAt = reward['earned_at']?.toString();
    final pointsUsed = reward['points_used'] ?? 0;
    final isTransferred = reward['transferred'] == true;
    final transferredTo = reward['transferred_to_name'];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 24),
                ),
              ),
              const SizedBox(width: 8),
              AppChip(label: '$pointsUsed pts', style: AppChipStyle.dark),
            ],
          ),
          const SizedBox(height: 8),
          AdminInfoLine(icon: Icons.storefront_rounded, text: '$businessName'),
          if (earnedAt != null && earnedAt.isNotEmpty)
            AdminInfoLine(
              icon: Icons.schedule_rounded,
              text: EcuadorDateUtils.formatEcuadorTime(earnedAt),
            ),
          if (isTransferred) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.pink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transferido a ${transferredTo ?? 'otro usuario'}',
                      style: AppTypography.body(size: 14, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
