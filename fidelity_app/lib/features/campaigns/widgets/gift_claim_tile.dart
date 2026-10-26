import 'package:flutter/material.dart';

import '../data/campaigns_repository.dart';
import 'gift_card_voucher.dart';

/// Un regalo del cliente: el cheque del local con su código. Lo usan "Mis
/// regalos" y la pestaña de gift cards de cada local.
class GiftClaimTile extends StatelessWidget {
  final CampaignClaim claim;
  final VoidCallback onTap;

  const GiftClaimTile({super.key, required this.claim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final campaign = claim.campaign;
    if (campaign == null) return const SizedBox.shrink();
    final business = campaign.businesses.firstOrNull;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GiftCardVoucher(
        campaign: campaign,
        code: claim.code,
        redeemed: claim.isRedeemed,
        validUntil: claim.isPurchase ? claim.expiresAt : null,
        logoUrl: business?.logoUrl,
        businessName: business?.name,
      ),
    );
  }
}

/// Las gift cards (y premios) que [businessId] le entregó al cliente.
List<CampaignClaim> claimsOfBusiness(List<CampaignClaim> claims, String businessId) => [
      for (final claim in claims)
        if (claim.campaign?.businesses.any((b) => b.id == businessId) ?? false) claim,
    ];
