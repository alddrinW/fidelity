import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/fido_says.dart';
import '../admin/data/admin_date_filter.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../payments/paga_ya_screen.dart' show BankAccountCard, ProofPicker;
import 'data/card_sales_repository.dart';

/// Pagar una tarjeta en venta por transferencia: el cliente ve cuánto transferir, la
/// referencia que debe poner y las cuentas, y sube la foto de su comprobante. El
/// administrador lo revisa y, al aprobarlo, la tarjeta llega a *Mis regalos*.
///
/// Cierra con `true` cuando el comprobante quedó enviado.
class CardTransferScreen extends ConsumerStatefulWidget {
  final Campaign offer;
  final TransferStart start;

  /// Cómo se elige la foto (en las pruebas se cambia por una de mentira).
  final Future<PickedImage?> Function()? pickImage;

  const CardTransferScreen({super.key, required this.offer, required this.start, this.pickImage});

  @override
  ConsumerState<CardTransferScreen> createState() => _CardTransferScreenState();
}

class _CardTransferScreenState extends ConsumerState<CardTransferScreen> {
  final _note = TextEditingController();
  PickedImage? _proof;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickProof() async {
    try {
      final picked = await (widget.pickImage?.call() ?? pickImageFromGallery(maxSide: 1280));
      if (picked != null && mounted) setState(() => _proof = picked);
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _send() async {
    final proof = _proof;
    if (proof == null) {
      _showError('Adjunta la foto del comprobante de la transferencia.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(cardSalesRepositoryProvider).submitProof(
            widget.start.purchaseId,
            proof.dataUri,
            note: _note.text,
          );
      if (!mounted) return;
      // El botón deja de girar antes del aviso (si no, seguiría girando detrás).
      setState(() => _sending = false);
      await showDialog<void>(
        context: context,
        builder: (_) => const AppMessageDialog(
          icon: Icons.hourglass_top_rounded,
          title: 'Comprobante enviado',
          message: 'Lo revisaremos y te avisaremos apenas lo aprobemos: tu tarjeta llegará a Mis regalos.',
          primaryLabel: 'Entendido',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// "hasta las 18:30" si es hoy; si no, con el día.
  String _holdText(DateTime until) {
    final hh = until.hour.toString().padLeft(2, '0');
    final mm = until.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = until.year == now.year && until.month == now.month && until.day == now.day;
    return today
        ? 'Guardamos tu tarjeta hasta las $hh:$mm.'
        : 'Guardamos tu tarjeta hasta el ${formatShortDate(until)} a las $hh:$mm.';
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    final hold = start.reservedUntil;
    final amount = centsText(start.amountCents);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Pagar por transferencia'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    const FidoSays(
                      message: 'Transfiere el monto exacto y sube la foto de tu comprobante: lo revisamos y te llega la tarjeta.',
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      radius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MONTO A TRANSFERIR', style: AppTypography.label(size: 12, tracking: 4)),
                          const SizedBox(height: 4),
                          Text(amount, style: AppTypography.display(size: 44)),
                          const SizedBox(height: 12),
                          Text('REFERENCIA', style: AppTypography.label(size: 12, tracking: 4)),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(start.reference, style: AppTypography.display(size: 28)),
                              ),
                              IconButton(
                                tooltip: context.tr('Copiar referencia'),
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                onPressed: () => _copy(start.reference, 'Referencia copiada'),
                              ),
                            ],
                          ),
                          Text(
                            'Escríbela en el concepto o comentario de la transferencia.',
                            style: AppTypography.body(size: 14, weight: FontWeight.w300),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      start.bankAccounts.length == 1 ? 'TRANSFIERE A ESTA CUENTA' : 'TRANSFIERE A UNA DE ESTAS CUENTAS',
                      style: AppTypography.label(size: 13, tracking: 3),
                    ),
                    const SizedBox(height: 10),
                    for (final bank in start.bankAccounts) ...[
                      BankAccountCard(bank: bank, onCopy: _copy),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Text('FOTO DEL COMPROBANTE *', style: AppTypography.label(size: 13, tracking: 4)),
                    const SizedBox(height: 4),
                    Text(
                      'Foto clara y legible de la transferencia.',
                      style: AppTypography.body(size: 14, weight: FontWeight.w300),
                    ),
                    const SizedBox(height: 12),
                    ProofPicker(proof: _proof, onPick: _pickProof, onRemove: () => setState(() => _proof = null)),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _note,
                      hint: 'N.º de transacción o comprobante (opcional)',
                      icon: Icons.tag_rounded,
                      textInputAction: TextInputAction.done,
                    ),
                    if (hold != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _holdText(hold),
                        textAlign: TextAlign.center,
                        style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 48, 24),
                child: AppPrimaryButton(
                  label: 'Enviar comprobante',
                  isLoading: _sending,
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
