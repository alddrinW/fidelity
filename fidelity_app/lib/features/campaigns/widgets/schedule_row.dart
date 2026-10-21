import 'package:flutter/material.dart';

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
