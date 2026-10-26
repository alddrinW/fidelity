import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/branches/branches_repository.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../card_sales/data/card_sales_repository.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_image_picker.dart';
import 'widgets/customer_picker_sheet.dart';
import 'widgets/gift_card_voucher.dart';
import 'widgets/schedule_row.dart';

/// Crea una gift card (descuento o mini premio). Cada cliente elegido recibe
/// la suya, con su propio código, y una notificación; llega a todos
/// tus clientes o solo a los que elijas, ya o programada. Si el administrador
/// lo permite, también se puede **vender**: el cliente la compra con tarjeta.
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
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '50');
  final _daysController = TextEditingController(text: '30');

  /// La vende en vez de regalarla (solo si el administrador lo permite).
  bool _forSale = false;

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
    // La vista previa de la gift card se actualiza con lo que se escribe.
    for (final controller in [
      _titleController,
      _descriptionController,
      _valueController,
      _labelController,
      _priceController,
      _daysController,
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
      _priceController,
      _daysController,
    ]) {
      controller.removeListener(_refreshPreview);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _labelController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  /// La gift card tal como va a quedar, con lo que el local está escribiendo.
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
      priceCents: _forSale ? (centsFromInput(_priceController.text) ?? 0) : null,
      cardValidDays: _forSale ? (int.tryParse(_daysController.text.trim()) ?? 30) : null,
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
    if (_forSale) {
      if (_businessIds.length != 1) return 'Una tarjeta en venta es de un solo negocio.';
      final rules = ref.read(cardSalesRulesProvider).valueOrNull;
      final price = centsFromInput(_priceController.text);
      if (price == null) return 'Escribe el precio en dólares, por ejemplo 0.25.';
      if (rules != null && (price < rules.minPriceCents || price > rules.maxPriceCents)) {
        return 'El precio debe estar entre ${centsText(rules.minPriceCents)} y ${centsText(rules.maxPriceCents)}.';
      }
      final stock = int.tryParse(_stockController.text.trim());
      if (stock == null || stock < 1 || stock > 5000) return 'Pon entre 1 y 5000 tarjetas a la venta.';
      final days = int.tryParse(_daysController.text.trim());
      if (days == null || days < 1 || days > 365) return 'La tarjeta puede valer entre 1 y 365 días.';
    }
    if (!_forSale && _audience == CampaignAudience.selected && _recipientIds.isEmpty) {
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
            audience: _forSale ? CampaignAudience.all : _audience,
            recipientIds: !_forSale && _audience == CampaignAudience.selected ? _recipientIds.toList() : const [],
            priceCents: _forSale ? centsFromInput(_priceController.text) : null,
            stock: _forSale ? int.tryParse(_stockController.text.trim()) : null,
            cardValidDays: _forSale ? int.tryParse(_daysController.text.trim()) : null,
            startsAt: _scheduleStart ? _startsAt : null,
            endsAt: _hasEnd ? _endsAt : null,
          );
      if (!mounted) return;
      DashboardAnimatedToast.show(
        context,
        _forSale
            ? (_scheduleStart ? 'Tarjeta programada a la venta' : 'Tarjeta puesta en venta')
            : (_scheduleStart ? 'Gift card programada' : 'Gift card enviada a tus clientes'),
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
    // Los pasos se numeran en el orden en que aparecen (cambian si la vende).
    var step = 0;
    String stepOf(String title) => 'Paso ${++step} · $title';
    final rules = ref.watch(cardSalesRulesProvider).valueOrNull;
    final canSell = rules?.enabled ?? false;

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
                        // La plantilla: así se ve la gift card mientras se arma.
                        _TemplatePreview(
                          campaign: _previewCampaign(selected),
                          priceLabel: _forSale && (centsFromInput(_priceController.text) ?? 0) > 0
                              ? centsText(centsFromInput(_priceController.text)!)
                              : null,
                        ),
                        const SizedBox(height: 24),
                        // Solo si el administrador encendió la venta de tarjetas.
                        if (canSell) ...[
                          const AdminSectionLabel('¿La regalas o la vendes?'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AdminFilterPill(
                                label: 'La regalo',
                                selected: !_forSale,
                                onTap: () => setState(() => _forSale = false),
                              ),
                              AdminFilterPill(
                                label: 'La vendo',
                                selected: _forSale,
                                onTap: () => setState(() {
                                  _forSale = true;
                                  // Una tarjeta en venta es de un solo local.
                                  if (_businessIds.length > 1) {
                                    final first = _businessIds.first;
                                    _businessIds
                                      ..clear()
                                      ..add(first);
                                  }
                                  _recipientIds.clear();
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        _StepHeader(
                          stepOf('Datos de tu gift card'),
                          'Ponle un nombre y, si quieres, un mensaje para tus clientes. Lo que escribas aparece arriba, en la gift card.',
                        ),
                        AppTextField(
                          controller: _titleController,
                          hint: 'Nombre de la gift card (ej. Regalo de aniversario)',
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
                        _StepHeader(
                          stepOf('Qué regalas'),
                          'Descuento: un porcentaje menos en la cuenta. Mini premio: algo gratis, como un café.',
                        ),
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
                            helperText: 'Escribe un número de 1 a 100. Ej.: 10 = 10% de descuento.',
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
                            helperText: 'Escribe qué se lleva el cliente. Ej.: Café pequeño gratis.',
                            icon: Icons.redeem_rounded,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Describe el mini premio' : null,
                          ),
                        const SizedBox(height: 24),
                        if (_forSale && rules != null) ...[
                          _StepHeader(
                            stepOf('Precio y cupos'),
                            'Cuánto paga el cliente, cuántas tarjetas vendes y cuántos días le vale después de comprarla.',
                          ),
                          AppTextField(
                            controller: _priceController,
                            hint: 'Precio en dólares (ej. 0.25)',
                            icon: Icons.attach_money_rounded,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            helperText:
                                'Entre ${centsText(rules.minPriceCents)} y ${centsText(rules.maxPriceCents)}',
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _stockController,
                            hint: 'Cuántas tarjetas pones a la venta',
                            icon: Icons.inventory_2_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _daysController,
                            hint: 'Días que vale la tarjeta tras comprarla',
                            icon: Icons.event_available_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'El cliente la paga con tarjeta. Fidelity se queda el ${rules.commissionPercent}% de cada venta '
                            '(incluye el cobro de PayPhone) y te paga el resto cuando el cliente canjea la tarjeta.',
                            style: AppTypography.body(
                              size: 14,
                              weight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _StepHeader(
                          stepOf('Negocio'),
                          'Elige el negocio donde se canjea la gift card.',
                        ),
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
                                    if (_forSale) {
                                      // En venta: un solo negocio, el último que se toca.
                                      _businessIds
                                        ..clear()
                                        ..add(b.id);
                                    } else if (!_businessIds.remove(b.id)) {
                                      _businessIds.add(b.id);
                                    }
                                    // Los clientes elegidos dependen del negocio.
                                    _recipientIds.clear();
                                  }),
                                ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        if (!_forSale) ...[
                        _StepHeader(
                          stepOf('¿A quién le llega?'),
                          'A todos tus clientes o solo a los que elijas. Cada uno recibe su propia gift card, con su código.',
                        ),
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
                        ],
                        _StepHeader(
                          stepOf('Fecha y hora'),
                          'Elige el día y la hora. La hora en que vence se muestra en la gift card.',
                        ),
                        ScheduleDateTimeRow(
                          title: _forSale ? 'Empieza a venderse' : 'Cuándo se envía',
                          hint: 'Ahora, o el día y la hora exactos en que les llega a tus clientes.',
                          offLabel: 'Ahora',
                          onLabel: 'Programar',
                          isOn: _scheduleStart,
                          value: _startsAt,
                          // Si no se elige otra, se propone dentro de una hora, en punto.
                          defaultTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))).replacing(minute: 0),
                          onToggle: (on) => setState(() {
                            _scheduleStart = on;
                            if (!on) _startsAt = null;
                          }),
                          onChanged: (picked) => setState(() => _startsAt = picked),
                        ),
                        const SizedBox(height: 20),
                        ScheduleDateTimeRow(
                          title: _forSale ? 'Termina la venta' : 'Hasta cuándo vale',
                          hint: _forSale
                              ? 'El día y la hora en que ya no se puede comprar.'
                              : 'El día y la hora en que la gift card deja de servir. Sin fecha, no vence.',
                          offLabel: 'Sin fecha',
                          onLabel: 'Elegir fecha y hora',
                          isOn: _hasEnd,
                          value: _endsAt,
                          // Al elegir el día, vence al final de ese día (23:59) salvo que se cambie la hora.
                          defaultTime: const TimeOfDay(hour: 23, minute: 59),
                          firstDate: _scheduleStart ? _startsAt : null,
                          onToggle: (on) => setState(() {
                            _hasEnd = on;
                            if (!on) _endsAt = null;
                          }),
                          onChanged: (picked) => setState(() => _endsAt = picked),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _forSale
                              ? 'Tus clientes verán la tarjeta en Explorar y la compran con tarjeta. '
                                  'Al comprarla reciben su propia gift card, con su código.'
                              : 'Cada cliente recibe su propia gift card, con su código, '
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
                  label: _forSale
                      ? (_scheduleStart ? 'Programar venta' : 'Poner en venta')
                      : (_scheduleStart ? 'Programar' : 'Enviar gift card'),
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

/// La plantilla: la gift card tal como va a quedar mientras el local la arma.
class _TemplatePreview extends StatelessWidget {
  final Campaign campaign;
  final String? priceLabel;

  const _TemplatePreview({required this.campaign, this.priceLabel});

  @override
  Widget build(BuildContext context) {
    final business = campaign.businesses.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ASÍ SE VERÁ TU GIFT CARD', style: AppTypography.label(size: 12, tracking: 4)),
        const SizedBox(height: 2),
        Text(
          'Se actualiza mientras escribes.',
          style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        GiftCardVoucher(
          campaign: campaign,
          priceLabel: priceLabel,
          logoUrl: business?.logoUrl,
          businessName: business?.name,
        ),
      ],
    );
  }
}

/// El título de un paso del formulario con una línea que explica qué se llena ahí.
class _StepHeader extends StatelessWidget {
  final String title;
  final String hint;

  const _StepHeader(this.title, this.hint);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(title.toUpperCase(), style: AppTypography.label(size: 13, tracking: 3)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Text(
              hint,
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
