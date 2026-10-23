import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../payments/data/payments_repository.dart';
import 'admin_payment_detail_screen.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/payment_review.dart';
import 'widgets/bank_accounts_dialog.dart';
import 'widgets/prices_dialog.dart';
import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';

/// Pagos de registro de negocios: el administrador valida (y así activa la
/// cuenta del dueño y emite su comprobante) o rechaza con un motivo.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

enum _PaymentFilter {
  toValidate('Por validar'),
  paid('Pagados'),
  rejected('Rechazados'),
  all('Todos');

  final String label;

  const _PaymentFilter(this.label);

  bool accepts(PaymentOrder p) => switch (this) {
        toValidate => p.status == PaymentStatus.pending || p.status == PaymentStatus.reported,
        paid => p.status == PaymentStatus.paid,
        rejected => p.status == PaymentStatus.rejected,
        all => true,
      };
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _repository = PaymentsRepository();

  bool _isLoading = true;
  List<PaymentOrder> _payments = [];
  _PaymentFilter _filter = _PaymentFilter.toValidate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final payments = await _repository.listAll();
      if (mounted) {
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar los pagos', isError: true);
      }
    }
  }

  Future<void> _validate(PaymentOrder payment) async {
    if (await reviewValidate(context, payment, _repository)) await _load();
  }

  Future<void> _reject(PaymentOrder payment) async {
    if (await reviewReject(context, payment, _repository)) await _load();
  }

  /// Abre el detalle: comprobante, negocio y dueño. Recarga si el pago cambió.
  Future<void> _openDetail(PaymentOrder payment) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminPaymentDetailScreen(paymentId: payment.id, preview: payment),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _payments.where(_filter.accepts).toList();
    final toValidate = _payments.where(_PaymentFilter.toValidate.accepts).length;

    return AdminPageFrame(
      title: 'Pagos',
      headerTrailingWidth: 96,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Cuentas bancarias'),
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => showBankAccountsDialog(context, _repository),
          ),
          IconButton(
            tooltip: context.tr('Precios del registro'),
            icon: const Icon(Icons.sell_outlined),
            onPressed: () => showPricesDialog(context, _repository),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.black,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _PaymentFilter.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = _PaymentFilter.values[index];
                        final suffix =
                            filter == _PaymentFilter.toValidate && toValidate > 0
                                ? ' ($toValidate)'
                                : '';
                        return AdminFilterPill(
                          label: '${filter.label}$suffix',
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        );
                      },
                    ),
                  ),
                  if (!_isLoading)
                    AdminCountLabel(
                      '${visible.length} ${visible.length == 1 ? 'pago' : 'pagos'}',
                    ),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  title: 'Sin pagos',
                  message: 'No hay pagos en esta categoría.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final payment = visible[index];
                    return _PaymentCard(
                      payment: payment,
                      onOpen: () => _openDetail(payment),
                      onValidate: () => _validate(payment),
                      onReject: () => _reject(payment),
                    ).animate(delay: (40 * (index % 8)).ms).fadeIn().slideY(begin: 0.06);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentOrder payment;
  final VoidCallback onOpen;
  final VoidCallback onValidate;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.onOpen,
    required this.onValidate,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    String date(DateTime? d) =>
        d == null ? '' : EcuadorDateUtils.formatEcuadorTime(d.toUtc().toIso8601String());

    final (String label, AppChipStyle style) = switch (payment.status) {
      PaymentStatus.paid => ('Pagado', AppChipStyle.dark),
      PaymentStatus.reported => ('Reportado', AppChipStyle.pink),
      PaymentStatus.rejected => ('Rechazado', AppChipStyle.outline),
      PaymentStatus.pending => ('Sin reportar', AppChipStyle.outline),
    };
    final isOpen = payment.status == PaymentStatus.pending ||
        payment.status == PaymentStatus.reported;

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  payment.businessName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 24),
                ),
              ),
              const SizedBox(width: 8),
              AppChip(label: label, style: style),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.conceptLabel} · ${payment.amountLabel}',
            style: AppTypography.body(size: 15, weight: FontWeight.w500),
          ),
          if (payment.ownerName != null || payment.ownerEmail != null)
            AdminInfoLine(
              icon: Icons.person_outline_rounded,
              text: [payment.ownerName, payment.ownerEmail]
                  .whereType<String>()
                  .where((t) => t.isNotEmpty)
                  .join(' · '),
            ),
          AdminInfoLine(icon: Icons.tag_rounded, text: 'Ref. ${payment.reference}', strong: true),
          if (payment.method != null)
            AdminInfoLine(
              icon: payment.method!.icon,
              text: [payment.method!.label, if (payment.note?.isNotEmpty == true) payment.note!]
                  .join(' · '),
            ),
          if (date(payment.reportedAt).isNotEmpty)
            AdminInfoLine(
              icon: Icons.schedule_rounded,
              text: 'Reportado ${date(payment.reportedAt)}',
            ),
          if (payment.receiptNumber != null)
            AdminInfoLine(
              icon: Icons.receipt_long_outlined,
              text: 'Comprobante ${payment.receiptNumber}',
            ),
          if (payment.status == PaymentStatus.rejected && payment.adminNote != null)
            AdminInfoLine(icon: Icons.info_outline_rounded, text: payment.adminNote!),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: Icon(payment.hasProof ? Icons.image_outlined : Icons.visibility_outlined),
              label: Text(payment.hasProof ? 'VER COMPROBANTE Y NEGOCIO' : 'VER DETALLE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black, width: 1.2),
                shape: const StadiumBorder(),
                textStyle: AppTypography.label(size: 12, tracking: 2),
              ),
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 16),
            AppPrimaryButton(label: 'Validar pago', onPressed: onValidate),
            Align(
              alignment: Alignment.centerLeft,
              child: AppTextAction(label: 'Rechazar', onPressed: onReject),
            ),
          ],
        ],
      ),
    );
  }
}
