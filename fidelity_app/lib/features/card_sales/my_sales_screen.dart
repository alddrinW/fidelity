import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'data/card_sales_repository.dart';

/// "Mis ventas": lo que el local vendió con sus tarjetas en venta y lo que le
/// toca. Fidelity se queda su comisión; el resto se le paga al local cuando el
/// cliente canjea la tarjeta.
class MySalesScreen extends ConsumerWidget {
  const MySalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(mySalesProvider);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Mis ventas'),
              Expanded(
                child: sales.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
                  error: (_, __) => const AppEmptyState.error(
                    message: 'No pudimos cargar tus ventas. Desliza para reintentar.',
                  ),
                  data: (summary) => RefreshIndicator(
                    color: AppColors.black,
                    onRefresh: () async => ref.invalidate(mySalesProvider),
                    child: _Body(summary: summary),
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

class _Body extends StatelessWidget {
  final SalesSummary summary;

  const _Body({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.sold == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: AppEmptyState(
              title: 'Aún no vendes tarjetas',
              message: 'Cuando un cliente compre una de tus tarjetas en venta, aquí verás lo que te toca.',
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        // Lo que ya puede cobrar: tarjetas canjeadas y aún no pagadas.
        AppCard(
          radius: 28,
          color: AppColors.pink,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POR COBRAR', style: AppTypography.label(size: 12, tracking: 3)),
              Text(centsText(summary.payableCents), style: AppTypography.display(size: 56)),
              Text(
                'De las tarjetas que ya canjearon tus clientes. Fidelity te lo transfiere y te avisa.',
                style: AppTypography.body(size: 13, weight: FontWeight.w300),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Vendidas', value: '${summary.sold}', hint: centsText(summary.grossCents))),
            const SizedBox(width: 12),
            Expanded(child: _Metric(label: 'Canjeadas', value: '${summary.redeemed}', hint: 'de ${summary.sold} vendidas')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Sin canjear', value: centsText(summary.pendingCents), hint: 'a tu favor')),
            const SizedBox(width: 12),
            Expanded(child: _Metric(label: 'Ya pagado', value: centsText(summary.paidOutCents), hint: 'transferido')),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'De ${centsText(summary.grossCents)} vendidos, ${centsText(summary.commissionCents)} son la comisión de Fidelity '
          '(incluye el cobro con tarjeta) y ${centsText(summary.netCents)} son tuyos.',
          style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Text('ÚLTIMAS VENTAS', style: AppTypography.label(size: 13, tracking: 5)),
        const SizedBox(height: 12),
        for (final sale in summary.recent) _SaleTile(sale: sale),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;

  const _Metric({required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.label(size: 11, tracking: 2)),
          Text(value, style: AppTypography.display(size: 30)),
          Text(hint, style: AppTypography.body(size: 12, weight: FontWeight.w300, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final SaleRow sale;

  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final status = sale.settled
        ? const AppChip(label: 'PAGADA', style: AppChipStyle.dark)
        : sale.redeemed
            ? const AppChip(label: 'POR COBRAR')
            : const AppChip(label: 'SIN CANJEAR', style: AppChipStyle.outline);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (sale.title ?? 'Tarjeta').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(size: 18),
                  ),
                  Text(
                    [
                      sale.buyer ?? 'Un cliente',
                      if (sale.paidAt != null)
                        EcuadorDateUtils.formatEcuadorDate(sale.paidAt!.toUtc().toIso8601String()),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(centsText(sale.netCents), style: AppTypography.display(size: 20)),
                const SizedBox(height: 4),
                status,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
