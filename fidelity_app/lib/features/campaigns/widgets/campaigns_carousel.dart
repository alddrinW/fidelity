import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../campaign_detail_screen.dart';
import '../data/campaigns_repository.dart';
import 'campaign_visuals.dart';
import '../../../core/l10n/tr_text.dart';

/// "Novedades": carrusel con las campañas vigentes de los locales del
/// cliente (eventos, tarjetas de regalo y rutas). Si no hay ninguna, o si no
/// se pueden cargar, no ocupa espacio.
class CampaignsCarousel extends ConsumerWidget {
  const CampaignsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(campaignFeedProvider);
    final campaigns = feed.valueOrNull ?? const <Campaign>[];
    if (campaigns.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Semantics(
              header: true,
              child: Text('NOVEDADES', style: AppTypography.label(size: 16, tracking: 0.5)),
            ),
          ),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: campaigns.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _CampaignTile(
                campaign: campaigns[index],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CampaignDetailScreen(campaign: campaigns[index]),
                    ),
                  );
                  ref.invalidate(campaignFeedProvider);
                },
              ).animate(delay: (60 * index).ms).fadeIn().slideX(begin: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignTile extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;

  const _CampaignTile({required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = campaignColors(campaign.type);
    final isRoute = campaign.type == CampaignType.route;

    return SizedBox(
      width: 270,
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: const BorderSide(color: AppColors.black, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(campaign.type.icon, size: 20, color: colors.foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        campaign.type.label.toUpperCase(),
                        style: AppTypography.label(size: 11, tracking: 3, color: colors.foreground),
                      ),
                    ),
                    if (campaign.claim != null)
                      Icon(Icons.check_circle_outline, size: 18, color: colors.foreground),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  campaign.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 24, color: colors.foreground),
                ),
                const Spacer(),
                if (isRoute)
                  Text(
                    '${campaign.stampedBusinessIds.length} de ${campaign.stampsNeeded} sellos',
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                Text(
                  campaignHeadline(campaign),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w300,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
