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
import '../admin/data/admin_date_filter.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/branches/branches_repository.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/campaigns_repository.dart';
import '../../core/l10n/tr_text.dart';

/// Crea una campaña: evento, tarjeta de regalo o ruta (pasaporte). Se puede
/// lanzar ya o programar para una fecha futura, con fin opcional.
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

  /// Fecha y hora con los selectores del sistema, en los colores de marca.
  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    Widget themed(Widget? child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.black,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.black,
            ),
          ),
          child: child!,
        );

    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (_, child) => themed(child),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
      builder: (_, child) => themed(child),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${formatShortDate(d)} $hh:$mm';
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

    setState(() => _isSaving = true);
    try {
      await ref.read(campaignsRepositoryProvider).create(
            type: _type,
            title: _titleController.text,
            description: _descriptionController.text,
            imageDataUri: _image?.dataUri,
            businessIds: _businessIds.toList(),
            benefitType: isGift ? _benefit : null,
            benefitValue: isGift && _benefit == CampaignBenefit.discountPercent
                ? int.tryParse(_valueController.text.trim())
                : null,
            benefitLabel: (isGift && _benefit == CampaignBenefit.miniPrize) || isRoute
                ? _labelController.text
                : null,
            requiredStamps: isRoute ? int.tryParse(_stampsController.text.trim()) : null,
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

    final isGift = _type == CampaignType.giftCard;
    final isRoute = _type == CampaignType.route;

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
                        for (final type in CampaignType.values) ...[
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
                        _ImagePicker(
                          image: _image,
                          onPick: _pickImage,
                          onRemove: () => setState(() => _image = null),
                        ),
                        if (isGift) ...[
                          const SizedBox(height: 24),
                          const AdminSectionLabel('Beneficio'),
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
                        _ScheduleRow(
                          title: 'Empieza',
                          offLabel: 'Ahora',
                          onLabel: 'Programar',
                          isOn: _scheduleStart,
                          value: _startsAt == null ? null : _formatDateTime(_startsAt!),
                          onToggle: (on) => setState(() {
                            _scheduleStart = on;
                            if (!on) _startsAt = null;
                          }),
                          onPick: () async {
                            final picked = await _pickDateTime(_startsAt);
                            if (picked != null) setState(() => _startsAt = picked);
                          },
                        ),
                        const SizedBox(height: 12),
                        _ScheduleRow(
                          title: 'Termina',
                          offLabel: 'Sin fin',
                          onLabel: 'Elegir fecha',
                          isOn: _hasEnd,
                          value: _endsAt == null ? null : _formatDateTime(_endsAt!),
                          onToggle: (on) => setState(() {
                            _hasEnd = on;
                            if (!on) _endsAt = null;
                          }),
                          onPick: () async {
                            final picked = await _pickDateTime(_endsAt ?? _startsAt);
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

class _ImagePicker extends StatelessWidget {
  final PickedImage? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePicker({required this.image, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.image_outlined),
        label: const Text('AGREGAR IMAGEN (OPCIONAL)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.black, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label(size: 13, tracking: 1.5),
        ),
      );
    }
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.memory(image!.bytes, height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        IconButton.filled(
          tooltip: 'Quitar imagen',
          style: IconButton.styleFrom(backgroundColor: AppColors.black),
          icon: const Icon(Icons.close_rounded, color: AppColors.white),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// Una fila de programación: título, dos opciones (p. ej. "Ahora" / "Programar")
/// y, si se eligió la segunda, la fecha elegida con su botón para cambiarla.
class _ScheduleRow extends StatelessWidget {
  final String title;
  final String offLabel;
  final String onLabel;
  final bool isOn;
  final String? value;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPick;

  const _ScheduleRow({
    required this.title,
    required this.offLabel,
    required this.onLabel,
    required this.isOn,
    required this.value,
    required this.onToggle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTypography.label(size: 12, tracking: 3)),
        const SizedBox(height: 8),
        Row(
          children: [
            AdminFilterPill(label: offLabel, selected: !isOn, onTap: () => onToggle(false)),
            const SizedBox(width: 8),
            AdminFilterPill(
              label: onLabel,
              icon: Icons.event_rounded,
              selected: isOn,
              onTap: () {
                onToggle(true);
                onPick();
              },
            ),
            if (isOn && value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: GestureDetector(
                  onTap: onPick,
                  child: Text(
                    value!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 15, weight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
