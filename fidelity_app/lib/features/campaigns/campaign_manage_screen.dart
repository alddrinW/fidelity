import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import '../../core/l10n/tr_text.dart';

/// Detalle de una campaña para su dueño: cifras, tarjetas o premios emitidos
/// (con su estado de canje) y la opción de cancelarla.
class CampaignManageScreen extends ConsumerStatefulWidget {
  final Campaign campaign;

  const CampaignManageScreen({super.key, required this.campaign});

  @override
  ConsumerState<CampaignManageScreen> createState() => _CampaignManageScreenState();
}

class _CampaignManageScreenState extends ConsumerState<CampaignManageScreen> {
  late final Campaign _campaign = widget.campaign;
  bool _isLoading = true;
  List<IssuedClaim> _claims = [];

  bool get _hasClaims => _campaign.type != CampaignType.event;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    if (!_hasClaims) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final claims = await ref.read(campaignsRepositoryProvider).claims(_campaign.id);
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'No se pudieron cargar las tarjetas', isError: true);
      }
    }
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.cancel_outlined,
        title: '¿Cancelar campaña?',
        message: 'Los clientes dejarán de verla y no se podrán canjear sus tarjetas.',
        primaryLabel: 'Cancelar campaña',
        onPrimary: () async {
          try {
            await ref.read(campaignsRepositoryProvider).cancel(_campaign.id);
            if (!mounted) return;
            DashboardAnimatedToast.show(context, 'Campaña cancelada');
            Navigator.of(context).pop();
          } catch (e) {
            if (mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
          }
        },
        secondaryLabel: 'Volver',
      ),
    );
  }

  String _day(DateTime? d) =>
      d == null ? '—' : EcuadorDateUtils.formatEcuadorTime(d.toUtc().toIso8601String());

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    final canCancel = c.phase == CampaignPhase.active || c.phase == CampaignPhase.scheduled;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(title: c.type.label),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Text(c.title.toUpperCase(), style: AppTypography.display(size: 34)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: c.phase.label,
                          style: c.phase == CampaignPhase.active
                              ? AppChipStyle.dark
                              : AppChipStyle.outline,
                        ),
                        for (final b in c.businesses)
                          AppChip(label: b.name, icon: Icons.storefront_outlined),
                      ],
                    ),
                    if (c.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(
                        c.description!,
                        style: AppTypography.body(size: 15, weight: FontWeight.w300),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppCard(
                      radius: 28,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          AdminInfoLine(icon: Icons.play_arrow_rounded, text: 'Empieza ${_day(c.startsAt)}'),
                          AdminInfoLine(
                            icon: Icons.stop_rounded,
                            text: c.endsAt == null ? 'Sin fecha de fin' : 'Termina ${_day(c.endsAt)}',
                          ),
                          if (c.benefitLabel != null)
                            AdminInfoLine(
                              icon: Icons.card_giftcard_rounded,
                              text: c.benefitLabel!,
                              strong: true,
                            ),
                          if (c.type == CampaignType.route)
                            AdminInfoLine(
                              icon: Icons.approval_rounded,
                              text: '${c.stampsNeeded} sellos para completar',
                            ),
                          if (c.type == CampaignType.scanChallenge)
                            AdminInfoLine(
                              icon: Icons.qr_code_scanner_rounded,
                              text: '${c.scansNeeded} escaneos para ganar',
                              strong: true,
                            ),
                        ],
                      ),
                    ),
                    if (_hasClaims) ...[
                      const SizedBox(height: 24),
                      AdminSectionLabel(
                        c.type == CampaignType.route || c.type == CampaignType.scanChallenge
                            ? 'Premios emitidos'
                            : 'Tarjetas emitidas',
                      ),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: AppColors.black))
                      else if (_claims.isEmpty)
                        Text(
                          c.type == CampaignType.route || c.type == CampaignType.scanChallenge
                              ? 'Todavía no hay premios emitidos.'
                              : 'Todavía no hay tarjetas emitidas.',
                          style: AppTypography.body(size: 15, weight: FontWeight.w300),
                        )
                      else
                        for (final claim in _claims) ...[
                          _ClaimRow(claim: claim),
                          const SizedBox(height: 10),
                        ],
                    ],
                    if (canCancel) ...[
                      const SizedBox(height: 24),
                      AppTextAction(label: 'Cancelar campaña', onPressed: _confirmCancel),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  final IssuedClaim claim;

  const _ClaimRow({required this.claim});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claim.code, style: AppTypography.display(size: 20)),
                Text(
                  claim.userName ?? claim.userEmail ?? 'Cliente',
                  style: AppTypography.body(size: 13, weight: FontWeight.w300),
                ),
              ],
            ),
          ),
          AppChip(
            label: claim.isRedeemed ? 'Canjeada' : 'Vigente',
            style: claim.isRedeemed ? AppChipStyle.outline : AppChipStyle.dark,
          ),
        ],
      ),
    );
  }
}
