import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/branches/branches_repository.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_image_picker.dart';
import 'widgets/customer_picker_sheet.dart';
import 'widgets/gift_card_voucher.dart';
import 'widgets/schedule_row.dart';

/// Crea una gift card (descuento o mini premio). Cada cliente elegido recibe
/// la suya, con su propio cheque y código, y una notificación; llega a todos
/// tus clientes o solo a los que elijas, ya o programada.
class GiftCardFormScreen extends ConsumerStatefulWidget {
  const GiftCardFormScreen({super.key});

  @override
  ConsumerState<GiftCardFormScreen> createState() => _GiftCardFormScreenState();
}

class _GiftCardFormScreenState extends ConsumerState<GiftCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController(text: '10');
  final _labelController = TextEditingController();

  CampaignBenefit _benefit = CampaignBenefit.discountPercent;
  CampaignAudience _audience = CampaignAudience.all;
  final Set<String> _recipientIds = {};
  PickedImage? _image;

  bool _scheduleStart = false;
  DateTime? _startsAt;
  bool _hasEnd = false;
  DateTime? _endsAt;

  final Set<String> _businessIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // La vista previa del cheque se actualiza con lo que se escribe.
    for (final controller in [
      _titleController,
      _descriptionController,
      _valueController,
      _labelController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _descriptionController,
      _valueController,
      _labelController,
    ]) {
      controller.removeListener(_refreshPreview);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  /// El cheque tal como va a quedar, con lo que el local está escribiendo.
  Campaign _previewCampaign(List<BusinessOverview> businesses) {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final value = int.tryParse(_valueController.text.trim());
    final label = _labelController.text.trim();

    return Campaign(
      id: 'preview',
      type: CampaignType.giftCard,
      title: title.isEmpty ? 'TU GIFT CARD' : title,
      phase: CampaignPhase.active,
      benefitType: _benefit,
      benefitValue: _benefit == CampaignBenefit.discountPercent ? value : null,
      benefitLabel: _benefit == CampaignBenefit.miniPrize
          ? (label.isEmpty ? 'Un premio sorpresa' : label)
          : null,
      description: description.isEmpty ? null : description,
      imageUrl: _image?.dataUri,
      businesses: [
        for (final b in businesses)
          CampaignBusinessRef(id: b.id, name: b.name, logoUrl: b.logoUrl),
      ],
      endsAt: _hasEnd ? _endsAt : null,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await pickImageFromGallery(maxSide: 1024);
      if (picked != null && mounted) setState(() => _image = picked);
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _pickRecipients() async {
    if (_businessIds.isEmpty) {
      _showError('Elige primero el negocio.');
      return;
    }
    final picked = await showCustomerPicker(
      context,
      repository: ref.read(campaignsRepositoryProvider),
      businessIds: _businessIds.toList(),
      initial: _recipientIds,
    );
    if (picked != null && mounted) {
      setState(() {
        _recipientIds
          ..clear()
          ..addAll(picked);
      });
    }
  }

  String? _validate() {
    if (_businessIds.isEmpty) return 'Elige al menos un negocio.';
    if (_audience == CampaignAudience.selected && _recipientIds.isEmpty) {
      return 'Elige al menos un cliente.';
    }
    if (_scheduleStart && _startsAt == null) return 'Elige cuándo empieza la gift card.';
    if (_hasEnd && _endsAt == null) return 'Elige cuándo vence la gift card.';
    final start = _scheduleStart ? _startsAt! : DateTime.now();
    if (_hasEnd && !_endsAt!.isAfter(start)) {
      return 'La fecha de vencimiento debe ser posterior al inicio.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(campaignsRepositoryProvider).create(
            type: CampaignType.giftCard,
            title: _titleController.text,
            description: _descriptionController.text,
            imageDataUri: _image?.dataUri,
            businessIds: _businessIds.toList(),
            benefitType: _benefit,
            benefitValue: _benefit == CampaignBenefit.discountPercent
                ? int.tryParse(_valueController.text.trim())
                : null,
            benefitLabel:
                _benefit == CampaignBenefit.miniPrize ? _labelController.text : null,
            audience: _audience,
            recipientIds: _audience == CampaignAudience.selected ? _recipientIds.toList() : const [],
            startsAt: _scheduleStart ? _startsAt : null,
            endsAt: _hasEnd ? _endsAt : null,
          );
      if (!mounted) return;
      DashboardAnimatedToast.show(
        context,
        _scheduleStart ? 'Gift card programada' : 'Gift card enviada a tus clientes',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businesses = ref.watch(businessOverviewProvider);
    final active = (businesses.valueOrNull ?? const <BusinessOverview>[])
        .where((b) => b.isActive)
        .toList();

    // Con un solo negocio activo, ya viene elegido.
    if (active.length == 1 && _businessIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _businessIds.isEmpty) setState(() => _businessIds.add(active.first.id));
      });
    }

    final selected = active.where((b) => _businessIds.contains(b.id)).toList();

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Nueva gift card'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // La plantilla: así se ve el cheque mientras lo armamos.
                        _TemplatePreview(
                          campaign: _previewCampaign(selected),
                        ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('El cheque'),
                        AppTextField(
                          controller: _titleController,
                          hint: 'Nombre (ej. Regalo de aniversario)',
                          icon: Icons.card_giftcard_rounded,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.length < 3) return 'El nombre debe tener al menos 3 caracteres';
                            if (t.length > 120) return 'Máximo 120 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _descriptionController,
                          hint: 'Mensaje para tus clientes (opcional)',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) =>
                              (v?.trim().length ?? 0) > 1000 ? 'Máximo 1000 caracteres' : null,
                        ),
                        const SizedBox(height: 14),
                        CampaignImagePicker(
                          bytes: _image?.bytes,
                          onPick: _pickImage,
                          onRemove: () => setState(() => _image = null),
                        ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('Beneficio'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in CampaignBenefit.values)
                              AdminFilterPill(
                                label: b.label,
                                selected: _benefit == b,
                                onTap: () => setState(() => _benefit = b),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_benefit == CampaignBenefit.discountPercent)
                          AppTextField(
                            controller: _valueController,
                            hint: 'Porcentaje de descuento',
                            icon: Icons.percent_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              return (n == null || n < 1 || n > 100)
                                  ? 'Ingresa un valor entre 1 y 100'
                                  : null;
                            },
                          )
                        else
                          AppTextField(
                            controller: _labelController,
                            hint: 'Mini premio (ej. Café pequeño gratis)',
                            icon: Icons.redeem_rounded,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Describe el mini premio' : null,
                          ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('Negocio'),
                        if (businesses.isLoading)
                          const Center(child: CircularProgressIndicator(color: AppColors.black))
                        else if (active.isEmpty)
                          Text(
                            'Necesitas al menos un negocio activo para enviar gift cards.',
                            style: AppTypography.body(size: 15, weight: FontWeight.w300),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final b in active)
                                AdminFilterPill(
                                  label: b.name,
                                  icon: _businessIds.contains(b.id) ? Icons.check_rounded : null,
                                  selected: _businessIds.contains(b.id),
                                  onTap: () => setState(() {
                                    if (!_businessIds.remove(b.id)) _businessIds.add(b.id);
                                    // Los clientes elegidos dependen del negocio.
                                    _recipientIds.clear();
                                  }),
                                ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('¿A quién le llega?'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in CampaignAudience.values)
                              AdminFilterPill(
                                label: a.label,
                                selected: _audience == a,
                                onTap: () => setState(() => _audience = a),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_audience == CampaignAudience.selected) ...[
                          OutlinedButton.icon(
                            onPressed: _pickRecipients,
                            icon: const Icon(Icons.people_alt_outlined),
                            label: Text(
                              _recipientIds.isEmpty
                                  ? 'ELEGIR CLIENTES'
                                  : '${_recipientIds.length} ${_recipientIds.length == 1 ? 'CLIENTE ELEGIDO' : 'CLIENTES ELEGIDOS'}',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.black,
                              side: const BorderSide(color: AppColors.black, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: const StadiumBorder(),
                              textStyle: AppTypography.label(size: 13, tracking: 1.5),
                            ),
                          ),
                        ] else
                          Text(
                            'Le llegará a cada cliente que tenga tarjeta en tu negocio.',
                            style: AppTypography.body(
                              size: 14,
                              weight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('Cuándo'),
                        ScheduleRow(
                          title: 'Se envía',
                          offLabel: 'Ahora',
                          onLabel: 'Programar',
                          isOn: _scheduleStart,
                          value: _startsAt == null ? null : formatCampaignDateTime(_startsAt!),
                          onToggle: (on) => setState(() {
                            _scheduleStart = on;
                            if (!on) _startsAt = null;
                          }),
                          onPick: () async {
                            final picked = await pickCampaignDateTime(context, _startsAt);
                            if (picked != null) setState(() => _startsAt = picked);
                          },
                        ),
                        const SizedBox(height: 12),
                        ScheduleRow(
                          title: 'Vence',
                          offLabel: 'Sin fecha',
                          onLabel: 'Elegir fecha',
                          isOn: _hasEnd,
                          value: _endsAt == null ? null : formatCampaignDateTime(_endsAt!),
                          onToggle: (on) => setState(() {
                            _hasEnd = on;
                            if (!on) _endsAt = null;
                          }),
                          onPick: () async {
                            final picked = await pickCampaignDateTime(context, _endsAt ?? _startsAt);
                            if (picked != null) setState(() => _endsAt = picked);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cada cliente recibe su propia gift card, con su cheque y su código, '
                          'y una notificación.',
                          style: AppTypography.body(
                            size: 14,
                            weight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AppPrimaryButton(
                  label: _scheduleStart ? 'Programar' : 'Enviar gift card',
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La plantilla: el cheque tal como va a quedar mientras el local lo arma.
class _TemplatePreview extends StatelessWidget {
  final Campaign campaign;

  const _TemplatePreview({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final business = campaign.businesses.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ASÍ SE VERÁ EL CHEQUE', style: AppTypography.label(size: 12, tracking: 4)),
        const SizedBox(height: 10),
        GiftCardVoucher(
          campaign: campaign,
          logoUrl: business?.logoUrl,
          businessName: business?.name,
        ),
      ],
    );
  }
}
