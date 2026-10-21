import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/stacked_card_list.dart';
import 'campaign_detail_screen.dart';
import 'data/campaigns_repository.dart';
import 'widgets/gift_claim_tile.dart';

/// "Mis regalos" como pantalla propia (la que se abre desde el perfil).
class MyGiftsScreen extends StatelessWidget {
  const MyGiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: MyGiftsView());
  }
}

/// "Mis regalos": los cheques del cliente, montados unos sobre otros como en un
/// portafolio. Cada uno se ve igual que lo entrega el local (`GiftCardVoucher`).
class MyGiftsView extends ConsumerWidget {
  const MyGiftsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(myClaimsProvider);

    return SafeArea(
      bottom: false,
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
                error: (e, _) => const AppEmptyState.error(message: 'No pudimos cargar tus regalos. Desliza para reintentar.',
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const AppEmptyState(
                      title: 'Sin regalos',
                      message:
                          'Aquí aparecerán tus tarjetas de regalo y los premios de las rutas.',
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.black,
                    onRefresh: () async => ref.invalidate(myClaimsProvider),
                    child: StackedCardList(
                      itemCount: list.length,
                      itemBuilder: (context, index) => GiftClaimTile(
                        claim: list[index],
                        onTap: () => _open(ref, list[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el regalo tocado.
  Future<void> _open(WidgetRef ref, CampaignClaim claim) async {
    final campaign = claim.campaign;
    if (campaign == null) return;

    await Navigator.of(ref.context).push(
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(campaign: campaign, claim: claim),
      ),
    );
    ref.invalidate(myClaimsProvider);
  }
}
