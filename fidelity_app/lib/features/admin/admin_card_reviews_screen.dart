import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../card_sales/data/card_sales_repository.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';

/// Comprobantes de las tarjetas pagadas por transferencia: el administrador mira la foto,
/// compara el monto y la referencia con su banco y la aprueba (el cliente recibe su
/// tarjeta) o la rechaza con un motivo (el cliente lo ve y puede intentarlo de nuevo).
class AdminCardReviewsScreen extends ConsumerStatefulWidget {
  const AdminCardReviewsScreen({super.key});

  @override
  ConsumerState<AdminCardReviewsScreen> createState() => _AdminCardReviewsScreenState();
}

class _AdminCardReviewsScreenState extends ConsumerState<AdminCardReviewsScreen> {
  /// El comprobante que se está aprobando o rechazando (evita dobles toques).
  String? _busyId;

  void _toast(String message, {bool isError = false}) {
    if (mounted) DashboardAnimatedToast.show(context, message, isError: isError);
  }

  Future<void> _decide(String id, Future<void> Function() action, String done) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await action();
      ref.invalidate(cardReviewsProvider);
      _toast(done);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), isError: true);
      // Si otro administrador ya lo revisó, la lista se actualiza.
      ref.invalidate(cardReviewsProvider);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _confirmApprove(CardReview review) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.verified_outlined,
        title: 'Aprobar comprobante',
        message: '¿Ya viste en tu banco la transferencia de ${centsText(review.amountCents)} '
            'con la referencia ${review.reference}?',
        hint: 'Al aprobarlo, ${review.buyer ?? 'el cliente'} recibe su tarjeta.',
        primaryLabel: 'Sí, aprobar',
        onPrimary: () => _decide(
          review.id,
          () => ref.read(cardSalesRepositoryProvider).approveReview(review.id),
          'Comprobante aprobado',
        ),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  Future<void> _reject(CardReview review) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(reference: review.reference),
    );
    if (reason == null || reason.isEmpty) return;
    await _decide(
      review.id,
      () => ref.read(cardSalesRepositoryProvider).rejectReview(review.id, reason),
      'Comprobante rechazado',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cardReviewsProvider);
    final list = async.valueOrNull;

    return AdminPageFrame(
      title: 'Comprobantes de tarjetas',
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async => ref.invalidate(cardReviewsProvider),
        child: list == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 360,
                    child: async.hasError
                        ? const AppEmptyState.error(message: 'No pudimos cargar los comprobantes. Desliza para reintentar.')
                        : const AdminLoading(),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  Text(
                    'Clientes que pagaron una tarjeta por transferencia. Revisa la foto, compara el monto y la '
                    'referencia con tu banco y aprueba: así reciben su tarjeta.',
                    style: AppTypography.body(size: 14, weight: FontWeight.w300),
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: AppEmptyState(
                        title: 'Todo al día',
                        message: 'No hay comprobantes por revisar.',
                        imageHeight: 110,
                      ),
                    )
                  else
                    for (final review in list) ...[
                      _ReviewTile(
                        review: review,
                        busy: _busyId == review.id,
                        onApprove: () => _confirmApprove(review),
                        onReject: () => _reject(review),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final CardReview review;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewTile({required this.review, required this.busy, required this.onApprove, required this.onReject});

  void _zoom(BuildContext context, ImageProvider image) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(minScale: 1, maxScale: 5, child: Image(image: image, fit: BoxFit.contain)),
            IconButton.filled(
              tooltip: context.tr('Cerrar'),
              style: IconButton.styleFrom(backgroundColor: AppColors.black),
              icon: const Icon(Icons.close_rounded, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(review.proofUrl);
    final sent = review.reportedAt;

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((review.title ?? 'Tarjeta').toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.display(size: 20)),
                    if (review.businessName != null)
                      Text(
                        review.businessName!,
                        style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(centsText(review.amountCents), style: AppTypography.display(size: 28)),
            ],
          ),
          const SizedBox(height: 10),
          _Line(label: 'Referencia', value: review.reference),
          _Line(label: 'Cliente', value: '${review.buyer ?? 'Cliente'}${review.buyerEmail == null ? '' : ' · ${review.buyerEmail}'}'),
          if (review.note != null && review.note!.isNotEmpty) _Line(label: 'Nota', value: review.note!),
          if (sent != null) _Line(label: 'Enviado', value: '${formatShortDate(sent)} ${sent.hour.toString().padLeft(2, '0')}:${sent.minute.toString().padLeft(2, '0')}'),
          const SizedBox(height: 12),
          if (image != null)
            MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                onTap: () => _zoom(context, image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image(
                    image: image,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 60),
                  ),
                ),
              ),
            )
          else
            Text(
              'Este comprobante no tiene foto.',
              style: AppTypography.body(size: 14, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.black,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.black, width: 1.2),
                    shape: const StadiumBorder(),
                    textStyle: AppTypography.label(size: 12, tracking: 1.5),
                  ),
                  child: const Text('RECHAZAR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: AppColors.black,
                    disabledBackgroundColor: AppColors.pink,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    side: const BorderSide(color: AppColors.black, width: 1.2),
                    shape: const StadiumBorder(),
                    textStyle: AppTypography.label(size: 12, tracking: 1.5),
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                      : const Text('APROBAR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label.toUpperCase(), style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary)),
          ),
          Expanded(child: SelectableText(value, style: AppTypography.body(size: 14, weight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Pide el motivo del rechazo (obligatorio: el cliente lo lee para corregir). Algunos
/// motivos comunes se ponen con un toque.
class _RejectDialog extends StatefulWidget {
  final String reference;

  const _RejectDialog({required this.reference});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  static const _quick = [
    'El monto no coincide',
    'No encontramos la transferencia',
    'La foto no se lee bien',
  ];

  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(reason);
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
              Text('Rechazar ${widget.reference}', style: AppTypography.display(size: 24)),
              const SizedBox(height: 8),
              Text(
                'Escribe el motivo: el cliente lo verá para corregirlo e intentarlo de nuevo.',
                style: AppTypography.body(size: 14, weight: FontWeight.w300),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _quick)
                    ActionChip(
                      label: Text(q),
                      onPressed: () => setState(() {
                        _controller.text = context.tr(q);
                        _showError = false;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLength: 300,
                maxLines: 2,
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
                decoration: InputDecoration(
                  hintText: context.tr('Motivo del rechazo'),
                  errorText: _showError ? context.tr('Escribe el motivo para que el cliente sepa qué corregir') : null,
                ),
              ),
              const SizedBox(height: 8),
              AppPrimaryButton(label: 'Rechazar comprobante', onPressed: _submit),
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
