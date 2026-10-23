import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/person_avatar.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/widgets/gift_card_voucher.dart';
import 'data/birthdays_repository.dart';

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// "Hoy", "Mañana" o "En 3 días".
String birthdayWhen(int daysUntil) {
  if (daysUntil == 0) return 'Hoy';
  if (daysUntil == 1) return 'Mañana';
  return 'En $daysUntil días';
}

/// "Cumple el 22 de Octubre": solo día y mes, nunca la edad.
String birthdayDate(BirthdayItem item) => 'Cumple el ${item.day} de ${_months[item.month - 1]}';

/// "HH:mm" como lo pide el servidor.
String clockText(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// La plantilla de cumpleaños de las gift cards: el diseño y el texto ya vienen
/// puestos. El dueño solo elige el **premio**, **a quién** se la da y **la
/// hora**: la gift card vale únicamente el día del cumpleaños de cada cliente.
class BirthdayGiftScreen extends ConsumerStatefulWidget {
  /// Cliente que ya sale marcado (al venir de la lista de cumpleaños).
  final String? initialUserId;
  final String? initialBusinessId;

  const BirthdayGiftScreen(
      {super.key, this.initialUserId, this.initialBusinessId});

  @override
  ConsumerState<BirthdayGiftScreen> createState() => _BirthdayGiftScreenState();
}

class _BirthdayGiftScreenState extends ConsumerState<BirthdayGiftScreen> {
  final _formKey = GlobalKey<FormState>();
  final _percent = TextEditingController(text: '15');
  final _prize = TextEditingController();

  bool _discount = true;

  /// Desde qué hora vale ese día, y hasta cuál (null = todo el día).
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _until;

  /// Los elegidos, como "negocio|cliente".
  late final Set<String> _selected = {
    if (widget.initialUserId != null && widget.initialBusinessId != null)
      '${widget.initialBusinessId}|${widget.initialUserId}',
  };

  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_percent, _prize]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _percent.dispose();
    _prize.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  static String _key(BirthdayItem item) => '${item.businessId}|${item.userId}';

  static String? _validatePercent(String? value) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null) return 'Escribe un porcentaje';
    if (n < 1 || n > 100) return 'Entre 1 y 100';
    return null;
  }

  static String? _validatePrize(String? value) =>
      (value ?? '').trim().isEmpty ? 'Describe el premio' : null;

  Future<void> _pickFrom() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _from,
      helpText: context.tr('Desde qué hora'),
      cancelText: context.tr('Cancelar'),
      confirmText: context.tr('Aceptar'),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickUntil() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _until ?? const TimeOfDay(hour: 22, minute: 0),
      helpText: context.tr('Hasta qué hora'),
      cancelText: context.tr('Cancelar'),
      confirmText: context.tr('Aceptar'),
    );
    if (picked != null) setState(() => _until = picked);
  }

  /// Los que se pueden regalar: los que aún no tienen su regalo de este año.
  List<BirthdayItem> _giftable(BirthdayList list) =>
      list.items.where((i) => !i.gifted).toList();

  Future<void> _send(List<BirthdayItem> items) async {
    if (!_formKey.currentState!.validate()) return;
    final chosen = [
      for (final i in items)
        if (_selected.contains(_key(i))) i
    ];
    if (chosen.isEmpty) return;

    final until = _until;
    if (until != null && clockText(until).compareTo(clockText(_from)) <= 0) {
      setState(
          () => _error = 'La hora de fin debe ser después de la de inicio');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    final repository = ref.read(birthdaysRepositoryProvider);
    final failures = <String>[];
    final failedKeys = <String>{};
    var sent = 0;
    for (final item in chosen) {
      try {
        await repository.gift(
          businessId: item.businessId,
          userId: item.userId,
          discountPercent: _discount ? int.parse(_percent.text.trim()) : null,
          prizeLabel: _discount ? null : _prize.text,
          startTime: clockText(_from),
          endTime: until == null ? null : clockText(until),
        );
        sent++;
      } catch (e) {
        failures.add('${item.name}: $e');
        failedKeys.add(_key(item));
      }
    }

    ref.invalidate(birthdaysProvider);
    ref.invalidate(myCampaignsProvider);
    if (!mounted) return;

    if (failures.isEmpty) {
      DashboardAnimatedToast.show(
        context,
        sent == 1
            ? 'Gift card de cumpleaños lista'
            : '$sent gift cards de cumpleaños listas',
      );
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSending = false;
      _error = failures.join('\n');
      // Quedan marcados solo los que fallaron, para reintentar.
      _selected.retainAll(failedKeys);
    });
    if (sent > 0) {
      DashboardAnimatedToast.show(
          context, '$sent gift cards de cumpleaños listas');
    }
  }

  /// El cheque tal como lo recibirá el cliente (con el primer elegido de ejemplo).
  Campaign _preview(List<BirthdayItem> chosen) {
    final first = chosen.firstOrNull;
    final name =
        first == null ? 'Ana' : first.name.trim().split(RegExp(r'\s+')).first;
    final business = first?.businessName ?? 'Tu local';
    final now = DateTime.now();
    final day = first == null ? now : now.add(Duration(days: first.daysUntil));
    final value = int.tryParse(_percent.text.trim());
    final label = _prize.text.trim();

    return Campaign(
      id: 'preview',
      type: CampaignType.giftCard,
      template: 'birthday',
      title: 'Feliz cumpleaños, $name',
      description:
          'Un regalo de $business por tu cumpleaños. Vale solo ese día.',
      phase: CampaignPhase.active,
      benefitType: _discount
          ? CampaignBenefit.discountPercent
          : CampaignBenefit.miniPrize,
      benefitValue: _discount ? value : null,
      benefitLabel:
          _discount ? null : (label.isEmpty ? 'Un premio sorpresa' : label),
      businesses: [CampaignBusinessRef(id: 'b', name: business)],
      endsAt: DateTime(day.year, day.month, day.day, 23, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthdays = ref.watch(birthdaysProvider);
    final list = birthdays.valueOrNull;
    final items = list == null ? const <BirthdayItem>[] : _giftable(list);
    final chosen = [
      for (final i in items)
        if (_selected.contains(_key(i))) i
    ];
    final multipleBusinesses =
        items.map((i) => i.businessId).toSet().length > 1;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Gift card de cumpleaños'),
              Expanded(
                child: birthdays.isLoading && list == null
                    ? const AdminLoading()
                    : Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          children: [
                            GiftCardVoucher(
                              campaign: _preview(chosen),
                              businessName: chosen.firstOrNull?.businessName,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'El diseño y el texto ya vienen listos. Tú eliges el premio, a quién y la hora.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                size: 14,
                                weight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const AdminSectionLabel('Premio'),
                            _prizeSection(),
                            const SizedBox(height: 24),
                            const AdminSectionLabel('A quién'),
                            _recipients(items, multipleBusinesses),
                            const SizedBox(height: 24),
                            const AdminSectionLabel('Hora'),
                            _hours(),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                    size: 14, color: AppColors.error),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AppPrimaryButton(
                  label: chosen.length > 1
                      ? 'Enviar ${chosen.length} regalos'
                      : 'Enviar regalo',
                  isLoading: _isSending,
                  onPressed: chosen.isEmpty ? null : () => _send(items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AdminFilterPill(
              label: 'Descuento',
              selected: _discount,
              onTap: () => setState(() => _discount = true),
            ),
            AdminFilterPill(
              label: 'Mini premio',
              selected: !_discount,
              onTap: () => setState(() => _discount = false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_discount)
          AppTextField(
            controller: _percent,
            hint: 'Porcentaje de descuento',
            icon: Icons.percent_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: _validatePercent,
          )
        else
          AppTextField(
            controller: _prize,
            hint: 'Ej.: un postre gratis',
            icon: Icons.card_giftcard_rounded,
            textCapitalization: TextCapitalization.sentences,
            validator: _validatePrize,
          ),
      ],
    );
  }

  Widget _recipients(List<BirthdayItem> items, bool showBusiness) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 220,
        child: AppEmptyState(
          title: 'Nadie por ahora',
          message:
              'Aquí aparecen los clientes que cumplen años hoy o pronto y todavía no tienen su regalo.',
          imageHeight: 100,
        ),
      );
    }
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              color: _selected.contains(_key(item)) ? AppColors.pink : null,
              onTap: () => setState(() {
                if (!_selected.add(_key(item))) _selected.remove(_key(item));
              }),
              child: Row(
                children: [
                  PersonAvatar(
                      name: item.name, avatarUrl: item.avatarUrl, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 16, weight: FontWeight.w600),
                        ),
                        Text(
                          '${context.tr(birthdayDate(item))} · ${context.tr(birthdayWhen(item.daysUntil))}',
                          style: AppTypography.body(
                              size: 13, weight: FontWeight.w300),
                        ),
                        if (showBusiness && item.businessName != null)
                          Text(
                            item.businessName!,
                            style: AppTypography.body(
                              size: 12,
                              weight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: _selected.contains(_key(item)),
                    activeColor: AppColors.black,
                    shape: const CircleBorder(),
                    onChanged: (_) => setState(() {
                      if (!_selected.add(_key(item))) {
                        _selected.remove(_key(item));
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _hours() {
    final until = _until;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vale solo el día del cumpleaños de cada cliente, entre estas horas.',
          style: AppTypography.body(size: 14, weight: FontWeight.w300),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HourButton(
                  label: 'Desde',
                  value: clockText(_from),
                  onTap: _pickFrom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HourButton(
                  label: 'Hasta',
                  value: until == null
                      ? context.tr('Todo el día')
                      : clockText(until),
                  onTap: _pickUntil,
                  onClear: until == null
                      ? null
                      : () => setState(() => _until = null),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un selector de hora: su nombre y la hora elegida.
class _HourButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _HourButton(
      {required this.label,
      required this.value,
      required this.onTap,
      this.onClear});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.label(
                      size: 10, tracking: 2, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                // Una sola línea: si no cabe (p. ej. "Todo el día"), la letra se achica.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1, style: AppTypography.display(size: 22)),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: context.tr('Todo el día'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClear,
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.schedule_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
