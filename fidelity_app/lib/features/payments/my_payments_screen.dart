import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'data/payments_repository.dart';
import 'paga_ya_screen.dart';
import '../../core/l10n/tr_text.dart';

/// "Mis pagos": historial de pagos del dueño y sus comprobantes.
class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  static String _formatDate(DateTime? date) =>
      date == null ? '' : EcuadorDateUtils.formatEcuadorDate(date.toUtc().toIso8601String());

  Future<void> _open(BuildContext context, WidgetRef ref, PaymentOrder payment) async {
    if (payment.status == PaymentStatus.paid) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        constraints: const BoxConstraints(maxWidth: 480),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (_) => _ReceiptSheet(payment: payment),
      );
    } else {
      final reported = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PagaYaScreen(order: payment)),
      );
      if (reported == true) ref.invalidate(myPaymentsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(myPaymentsProvider);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Mis pagos'),
              Expanded(
                child: payments.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.black),
                  ),
                  error: (e, _) => AppEmptyState.error(message: 'No pudimos cargar tus pagos. Desliza para reintentar.',
                  ),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          title: 'Sin pagos',
                          message: 'Aquí verás tus pagos y sus comprobantes.',
                        )
                      : RefreshIndicator(
                          color: AppColors.black,
                          onRefresh: () async => ref.invalidate(myPaymentsProvider),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final payment = list[index];
                              return _PaymentCard(
                                payment: payment,
                                dateLabel: _formatDate(payment.paidAt ?? payment.createdAt),
                                onTap: () => _open(context, ref, payment),
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

class _PaymentCard extends StatelessWidget {
  final PaymentOrder payment;
  final String dateLabel;
  final VoidCallback onTap;

  const _PaymentCard({required this.payment, required this.dateLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (String label, AppChipStyle style) = switch (payment.status) {
      PaymentStatus.paid => ('Pagado', AppChipStyle.dark),
      PaymentStatus.reported => ('En revisión', AppChipStyle.pink),
      PaymentStatus.rejected => ('Rechazado', AppChipStyle.outline),
      PaymentStatus.pending => ('Pendiente', AppChipStyle.outline),
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.conceptLabel.toUpperCase(),
                  style: AppTypography.label(size: 12, tracking: 3),
                ),
              ),
              AppChip(label: label, style: style),
            ],
          ),
          const SizedBox(height: 4),
          Text(payment.amountLabel, style: AppTypography.display(size: 32)),
          Text(
            payment.businessName,
            style: AppTypography.body(size: 15, weight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Ref. ${payment.reference}',
              if (dateLabel.isNotEmpty) dateLabel,
            ].join(' · '),
            style: AppTypography.body(
              size: 13,
              weight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
          if (payment.status == PaymentStatus.paid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Ver comprobante',
                    style: AppTypography.body(size: 14, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          if (payment.status == PaymentStatus.rejected && payment.adminNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                payment.adminNote!,
                style: AppTypography.body(size: 14, weight: FontWeight.w300),
              ),
            ),
        ],
      ),
    );
  }
}

/// Comprobante digital de un pago validado.
class _ReceiptSheet extends StatelessWidget {
  final PaymentOrder payment;

  const _ReceiptSheet({required this.payment});

  @override
  Widget build(BuildContext context) {
    String date(DateTime? d) =>
        d == null ? '—' : EcuadorDateUtils.formatEcuadorTime(d.toUtc().toIso8601String());

    final rows = <(String, String)>[
      ('Negocio', payment.businessName),
      ('Concepto', payment.conceptLabel),
      ('Referencia', payment.reference),
      ('Método', payment.method?.label ?? '—'),
      ('Fecha de pago', date(payment.paidAt)),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'COMPROBANTE DE PAGO',
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              payment.receiptNumber ?? '',
              textAlign: TextAlign.center,
              style: AppTypography.label(size: 13, tracking: 3, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              payment.amountLabel,
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 44),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.black),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        label,
                        style: AppTypography.body(
                          size: 14,
                          weight: FontWeight.w300,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: AppTypography.body(size: 14, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Copiar número',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: payment.receiptNumber ?? ''));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Número de comprobante copiado')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
