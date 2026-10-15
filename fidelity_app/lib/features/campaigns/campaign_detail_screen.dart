import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_visuals.dart';
import '../../core/l10n/tr_text.dart';

/// Detalle de una campaña para el cliente: el evento, la tarjeta de regalo (que
/// puede reclamar y mostrar en el local) o el pasaporte de una ruta con sus
/// sellos.
class CampaignDetailScreen extends ConsumerStatefulWidget {
  final Campaign campaign;

  /// Tarjeta ya conocida (cuando se abre desde "Mis tarjetas").
  final CampaignClaim? claim;

  const CampaignDetailScreen({super.key, required this.campaign, this.claim});

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  late CampaignClaim? _claim = widget.claim ?? widget.campaign.claim;
  bool _isClaiming = false;

  Campaign get _campaign => widget.campaign;

  Future<void> _claimGift() async {
    setState(() => _isClaiming = true);
    try {
      final claim = await ref.read(campaignsRepositoryProvider).claim(_campaign.id);
      ref.invalidate(myClaimsProvider);
      if (mounted) setState(() => _claim = claim);
    } catch (e) {
      if (mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(_campaign.imageUrl);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(title: _campaign.type.label),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    if (image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image(image: image, height: 180, fit: BoxFit.cover),
                      ),
                    if (image != null) const SizedBox(height: 16),
                    Text(
                      _campaign.title.toUpperCase(),
                      style: AppTypography.display(size: 36),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: campaignValidity(_campaign),
                          style: AppChipStyle.outline,
                          icon: Icons.schedule_rounded,
                        ),
                        for (final b in _campaign.businesses)
                          AppChip(label: b.name, icon: Icons.storefront_outlined),
                      ],
                    ),
                    if (_campaign.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(
                        _campaign.description!,
                        style: AppTypography.body(size: 16, weight: FontWeight.w300),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ..._typeSection(),
                  ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _typeSection() {
    switch (_campaign.type) {
      case CampaignType.event:
        return const [];
      case CampaignType.giftCard:
        return [
          _BenefitCard(label: _campaign.benefitLabel ?? 'Tarjeta de regalo'),
          const SizedBox(height: 16),
          if (_claim == null)
            AppPrimaryButton(
              label: 'Obtener tarjeta',
              isLoading: _isClaiming,
              onPressed: _campaign.isActive ? _claimGift : null,
            )
          else
            _ClaimCodeCard(claim: _claim!, placeName: _campaign.businesses.firstOrNull?.name),
        ];
      case CampaignType.route:
        final stamped = _campaign.stampedBusinessIds.toSet();
        final needed = _campaign.stampsNeeded;
        return [
          Text(
            'TU PASAPORTE · ${stamped.length} DE $needed SELLOS',
            style: AppTypography.label(size: 13, tracking: 4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final b in _campaign.businesses)
                _StampSpot(name: b.name, stamped: stamped.contains(b.id)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Escanea en cada local para ganar su sello. Al completarlo ganas: '
            '${_campaign.benefitLabel ?? 'un premio'}.',
            style: AppTypography.body(size: 15, weight: FontWeight.w300),
          ),
          if (_claim != null) ...[
            const SizedBox(height: 16),
            _ClaimCodeCard(claim: _claim!, placeName: _campaign.businesses.firstOrNull?.name),
          ],
        ];
    }
  }
}

class _BenefitCard extends StatelessWidget {
  final String label;

  const _BenefitCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(32)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard_rounded, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.display(size: 28, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sello del pasaporte: relleno rosa con check si ya se ganó, contorno si falta.
class _StampSpot extends StatelessWidget {
  final String name;
  final bool stamped;

  const _StampSpot({required this.name, required this.stamped});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name: ${stamped ? 'sello ganado' : 'sello pendiente'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: stamped ? AppColors.pink : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: stamped ? 1.6 : 1.2),
              ),
              child: Icon(
                stamped ? Icons.check_rounded : Icons.storefront_outlined,
                size: 34,
                color: stamped ? AppColors.black : AppColors.placeholderIcon,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 12, weight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// Código de canje (con QR) que el cliente muestra en el local.
class _ClaimCodeCard extends StatelessWidget {
  final CampaignClaim claim;
  final String? placeName;

  const _ClaimCodeCard({required this.claim, this.placeName});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppChip(
            label: claim.isRedeemed ? 'Canjeada' : 'Vigente',
            style: claim.isRedeemed ? AppChipStyle.outline : AppChipStyle.dark,
            icon: claim.isRedeemed ? Icons.check_rounded : Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: claim.isRedeemed ? 0.35 : 1,
            child: QrImageView(
              data: claim.code,
              size: 168,
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(claim.code, style: AppTypography.display(size: 32)),
          const SizedBox(height: 4),
          Text(
            claim.isRedeemed
                ? 'Ya usaste esta tarjeta.'
                : 'Muestra este código${placeName == null ? '' : ' en $placeName'} para canjearlo.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          if (!claim.isRedeemed) ...[
            const SizedBox(height: 8),
            AppTextAction(
              label: 'Copiar código',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: claim.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
