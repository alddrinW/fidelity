import 'package:flutter/material.dart' hide Text;

import '../l10n/translator.dart';
import '../theme/app_colors.dart';
import 'app_text_field.dart';

/// Conversión de la fecha de nacimiento entre la app y el servidor.
class BirthDate {
  const BirthDate._();

  /// "14/03/1998", como se muestra.
  static String format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// "1998-03-14", como la guarda el servidor.
  static String toApi(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Lee "1998-03-14" (o una fecha ISO completa); null si no hay o no sirve.
  static DateTime? parse(String? value) {
    if (value == null || value.length < 10) return null;
    final parsed = DateTime.tryParse(value.substring(0, 10));
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }
}

/// Campo para elegir la fecha de nacimiento con el calendario. Es opcional:
/// se puede quitar con la "x". Solo se muestra a los clientes.
class BirthDateField extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hint;
  final String? helperText;

  const BirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Fecha de nacimiento (opcional)',
    this.helperText = 'Tu local podrá saludarte y regalarte algo en tu cumpleaños.',
  });

  @override
  State<BirthDateField> createState() => _BirthDateFieldState();
}

class _BirthDateFieldState extends State<BirthDateField> {
  late final TextEditingController _controller = TextEditingController(text: _text(widget.value));

  static String _text(DateTime? date) => date == null ? '' : BirthDate.format(date);

  @override
  void didUpdateWidget(covariant BirthDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El valor puede cambiar desde fuera (p. ej. al terminar de cargar el perfil).
    if (oldWidget.value != widget.value && _controller.text != _text(widget.value)) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: context.tr('Fecha de nacimiento'),
      cancelText: context.tr('Cancelar'),
      confirmText: context.tr('Aceptar'),
    );
    if (picked != null) widget.onChanged(DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      hint: widget.hint,
      icon: Icons.cake_outlined,
      helperText: widget.helperText,
      readOnly: true,
      onTap: _pick,
      trailing: widget.value == null
          ? const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.textSecondary)
          : GestureDetector(
              onTap: () => widget.onChanged(null),
              child: Tooltip(
                message: context.tr('Quitar fecha'),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
              ),
            ),
    );
  }
}
