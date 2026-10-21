import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import 'campaign_form_screen.dart';
import 'campaign_manage_screen.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_visuals.dart';
import 'widgets/redeem_code_card.dart';
import '../../core/l10n/tr_text.dart';

/// Pestaña "Campañas" del dueño: eventos y rutas (las gift cards tienen su propia
/// pestaña), con el canje de premios de ruta y el botón para crear una nueva.
class CampaignsTab extends ConsumerWidget {
  const CampaignsTab({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CampaignFormScreen()),
    );
    ref.invalidate(myCampaignsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(myCampaignsProvider);

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: () async => ref.invalidate(myCampaignsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          RedeemCodeCard(onRedeemed: () => ref.invalidate(myCampaignsProvider)),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Nueva campaña',
            onPressed: () => _create(context, ref),
          ),
          const SizedBox(height: 24),
          campaigns.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.black)),
            ),
            error: (e, _) => const SizedBox(
              height: 260,
              child: AppEmptyState.error(message: 'No pudimos cargar tus campañas. Desliza para reintentar.',
                imageHeight: 110,
              ),
            ),
            data: (all) {
              // Las gift cards tienen su propia pestaña.
              final list = all.where((c) => c.type != CampaignType.giftCard).toList();
              return list.isEmpty
                ? const SizedBox(
                    height: 300,
                    child: AppEmptyState(
                      title: 'Sin campañas',
                      message: 'Crea eventos o rutas para tus clientes.',
                      imageHeight: 120,
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        _CampaignCard(
                          campaign: list[i],
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CampaignManageScreen(campaign: list[i]),
                              ),
                            );
                            ref.invalidate(myCampaignsProvider);
                          },
                        ).animate(delay: (40 * (i % 8)).ms).fadeIn().slideY(begin: 0.06),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;

  const _CampaignCard({required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stats = campaign.stats;
    final (AppChipStyle phaseStyle) = switch (campaign.phase) {
      CampaignPhase.active => AppChipStyle.dark,
      CampaignPhase.scheduled => AppChipStyle.pink,
      _ => AppChipStyle.outline,
    };

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                child: Icon(campaign.type.icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(size: 22),
                    ),
                    Text(
                      '${campaign.type.label} · ${campaignValidity(campaign)}',
                      style: AppTypography.body(
                        size: 13,
                        weight: FontWeight.w300,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppChip(label: campaign.phase.label, style: phaseStyle),
            ],
          ),
          if (stats != null && campaign.type != CampaignType.event) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  label: campaign.type == CampaignType.route || campaign.type == CampaignType.scanChallenge
                      ? 'Premios'
                      : 'Tarjetas',
                  value: stats.claims,
                ),
                _Stat(label: 'Canjes', value: stats.redeemed),
                if (campaign.type == CampaignType.route)
                  _Stat(label: 'Participan', value: stats.participants),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTypography.display(size: 26)),
          Text(
            label.toUpperCase(),
            style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
