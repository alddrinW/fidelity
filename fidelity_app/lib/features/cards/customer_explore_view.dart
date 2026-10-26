import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../business/data/business_repository.dart';
import '../card_sales/card_offer_screen.dart';
import '../card_sales/data/card_sales_repository.dart';
import '../campaigns/campaign_detail_screen.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/widgets/campaign_visuals.dart';
import '../scanner/scanner_screen.dart';
import '../../core/l10n/tr_text.dart';

/// "Explorar": los negocios donde el cliente puede escanear su código QR y las
/// campañas vigentes de sus locales.
class CustomerExploreView extends ConsumerStatefulWidget {
  const CustomerExploreView({super.key});

  @override
  ConsumerState<CustomerExploreView> createState() => _CustomerExploreViewState();
}

class _CustomerExploreViewState extends ConsumerState<CustomerExploreView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filtra por nombre, categoría o premio: lo que el cliente busca.
  bool _matches(Map<String, dynamic> business) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    final category = (business['categoryRef'] as Map?)?['name']?.toString() ?? '';
    final haystack = [
      business['name']?.toString() ?? '',
      category,
      business['description']?.toString() ?? '',
      business['rewardDescription']?.toString() ?? '',
      business['address']?.toString() ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final businesses = ref.watch(businessesDirectoryProvider);
    final campaigns = ref.watch(campaignFeedProvider).valueOrNull ?? const <Campaign>[];
    final offers = ref.watch(cardOffersProvider).valueOrNull ?? const <Campaign>[];

    final visible = (businesses.valueOrNull ?? const <Map<String, dynamic>>[])
        .where(_matches)
        .toList();

    return SafeArea(
      bottom: false,
      child: AppResponsiveBody(
        adaptive: true,
        child: Column(
          children: [
            const AppPageHeader(title: 'Explorar'),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: AppTypography.body(size: 17, weight: FontWeight.w300),
                cursorColor: AppColors.black,
                decoration: InputDecoration(
                  hintText: 'Busca un local o una categoría',
                  prefixIcon: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 20, end: 12),
                    child: Icon(Icons.search_rounded, size: 24),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: businesses.isLoading && businesses.valueOrNull == null
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty && campaigns.isEmpty && offers.isEmpty
                      ? AppEmptyState(
                          title: _query.isEmpty ? 'Sin negocios' : 'Sin resultados',
                          message: _query.isEmpty
                              ? 'Todavía no hay negocios activos en Fidelity.'
                              : 'Prueba con otro nombre o categoría.',
                        )
                      : RefreshIndicator(
                          color: AppColors.black,
                          onRefresh: () async {
                            ref.invalidate(businessesDirectoryProvider);
                            ref.invalidate(campaignFeedProvider);
                            ref.invalidate(cardOffersProvider);
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            // Abajo hay espacio para el botón flotante.
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                            children: [
                              // Gift cards que los locales venden: se pagan con tarjeta.
                              if (offers.isNotEmpty) ...[
                                _SectionTitle(text: 'TARJETAS EN VENTA'),
                                for (final offer in offers)
                                  _OfferTile(
                                    offer: offer,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => CardOfferScreen(offer: offer)),
                                      );
                                      ref.invalidate(cardOffersProvider);
                                    },
                                  ).animate().fadeIn().slideY(begin: 0.05),
                                const SizedBox(height: 8),
                              ],
                              if (visible.isNotEmpty) ...[
                                _SectionTitle(text: 'NEGOCIOS'),
                                for (final business in visible)
                                  _BusinessTile(
                                    business: business,
                                    onTap: () => _openBusiness(business),
                                  ).animate().fadeIn().slideY(begin: 0.05),
                              ],
                              if (campaigns.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _SectionTitle(text: 'NOVEDADES'),
                                for (final campaign in campaigns)
                                  _CampaignTile(
                                    campaign: campaign,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CampaignDetailScreen(campaign: campaign),
                                        ),
                                      );
                                      ref.invalidate(campaignFeedProvider);
                                    },
                                  ).animate().fadeIn().slideY(begin: 0.05),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ficha del local: sus datos y el botón para escanear su código QR.
  void _openBusiness(Map<String, dynamic> business) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetCtx) {
        final name = business['name']?.toString() ?? 'Negocio';
        final category = (business['categoryRef'] as Map?)?['name']?.toString();
        final reward = business['rewardDescription']?.toString();
        final address = business['address']?.toString();
        final points = (business['pointsRequired'] as num?)?.toInt();
        final image = imageProviderFromUrl(business['logoUrl']?.toString());

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.black, width: 1.2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: image == null
                          ? const Icon(Icons.storefront_outlined, color: AppColors.black)
                          : Padding(
                              // El logo entra completo, sin recortarse.
                              padding: const EdgeInsets.all(8),
                              child: Image(image: image, fit: BoxFit.contain),
                            ),
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
                            style: AppTypography.display(size: 26),
                          ),
                          if (category != null && category.isNotEmpty)
                            Text(
                              category,
                              style: AppTypography.body(
                                size: 14,
                                weight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (reward != null && reward.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'PREMIO',
                    style: AppTypography.label(size: 13, tracking: 3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reward,
                    style: AppTypography.body(size: 16, weight: FontWeight.w400),
                  ),
                ],
                if (points != null && points > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Con $points puntos te llevas el premio.',
                    style: AppTypography.body(
                      size: 15,
                      weight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: AppTypography.body(
                            size: 15,
                            weight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Escanear aquí',
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Título de sección ("NEGOCIOS", "NOVEDADES").
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTypography.label(size: 16, tracking: 0.5)),
      ),
    );
  }
}

/// Un local en la lista de "Explorar".
class _BusinessTile extends StatelessWidget {
  final Map<String, dynamic> business;
  final VoidCallback onTap;

  const _BusinessTile({required this.business, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(business['logoUrl']?.toString());
    final category = (business['categoryRef'] as Map?)?['name']?.toString();
    final reward = business['rewardDescription']?.toString();
    final points = (business['pointsRequired'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: image == null
                  ? const Icon(Icons.storefront_outlined, color: AppColors.black)
                  : Padding(
                      // El logo entra completo, sin recortarse.
                      padding: const EdgeInsets.all(7),
                      child: Image(image: image, fit: BoxFit.contain),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (business['name']?.toString() ?? 'Negocio').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(size: 22),
                  ),
                  if (category != null && category.isNotEmpty)
                    Text(
                      category,
                      style: AppTypography.body(
                        size: 13,
                        weight: FontWeight.w300,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (reward != null && reward.isNotEmpty)
                    Text(
                      reward,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            if (points != null && points > 0)
              Text(
                '$points pts',
                style: AppTypography.label(size: 13, tracking: 1),
              ),
          ],
        ),
      ),
    );
  }
}

/// Una campaña en la lista de novedades.
class _CampaignTile extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;

  const _CampaignTile({required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = campaignColors(campaign.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        color: colors.background,
        onTap: onTap,
        child: Row(
          children: [
            Icon(campaign.type.icon, size: 24, color: colors.foreground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(size: 20, color: colors.foreground),
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
            Icon(Icons.chevron_right_rounded, size: 28, color: colors.foreground),
          ],
        ),
      ),
    );
  }
}

/// Una tarjeta en venta en la lista de Explorar: qué incluye, de qué local y a cuánto.
class _OfferTile extends StatelessWidget {
  final Campaign offer;
  final VoidCallback onTap;

  const _OfferTile({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final business = offer.businesses.firstOrNull;
    final bought = offer.claim != null;
    final left = offer.stockLeft ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        color: AppColors.pink,
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.local_offer_rounded, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (offer.benefitLabel ?? offer.title).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(size: 20),
                  ),
                  Text(
                    [
                      business?.name ?? 'Un local',
                      if (bought) 'Ya la tienes' else if (left <= 5) 'Quedan $left',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 14, weight: FontWeight.w300),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(99)),
              child: Text(offer.priceText, style: AppTypography.display(size: 20, color: AppColors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
