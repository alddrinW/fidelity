import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../card_sales/data/card_sales_repository.dart';
import 'widgets/admin_widgets.dart';

/// Tarjetas en venta: lo que el administrador le debe pagar a cada local (por
/// las tarjetas que sus clientes ya canjearon) y las compras cobradas dos veces
/// que hay que devolver. El pago al local se hace por fuera (transferencia) y
/// aquí se registra con su referencia.
class AdminCardPayoutsScreen extends ConsumerWidget {
  const AdminCardPayoutsScreen({super.key});

  Future<void> _settle(BuildContext context, WidgetRef ref, PayoutRow row) async {
    final note = await _askNote(
      context,
      title: 'Registrar pago a ${row.businessName ?? 'el local'}',
      message: 'Vas a registrar que ya le transferiste ${centsText(row.netCents)} '
          'por ${row.cards} ${row.cards == 1 ? 'tarjeta canjeada' : 'tarjetas canjeadas'}.',
      hint: 'Referencia de la transferencia (opcional)',
      action: 'Registrar pago',
    );
    if (note == null) return;
    try {
      await ref.read(cardSalesRepositoryProvider).settle(row.businessId, note: note);
      ref.invalidate(cardPayoutsProvider);
      if (context.mounted) DashboardAnimatedToast.show(context, 'Pago registrado');
    } catch (e) {
      if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  Future<void> _refunded(BuildContext context, WidgetRef ref, RefundRow row) async {
    final note = await _askNote(
      context,
      title: 'Devolución ${row.reference}',
      message: 'Marca esta compra como devuelta cuando ya le reversaste ${centsText(row.amountCents)} '
          'a ${row.buyer ?? 'el cliente'} en PayPhone.',
      hint: 'Comentario (opcional)',
      action: 'Ya la devolví',
    );
    if (note == null) return;
    try {
      await ref.read(cardSalesRepositoryProvider).markRefunded(row.id, note: note);
      ref.invalidate(cardPayoutsProvider);
      if (context.mounted) DashboardAnimatedToast.show(context, 'Devolución registrada');
    } catch (e) {
      if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cardPayoutsProvider);
    final data = async.valueOrNull;

    return AdminPageFrame(
      title: 'Pagos a locales',
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async => ref.invalidate(cardPayoutsProvider),
        child: data == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 360,
                    child: async.hasError
                        ? const AppEmptyState.error(message: 'No pudimos cargar los pagos. Desliza para reintentar.')
                        : const AdminLoading(),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  Text(
                    'Cuando un cliente canjea una tarjeta comprada, el local se gana lo que pagó menos '
                    'la comisión de Fidelity. Transfiérele y registra aquí el pago.',
                    style: AppTypography.body(size: 14, weight: FontWeight.w300),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    radius: 28,
                    color: AppColors.pink,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('POR PAGAR A LOS LOCALES', style: AppTypography.label(size: 12, tracking: 3)),
                        Text(centsText(data.totalCents), style: AppTypography.display(size: 48)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (data.payouts.isEmpty)
                    const SizedBox(
                      height: 220,
                      child: AppEmptyState(
                        title: 'Nada por pagar',
                        message: 'Cuando un cliente canjee una tarjeta comprada, el local aparecerá aquí.',
                        imageHeight: 100,
                      ),
                    )
                  else
                    for (final row in data.payouts) ...[
                      _PayoutTile(row: row, onSettle: () => _settle(context, ref, row)),
                      const SizedBox(height: 10),
                    ],
                  if (data.refunds.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const AdminSectionLabel('Por devolver'),
                    for (final row in data.refunds) ...[
                      _RefundTile(row: row, onDone: () => _refunded(context, ref, row)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final PayoutRow row;
  final VoidCallback onSettle;

  const _PayoutTile({required this.row, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (row.businessName ?? 'Local').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 20),
                ),
              ),
              Text(centsText(row.netCents), style: AppTypography.display(size: 26)),
            ],
          ),
          Text(
            '${row.cards} ${row.cards == 1 ? 'tarjeta canjeada' : 'tarjetas canjeadas'}'
            '${row.ownerEmail == null ? '' : ' · ${row.ownerEmail}'}',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onSettle,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('REGISTRAR PAGO'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                backgroundColor: AppColors.pink,
                side: const BorderSide(color: AppColors.black, width: 1.2),
                shape: const StadiumBorder(),
                textStyle: AppTypography.label(size: 12, tracking: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundTile extends StatelessWidget {
  final RefundRow row;
  final VoidCallback onDone;

  const _RefundTile({required this.row, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.reference, style: AppTypography.label(size: 14, tracking: 2)),
              ),
              Text(centsText(row.amountCents), style: AppTypography.display(size: 22)),
            ],
          ),
          Text(
            '${row.buyer ?? 'Cliente'}${row.buyerEmail == null ? '' : ' · ${row.buyerEmail}'}'
            '${row.businessName == null ? '' : ' · ${row.businessName}'}',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          Text(
            'Pagó dos veces la misma tarjeta: reversa el cobro en PayPhone.',
            style: AppTypography.body(size: 13, weight: FontWeight.w300),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black, width: 1.2),
                shape: const StadiumBorder(),
                textStyle: AppTypography.label(size: 12, tracking: 1.5),
              ),
              child: const Text('YA LA DEVOLVÍ'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide una nota opcional antes de registrar algo. Devuelve el texto (vacío si
/// no escribió nada) o `null` si canceló.
Future<String?> _askNote(
  BuildContext context, {
  required String title,
  required String message,
  required String hint,
  required String action,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(title: title, message: message, hint: hint, action: action),
  );
}

class _NoteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String hint;
  final String action;

  const _NoteDialog({required this.title, required this.message, required this.hint, required this.action});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.black, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppTypography.display(size: 24)),
              const SizedBox(height: 8),
              Text(widget.message, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                maxLength: 200,
                decoration: InputDecoration(hintText: context.tr(widget.hint)),
              ),
              const SizedBox(height: 8),
              AppPrimaryButton(
                label: widget.action,
                onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
