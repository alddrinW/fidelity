import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../birthdays/birthday_gift_screen.dart';
import 'data/campaigns_repository.dart';
import 'gift_card_form_screen.dart';
import 'gift_card_manage_screen.dart';
import 'widgets/campaign_visuals.dart';
import 'widgets/redeem_code_card.dart';

/// Pestaña "Gift Cards" del dueño: canjear una gift card (con su código de
/// letras), crear nuevas para sus clientes y ver, editar o cancelar las que ya
/// envió.
class GiftCardsTab extends ConsumerWidget {
  const GiftCardsTab({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GiftCardFormScreen()),
    );
    ref.invalidate(myCampaignsProvider);
  }

  Future<void> _birthday(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BirthdayGiftScreen()),
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
            label: 'Nueva gift card',
            onPressed: () => _create(context, ref),
          ),
          const SizedBox(height: 12),
          _BirthdayTemplateCard(onTap: () => _birthday(context, ref)),
          const SizedBox(height: 24),
          campaigns.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.black)),
            ),
            error: (e, _) => const SizedBox(
              height: 260,
              child: AppEmptyState.error(message: 'No pudimos cargar tus gift cards. Desliza para reintentar.',
                imageHeight: 110,
              ),
            ),
            data: (all) {
              final list = all.where((c) => c.type == CampaignType.giftCard).toList();
              if (list.isEmpty) {
                return const SizedBox(
                  height: 300,
                  child: AppEmptyState(
                    title: 'Sin gift cards',
                    message:
                        'Regala descuentos o mini premios: a cada cliente le llega la suya, con su cheque y su código.',
                    imageHeight: 120,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    GiftCardTile(
                      campaign: list[i],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GiftCardManageScreen(campaign: list[i]),
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

/// Una gift card de la lista del dueño: beneficio, a quién le llega y cuántas
/// se enviaron y canjearon.
class GiftCardTile extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;

  const GiftCardTile({super.key, required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stats = campaign.stats;
    final phaseStyle = switch (campaign.phase) {
      CampaignPhase.active => AppChipStyle.dark,
      CampaignPhase.scheduled => AppChipStyle.pink,
      _ => AppChipStyle.outline,
    };
    final audience = campaign.audience == CampaignAudience.selected
        ? '${stats?.recipients ?? 0} ${(stats?.recipients ?? 0) == 1 ? 'cliente elegido' : 'clientes elegidos'}'
        : 'Todos mis clientes';

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
                child: const Icon(Icons.card_giftcard_rounded, size: 22),
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
                      '${campaign.benefitLabel ?? 'Gift card'} · $audience',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 13,
                        weight: FontWeight.w300,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      campaignValidity(campaign),
                      style: AppTypography.body(
                        size: 12,
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
          if (stats != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TileStat(label: 'Enviadas', value: stats.claims),
                _TileStat(label: 'Canjeadas', value: stats.redeemed),
                _TileStat(label: 'Sin canjear', value: stats.claims - stats.redeemed),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TileStat extends StatelessWidget {
  final String label;
  final int value;

  const _TileStat({required this.label, required this.value});

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

/// La plantilla de cumpleaños: diseño y texto ya puestos; el dueño solo elige
/// el premio, a quién y la hora.
class _BirthdayTemplateCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BirthdayTemplateCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      color: AppColors.pink,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.cake_rounded, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CUMPLEAÑOS', style: AppTypography.display(size: 22)),
                const SizedBox(height: 2),
                Text(
                  'Plantilla lista: tú eliges el premio, a quién y la hora. Vale solo el día del cumpleaños.',
                  style: AppTypography.body(size: 13, weight: FontWeight.w300),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
