import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/branches/branches_repository.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import 'widgets/campaign_image_picker.dart';
import 'widgets/schedule_row.dart';
import '../../core/l10n/tr_text.dart';

/// Crea una campaña: evento, ruta (pasaporte) o reto de escaneos. Se puede
/// lanzar ya o programar para una fecha futura, con fin opcional. En un reto el
/// dueño dice cuántos escaneos debe hacer el cliente para ganar el premio.
class CampaignFormScreen extends ConsumerStatefulWidget {
  const CampaignFormScreen({super.key});

  @override
  ConsumerState<CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends ConsumerState<CampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController(text: '10');
  final _labelController = TextEditingController();
  final _stampsController = TextEditingController();
  final _scansController = TextEditingController(text: '5');

  CampaignType _type = CampaignType.event;
  CampaignBenefit _benefit = CampaignBenefit.discountPercent;
  PickedImage? _image;

  bool _scheduleStart = false;
  DateTime? _startsAt;
  bool _hasEnd = false;
  DateTime? _endsAt;

  final Set<String> _businessIds = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _labelController.dispose();
    _stampsController.dispose();
    _scansController.dispose();
    super.dispose();
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

  String? _validate() {
    if (_businessIds.isEmpty) return 'Elige al menos un negocio participante.';
    if (_type == CampaignType.route && _businessIds.length < 2) {
      return 'Una ruta necesita al menos 2 locales.';
    }
    if (_scheduleStart && _startsAt == null) return 'Elige cuándo empieza la campaña.';
    if (_hasEnd && _endsAt == null) return 'Elige cuándo termina la campaña.';
    final start = _scheduleStart ? _startsAt! : DateTime.now();
    if (_hasEnd && !_endsAt!.isAfter(start)) {
      return 'La fecha de fin debe ser posterior al inicio.';
    }
    if (_type == CampaignType.route) {
      final stamps = int.tryParse(_stampsController.text.trim());
      if (stamps != null && (stamps < 2 || stamps > _businessIds.length)) {
        return 'Los sellos deben estar entre 2 y ${_businessIds.length}.';
      }
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

    final isGift = _type == CampaignType.giftCard;
    final isRoute = _type == CampaignType.route;
    final isChallenge = _type == CampaignType.scanChallenge;
    // El premio del reto es, como una gift card, un descuento o un mini premio.
    final hasBenefit = isGift || isChallenge;

    setState(() => _isSaving = true);
    try {
      await ref.read(campaignsRepositoryProvider).create(
            type: _type,
            title: _titleController.text,
            description: _descriptionController.text,
            imageDataUri: _image?.dataUri,
            businessIds: _businessIds.toList(),
            benefitType: hasBenefit ? _benefit : null,
            benefitValue: hasBenefit && _benefit == CampaignBenefit.discountPercent
                ? int.tryParse(_valueController.text.trim())
                : null,
            benefitLabel: (hasBenefit && _benefit == CampaignBenefit.miniPrize) || isRoute
                ? _labelController.text
                : null,
            requiredStamps: isRoute ? int.tryParse(_stampsController.text.trim()) : null,
            requiredScans: isChallenge ? int.tryParse(_scansController.text.trim()) : null,
            startsAt: _scheduleStart ? _startsAt : null,
            endsAt: _hasEnd ? _endsAt : null,
          );
      if (!mounted) return;
      DashboardAnimatedToast.show(
        context,
        _scheduleStart ? 'Campaña programada' : 'Campaña lanzada',
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

    final isRoute = _type == CampaignType.route;
    final isChallenge = _type == CampaignType.scanChallenge;
    final hasBenefit = _type == CampaignType.giftCard || isChallenge;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Nueva campaña'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AdminSectionLabel('Tipo de campaña'),
                        for (final type in CampaignType.values.where((t) => t != CampaignType.giftCard)) ...[
                          _TypeOption(
                            type: type,
                            selected: _type == type,
                            onTap: () => setState(() => _type = type),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 14),
                        const AdminSectionLabel('Contenido'),
                        AppTextField(
                          controller: _titleController,
                          hint: 'Título de la campaña',
                          icon: Icons.title_rounded,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.length < 3) return 'El título debe tener al menos 3 caracteres';
                            if (t.length > 120) return 'Máximo 120 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _descriptionController,
                          hint: 'Descripción (opcional)',
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
                        if (isChallenge) ...[
                          const SizedBox(height: 24),
                          const AdminSectionLabel('Escaneos que pides'),
                          AppTextField(
                            controller: _scansController,
                            hint: 'Cuántos escaneos debe hacer el cliente',
                            icon: Icons.qr_code_scanner_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              return (n == null || n < 2 || n > 100)
                                  ? 'Ingresa un número entre 2 y 100'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cuentan los escaneos reales de tu código QR, aprobados, mientras dure la campaña.',
                            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                          ),
                        ],
                        if (hasBenefit) ...[
                          const SizedBox(height: 24),
                          AdminSectionLabel(isChallenge ? 'Premio del reto' : 'Beneficio'),
                          Row(
                            children: [
                              for (final b in CampaignBenefit.values) ...[
                                AdminFilterPill(
                                  label: b.label,
                                  selected: _benefit == b,
                                  onTap: () => setState(() => _benefit = b),
                                ),
                                const SizedBox(width: 8),
                              ],
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
                        ],
                        if (isRoute) ...[
                          const SizedBox(height: 24),
                          const AdminSectionLabel('Premio de la ruta'),
                          AppTextField(
                            controller: _labelController,
                            hint: 'Premio al completar (ej. Taza de regalo)',
                            icon: Icons.emoji_events_outlined,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Describe el premio' : null,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _stampsController,
                            hint: 'Sellos requeridos (por defecto, todos)',
                            icon: Icons.approval_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        AdminSectionLabel(isRoute ? 'Locales de la ruta' : 'Negocios participantes'),
                        if (businesses.isLoading)
                          const Center(child: CircularProgressIndicator(color: AppColors.black))
                        else if (active.isEmpty)
                          Text(
                            'Necesitas al menos un negocio activo para lanzar campañas.',
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
                                  }),
                                ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        const AdminSectionLabel('Cuándo'),
                        ScheduleRow(
                          title: 'Empieza',
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
                          title: 'Termina',
                          offLabel: 'Sin fin',
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
                          _scheduleStart
                              ? 'Avisaremos a tus clientes cuando llegue la hora de inicio.'
                              : 'Avisaremos a tus clientes en cuanto la lances.',
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
                  label: _scheduleStart ? 'Programar' : 'Lanzar campaña',
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

class _TypeOption extends StatelessWidget {
  final CampaignType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      excludeSemantics: true,
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.all(16),
        color: selected ? AppColors.pink : AppColors.white,
        onTap: onTap,
        child: Row(
          children: [
            Icon(type.icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: AppTypography.body(size: 17, weight: FontWeight.w500)),
                  Text(
                    type.description,
                    style: AppTypography.body(size: 13, weight: FontWeight.w300),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}

