import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'campaign_detail_screen.dart';
import 'data/campaigns_repository.dart';
import '../../core/l10n/tr_text.dart';

/// "Mis regalos": tarjetas de regalo y premios de ruta del cliente, con su
/// código para canjear en el local.
class MyGiftsScreen extends ConsumerWidget {
  const MyGiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(myClaimsProvider);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Mis regalos'),
              Expanded(
                child: claims.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.black),
                  ),
                  error: (e, _) => const AppEmptyState(
                    title: 'Algo salió mal',
                    message: 'No pudimos cargar tus regalos. Desliza para reintentar.',
                  ),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          title: 'Sin regalos',
                          message: 'Aquí aparecerán tus tarjetas de regalo y los premios de las rutas.',
                        )
                      : RefreshIndicator(
                          color: AppColors.black,
                          onRefresh: () async => ref.invalidate(myClaimsProvider),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final claim = list[index];
                              final campaign = claim.campaign;
                              if (campaign == null) return const SizedBox.shrink();
                              return AppCard(
                                radius: 28,
                                padding: const EdgeInsets.all(20),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CampaignDetailScreen(
                                        campaign: campaign,
                                        claim: claim,
                                      ),
                                    ),
                                  );
                                  ref.invalidate(myClaimsProvider);
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: claim.isRedeemed
                                            ? AppColors.surfaceMuted
                                            : AppColors.pink,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        claim.isRoutePrize
                                            ? Icons.route_rounded
                                            : Icons.card_giftcard_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            campaign.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.body(
                                              size: 16,
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            campaign.benefitLabel ?? claim.code,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.body(
                                              size: 14,
                                              weight: FontWeight.w300,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AppChip(
                                      label: claim.isRedeemed ? 'Canjeada' : 'Vigente',
                                      style: claim.isRedeemed
                                          ? AppChipStyle.outline
                                          : AppChipStyle.dark,
                                    ),
                                  ],
                                ),
                              ).animate(delay: (40 * (index % 8)).ms).fadeIn().slideY(begin: 0.06);
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
