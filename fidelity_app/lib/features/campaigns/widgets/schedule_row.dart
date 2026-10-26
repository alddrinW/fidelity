import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../admin/data/admin_date_filter.dart';
import '../../admin/widgets/admin_widgets.dart';

/// Fecha y hora con los selectores del sistema, en los colores de marca.
Future<DateTime?> pickCampaignDateTime(BuildContext context, DateTime? initial) async {
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
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
    builder: (_, child) => themed(child),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String formatCampaignDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatShortDate(d)} $hh:$mm';
}

/// Una fila de programación: título, dos opciones (p. ej. "Ahora" / "Programar")
/// y, si se eligió la segunda, la fecha elegida con su botón para cambiarla.
class ScheduleRow extends StatelessWidget {
  final String title;
  final String offLabel;
  final String onLabel;
  final bool isOn;
  final String? value;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPick;

  const ScheduleRow({
    super.key,
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
        // Wrap: en pantallas angostas la fecha baja a la siguiente línea en
        // vez de desbordarse.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminFilterPill(label: offLabel, selected: !isOn, onTap: () => onToggle(false)),
            AdminFilterPill(
              label: onLabel,
              icon: Icons.event_rounded,
              selected: isOn,
              onTap: () {
                onToggle(true);
                onPick();
              },
            ),
            if (isOn && value != null)
              GestureDetector(
                onTap: onPick,
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 15, weight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fecha y hora por separado, para que el dueño vea y cambie cada una: dos
/// opciones ("Ahora" / "Programar") y, al elegir la segunda, un botón de **fecha**
/// y otro de **hora**. Pregunta primero la fecha y luego la hora.
class ScheduleDateTimeRow extends StatelessWidget {
  final String title;

  /// Una línea que explica qué se está eligiendo.
  final String hint;
  final String offLabel;
  final String onLabel;
  final bool isOn;
  final DateTime? value;

  /// La hora que se propone al elegir la fecha.
  final TimeOfDay defaultTime;

  /// La fecha más temprana que se puede elegir (por defecto, hoy).
  final DateTime? firstDate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<DateTime> onChanged;

  const ScheduleDateTimeRow({
    super.key,
    required this.title,
    required this.hint,
    required this.offLabel,
    required this.onLabel,
    required this.isOn,
    required this.value,
    required this.defaultTime,
    required this.onToggle,
    required this.onChanged,
    this.firstDate,
  });

  Widget _themed(BuildContext context, Widget? child) => Theme(
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

  /// Elige el día; conserva la hora que ya había (o propone [defaultTime]).
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final earliest = DateTime((firstDate ?? now).year, (firstDate ?? now).month, (firstDate ?? now).day);
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      helpText: title,
      initialDate: initial.isBefore(earliest) ? earliest : initial,
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (_, child) => _themed(context, child),
    );
    if (date == null) return;
    final time = value == null ? defaultTime : TimeOfDay.fromDateTime(value!);
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  /// Elige la hora; si todavía no hay día, pide primero el día.
  Future<void> _pickTime(BuildContext context) async {
    if (value == null) {
      await _pickDate(context);
      return;
    }
    final time = await showTimePicker(
      context: context,
      helpText: title,
      initialTime: TimeOfDay.fromDateTime(value!),
      builder: (_, child) => _themed(context, child),
    );
    if (time == null) return;
    onChanged(DateTime(value!.year, value!.month, value!.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final date = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTypography.label(size: 12, tracking: 3)),
        const SizedBox(height: 2),
        Text(
          hint,
          style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminFilterPill(label: offLabel, selected: !isOn, onTap: () => onToggle(false)),
            AdminFilterPill(
              label: onLabel,
              icon: Icons.event_rounded,
              selected: isOn,
              onTap: () {
                onToggle(true);
                // Al elegir esta opción se pregunta enseguida el día.
                if (date == null) _pickDate(context);
              },
            ),
          ],
        ),
        if (isOn) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PartButton(
                icon: Icons.calendar_today_outlined,
                caption: 'Fecha',
                value: date == null ? 'Elegir' : formatShortDate(date),
                onTap: () => _pickDate(context),
              ),
              _PartButton(
                icon: Icons.access_time_rounded,
                caption: 'Hora',
                value: date == null ? 'Elegir' : _clock(date),
                onTap: () => _pickTime(context),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Un botón con su título chico ("FECHA", "HORA") y lo elegido grande.
class _PartButton extends StatelessWidget {
  final IconData icon;
  final String caption;
  final String value;
  final VoidCallback onTap;

  const _PartButton({required this.icon, required this.caption, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$caption: $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.black, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caption.toUpperCase(), style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary)),
                    Text(value, style: AppTypography.display(size: 20)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
