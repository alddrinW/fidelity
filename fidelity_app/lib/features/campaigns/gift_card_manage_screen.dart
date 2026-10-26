import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/image_picking.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_image_picker.dart';
import 'widgets/gift_card_voucher.dart';
import 'widgets/schedule_row.dart';

/// Una gift card vista por su dueño: cifras, el cheque tal como lo verá el
/// cliente, las gift cards emitidas a cada cliente (con su código de letras) y
/// las opciones de editarla o cancelarla.
class GiftCardManageScreen extends ConsumerStatefulWidget {
  final Campaign campaign;

  const GiftCardManageScreen({super.key, required this.campaign});

  @override
  ConsumerState<GiftCardManageScreen> createState() => _GiftCardManageScreenState();
}

class _GiftCardManageScreenState extends ConsumerState<GiftCardManageScreen> {
  late Campaign _campaign = widget.campaign;
  bool _isLoading = true;
  bool _changed = false;
  List<IssuedClaim> _claims = [];

  bool get _canChange =>
      _campaign.phase == CampaignPhase.active || _campaign.phase == CampaignPhase.scheduled;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
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
        DashboardAnimatedToast.show(context, 'No se pudieron cargar las gift cards', isError: true);
      }
    }
  }

  Future<void> _edit() async {
    final updated = await showDialog<Campaign>(
      context: context,
      builder: (_) => GiftCardEditDialog(campaign: _campaign),
    );
    if (updated == null || !mounted) return;
    // El servidor no devuelve las cifras: se conservan las que ya teníamos.
    setState(() {
      _campaign = Campaign(
        id: updated.id,
        type: updated.type,
        title: updated.title,
        description: updated.description,
        imageUrl: updated.imageUrl,
        benefitType: updated.benefitType,
        benefitValue: updated.benefitValue,
        benefitLabel: updated.benefitLabel,
        audience: updated.audience,
        startsAt: updated.startsAt,
        endsAt: updated.endsAt,
        phase: updated.phase,
        businesses: updated.businesses,
        stats: _campaign.stats,
      );
      _changed = true;
    });
    DashboardAnimatedToast.show(context, 'Gift card actualizada');
  }

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.cancel_outlined,
        title: '¿Cancelar gift card?',
        message: 'Tus clientes dejarán de poder canjearla y recibirán un aviso.',
        primaryLabel: 'Cancelar gift card',
        onPrimary: () async {
          try {
            await ref.read(campaignsRepositoryProvider).cancel(_campaign.id);
            if (!mounted) return;
            DashboardAnimatedToast.show(context, 'Gift card cancelada');
            Navigator.of(context).pop(true);
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
    final redeemed = _claims.where((x) => x.isRedeemed).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: AppResponsiveBody(
            adaptive: true,
            child: Column(
              children: [
                AppPageHeader(
                  title: 'Gift card',
                  onBack: () => Navigator.of(context).pop(_changed),
                ),
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
                          AppChip(label: c.audience.label, icon: Icons.people_alt_outlined),
                          for (final b in c.businesses)
                            AppChip(label: b.name, icon: Icons.storefront_outlined),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // El cheque tal como lo verá el cliente.
                      GiftCardVoucher(
                        campaign: c,
                        logoUrl: c.businesses.firstOrNull?.logoUrl,
                        businessName: c.businesses.firstOrNull?.name,
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
                            AdminInfoLine(
                              icon: Icons.play_arrow_rounded,
                              text: 'Se envía ${_day(c.startsAt)}',
                            ),
                            AdminInfoLine(
                              icon: Icons.stop_rounded,
                              text: c.endsAt == null ? 'Sin fecha de vencimiento' : 'Vence ${_day(c.endsAt)}',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  _Stat(label: 'Enviadas', value: _isLoading ? (c.stats?.claims ?? 0) : _claims.length),
                                  _Stat(label: 'Canjeadas', value: _isLoading ? (c.stats?.redeemed ?? 0) : redeemed),
                                  _Stat(
                                    label: 'Sin canjear',
                                    value: _isLoading
                                        ? ((c.stats?.claims ?? 0) - (c.stats?.redeemed ?? 0))
                                        : _claims.length - redeemed,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canChange) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('EDITAR GIFT CARD'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.black,
                            side: const BorderSide(color: AppColors.black, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const StadiumBorder(),
                            textStyle: AppTypography.label(size: 13, tracking: 1.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const AdminSectionLabel('Gift cards de tus clientes'),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: AppColors.black))
                      else if (_claims.isEmpty)
                        Text(
                          c.phase == CampaignPhase.scheduled
                              ? 'Se enviarán a tus clientes cuando llegue la hora.'
                              : 'Todavía no se envió ninguna.',
                          style: AppTypography.body(size: 15, weight: FontWeight.w300),
                        )
                      else
                        for (final claim in _claims) ...[
                          _ClaimRow(
                            claim: claim,
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => GiftCardCodeDialog(
                                claim: claim,
                                campaign: c,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (_canChange) ...[
                        const SizedBox(height: 24),
                        AppTextAction(label: 'Cancelar gift card', onPressed: _confirmCancel),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTypography.display(size: 26)),
          Text(
            label.toUpperCase(),
            style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  final IssuedClaim claim;
  final VoidCallback onTap;

  const _ClaimRow({required this.claim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claim.code, style: AppTypography.display(size: 20)),
                Text(
                  claim.userName ?? claim.userEmail ?? 'Cliente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

/// La gift card de un cliente: su código de letras, para dictarlo o escribirlo.
class GiftCardCodeDialog extends StatelessWidget {
  final IssuedClaim claim;
  final Campaign campaign;

  const GiftCardCodeDialog({super.key, required this.claim, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppChip(
              label: claim.isRedeemed ? 'Canjeada' : 'Vigente',
              style: claim.isRedeemed ? AppChipStyle.outline : AppChipStyle.dark,
            ),
            const SizedBox(height: 16),
            GiftCardVoucher(
              campaign: campaign,
              code: claim.code,
              redeemed: claim.isRedeemed,
              logoUrl: campaign.businesses.firstOrNull?.logoUrl,
              businessName: campaign.businesses.firstOrNull?.name,
            ),
            const SizedBox(height: 16),
            Text(
              claim.userName ?? claim.userEmail ?? 'Cliente',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'El cliente te muestra este código para canjearlo.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, weight: FontWeight.w300),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: claim.code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado')),
              );
            }
          },
          child: const Text('Copiar código'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CERRAR'),
        ),
      ],
    );
  }
}

/// Edita una gift card: nombre, mensaje, beneficio y fecha de vencimiento.
/// Cierra con la gift card actualizada.
class GiftCardEditDialog extends ConsumerStatefulWidget {
  final Campaign campaign;

  const GiftCardEditDialog({super.key, required this.campaign});

  @override
  ConsumerState<GiftCardEditDialog> createState() => _GiftCardEditDialogState();
}

class _GiftCardEditDialogState extends ConsumerState<GiftCardEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.campaign.title);
  late final _description = TextEditingController(text: widget.campaign.description ?? '');
  late final _value = TextEditingController(text: '${widget.campaign.benefitValue ?? 10}');
  late final _label = TextEditingController(text: widget.campaign.benefitLabel ?? '');
  DateTime? _endsAt;
  bool _isSaving = false;
  String? _error;

  /// La imagen de fondo del cheque: los bytes de la recién elegida y el dato
  /// que se manda al servidor (cadena vacía = quitarla).
  Uint8List? _imageBytes;
  String? _imageDataUri;
  bool _imageChanged = false;

  bool get _isDiscount => widget.campaign.benefitType == CampaignBenefit.discountPercent;

  @override
  void initState() {
    super.initState();
    // La vista previa del cheque se actualiza con lo que se escribe.
    for (final controller in [_title, _description, _value, _label]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [_title, _description, _value, _label]) {
      controller.removeListener(_refreshPreview);
    }
    _title.dispose();
    _description.dispose();
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await pickImageFromGallery(maxSide: 1024);
      if (picked != null && mounted) {
        setState(() {
          _imageBytes = picked.bytes;
          _imageDataUri = picked.dataUri;
          _imageChanged = true;
        });
      }
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// El cheque tal como va a quedar, con lo que se está editando.
  Campaign _previewCampaign() {
    final c = widget.campaign;
    final title = _title.text.trim();
    final description = _description.text.trim();
    final value = int.tryParse(_value.text.trim());
    final label = _label.text.trim();

    return Campaign(
      id: c.id,
      type: CampaignType.giftCard,
      title: title.isEmpty ? c.title : title,
      phase: c.phase,
      benefitType: c.benefitType,
      benefitValue: _isDiscount ? value : c.benefitValue,
      benefitLabel: _isDiscount
          ? c.benefitLabel
          : (label.isEmpty ? c.benefitLabel : label),
      description: description.isEmpty ? null : description,
      imageUrl: _imageChanged
          ? (_imageDataUri?.isEmpty == true ? null : _imageDataUri)
          : c.imageUrl,
      priceCents: c.priceCents,
      cardValidDays: c.cardValidDays,
      businesses: c.businesses,
      endsAt: _endsAt ?? c.endsAt,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final c = widget.campaign;
    try {
      final updated = await ref.read(campaignsRepositoryProvider).update(
            c.id,
            title: _title.text.trim() == c.title ? null : _title.text,
            description:
                _description.text.trim() == (c.description ?? '').trim() ? null : _description.text,
            benefitValue: _isDiscount && int.tryParse(_value.text.trim()) != c.benefitValue
                ? int.tryParse(_value.text.trim())
                : null,
            benefitLabel: !_isDiscount && _label.text.trim() != (c.benefitLabel ?? '').trim()
                ? _label.text
                : null,
            endsAt: _endsAt,
            imageDataUri: _imageChanged ? _imageDataUri : null,
          );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'EDITAR GIFT CARD',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La plantilla: el cheque tal como va a quedar.
              GiftCardVoucher(
                campaign: _previewCampaign(),
                logoUrl: widget.campaign.businesses.firstOrNull?.logoUrl,
                businessName: widget.campaign.businesses.firstOrNull?.name,
              ),
              const SizedBox(height: 20),
              Text(
                widget.campaign.isForSale
                    ? 'Quienes ya la compraron conservan su tarjeta tal cual.'
                    : 'Quienes ya la tienen recibirán un aviso del cambio.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, weight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _title,
                hint: 'Nombre',
                icon: Icons.card_giftcard_rounded,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'Mínimo 3 caracteres' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _description,
                hint: 'Mensaje (opcional)',
                icon: Icons.notes_rounded,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              CampaignImagePicker(
                bytes: _imageBytes,
                imageUri: _imageChanged
                    ? (_imageDataUri?.isEmpty == true ? null : _imageDataUri)
                    : widget.campaign.imageUrl,
                onPick: _pickImage,
                onRemove: () => setState(() {
                  _imageBytes = null;
                  _imageDataUri = '';
                  _imageChanged = true;
                }),
              ),
              const SizedBox(height: 12),
              // El beneficio de una tarjeta en venta no se cambia: los clientes la pagan por lo que ofrece.
              if (widget.campaign.isForSale)
                const SizedBox.shrink()
              else if (_isDiscount)
                AppTextField(
                  controller: _value,
                  hint: 'Porcentaje de descuento',
                  icon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return (n == null || n < 1 || n > 100) ? 'Entre 1 y 100' : null;
                  },
                )
              else
                AppTextField(
                  controller: _label,
                  hint: 'Mini premio',
                  icon: Icons.redeem_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Describe el mini premio' : null,
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickCampaignDateTime(context, _endsAt ?? widget.campaign.endsAt);
                  if (picked != null) setState(() => _endsAt = picked);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _endsAt == null
                      ? (widget.campaign.endsAt == null ? 'FIJAR VENCIMIENTO' : 'CAMBIAR VENCIMIENTO')
                      : formatCampaignDateTime(_endsAt!),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.black,
                  side: const BorderSide(color: AppColors.black, width: 1.2),
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.label(size: 12, tracking: 1.5),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}
