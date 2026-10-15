import 'package:flutter/material.dart' hide Text;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../data/admin_date_filter.dart';
import '../../../core/l10n/tr_text.dart';

/// Ancho máximo del contenido del panel: más generoso que el móvil para
/// aprovechar las pantallas anchas de escritorio.
const double kAdminMaxWidth = 720;

/// Marco común de las pantallas del panel: cabecera de marca, contenido
/// centrado y un botón fijo opcional al pie (p. ej. "Exportar").
class AdminPageFrame extends StatelessWidget {
  final String title;
  final Widget? headerTrailing;
  final Widget body;
  final Widget? bottom;

  const AdminPageFrame({
    super.key,
    required this.title,
    required this.body,
    this.headerTrailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          maxWidth: kAdminMaxWidth,
          child: Column(
            children: [
              AppPageHeader(title: title, trailing: headerTrailing),
              Expanded(child: body),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo de sección en Anek Latin espaciado, como en las demás pantallas.
class AdminSectionLabel extends StatelessWidget {
  final String text;

  const AdminSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(text.toUpperCase(), style: AppTypography.label(size: 13, tracking: 5)),
    );
  }
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 3),
    );
  }
}

/// Campo de búsqueda en píldora.
class AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: AppColors.black,
      style: AppTypography.body(size: 16, weight: FontWeight.w300),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(start: 20, end: 12),
          child: Icon(Icons.search_rounded, size: 24),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

/// Píldora de filtro: negra si está activa, con contorno si no.
class AdminFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const AdminFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.white : AppColors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.black : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.black, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: AppTypography.label(size: 12, tracking: 2, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila desplazable de píldoras con los periodos de [AdminDateFilter]. Al
/// elegir "Personalizado" abre el selector de rango y avisa con el rango
/// elegido; si el usuario cancela, no cambia nada.
class AdminDateFilterBar extends StatelessWidget {
  final AdminDateFilter selected;
  final DateTimeRange? customRange;
  final bool includeAll;
  final void Function(AdminDateFilter filter, DateTimeRange? customRange) onChanged;

  const AdminDateFilterBar({
    super.key,
    required this.selected,
    required this.customRange,
    required this.onChanged,
    this.includeAll = true,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final now = EcuadorDateUtils.nowEcuador();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      initialDateRange:
          customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.black,
            onPrimary: AppColors.white,
            surface: AppColors.white,
            onSurface: AppColors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(AdminDateFilter.custom, picked);
  }

  @override
  Widget build(BuildContext context) {
    final filters = AdminDateFilter.values
        .where((f) => includeAll || f != AdminDateFilter.all)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              return AdminFilterPill(
                label: filter.label,
                selected: selected == filter,
                icon: filter == AdminDateFilter.custom ? Icons.date_range_rounded : null,
                onTap: filter == AdminDateFilter.custom
                    ? () => _pickCustom(context)
                    : () => onChanged(filter, customRange),
              );
            },
          ),
        ),
        if (selected == AdminDateFilter.custom && customRange != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 24, 0),
            child: Text(
              '${formatShortDate(customRange!.start)} - ${formatShortDate(customRange!.end)}',
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón de exportar fijo al pie: píldora negra con icono de descarga.
class AdminExportButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AdminExportButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.download_rounded),
        label: Text(
          'EXPORTAR',
          style: AppTypography.label(size: 16, tracking: 6, color: AppColors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.black,
          disabledForegroundColor: AppColors.white,
        ),
      ),
    );
  }
}

/// Selector en píldora que abre una hoja con las opciones (p. ej. el local).
/// [options] son pares (valor, etiqueta).
class AdminSelectField extends StatelessWidget {
  final IconData icon;
  final String title;
  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const AdminSelectField({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      constraints: const BoxConstraints(maxWidth: kAdminMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(title.toUpperCase(), style: AppTypography.display(size: 28)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: options.length,
                  itemBuilder: (_, index) {
                    final (value, label) = options[index];
                    final isSelected = value == selected;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 17,
                          weight: isSelected ? FontWeight.w500 : FontWeight.w300,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: AppColors.black)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != selected) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = options
        .firstWhere((o) => o.$1 == selected, orElse: () => options.first)
        .$2;

    return Semantics(
      button: true,
      label: '$title: $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border, width: 1.2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 17, weight: FontWeight.w300),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contador de resultados ("12 negocios") bajo los filtros.
class AdminCountLabel extends StatelessWidget {
  final String text;

  const AdminCountLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 24, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label(size: 12, tracking: 3, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Línea de información con icono (correo, teléfono, local...).
class AdminInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;

  const AdminInfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 14,
                weight: strong ? FontWeight.w500 : FontWeight.w300,
                color: strong ? AppColors.black : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
