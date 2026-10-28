import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_text_field.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/settings_repository.dart';
import 'widgets/admin_widgets.dart';

/// Ajustes del sistema: el administrador fija aquí los precios, las reglas de
/// los minijuegos, los límites de los negocios y cuánto tiempo se guardan los
/// registros viejos. Lo que no cambia se queda en su valor por defecto.
///
/// Para no abrumar, cada grupo se abre y se cierra; las descripciones largas se
/// muestran en dos líneas ("Ver más") y lo que es encender o apagar es un interruptor.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, AppSettingItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SettingEditDialog(item: item, repository: ref.read(settingsRepositoryProvider)),
    );
    if (saved == true) {
      ref.invalidate(appSettingsProvider);
      if (context.mounted) DashboardAnimatedToast.show(context, 'Ajuste guardado');
    }
  }

  /// Encender o apagar: se guarda al instante.
  Future<void> _toggle(BuildContext context, WidgetRef ref, AppSettingItem item, bool on) async {
    try {
      await ref.read(settingsRepositoryProvider).save(item.key, on ? 1 : 0);
      ref.invalidate(appSettingsProvider);
      if (context.mounted) DashboardAnimatedToast.show(context, 'Ajuste guardado');
    } catch (e) {
      if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final data = settings.valueOrNull;

    return AdminPageFrame(
      title: 'Ajustes',
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async => ref.invalidate(appSettingsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (data == null && settings.isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState.error(message: 'No pudimos cargar los ajustes. Desliza para reintentar.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final group in data.groups)
                      _SettingGroupSection(
                        group: group,
                        items: data.itemsOf(group.id),
                        onEdit: (item) => _edit(context, ref, item),
                        onToggle: (item, on) => _toggle(context, ref, item, on),
                      ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un grupo de ajustes (Precios, Minijuegos...) que se abre y se cierra. Cerrado muestra
/// cuántos ajustes tiene y cuántos cambió el administrador.
class _SettingGroupSection extends StatefulWidget {
  final AppSettingGroup group;
  final List<AppSettingItem> items;
  final ValueChanged<AppSettingItem> onEdit;
  final void Function(AppSettingItem item, bool on) onToggle;

  const _SettingGroupSection({
    required this.group,
    required this.items,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  State<_SettingGroupSection> createState() => _SettingGroupSectionState();
}

class _SettingGroupSectionState extends State<_SettingGroupSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final custom = widget.items.where((i) => i.isCustom).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: group.label,
            child: AppCard(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
              color: _open ? AppColors.surfaceMuted : AppColors.white,
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.label.toUpperCase(), style: AppTypography.display(size: 22)),
                        if (group.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            group.description,
                            maxLines: _open ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Cuántos ajustes tiene y cuántos se cambiaron (debajo, para que quepa en celulares angostos).
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${widget.items.length} ${context.tr(widget.items.length == 1 ? 'ajuste' : 'ajustes').toLowerCase()}',
                              style: AppTypography.label(size: 11, tracking: 1.5, color: AppColors.textSecondary),
                            ),
                            if (custom > 0)
                              AppChip(
                                label: '$custom ${context.tr(custom == 1 ? 'personalizado' : 'personalizados').toLowerCase()}',
                                style: AppChipStyle.pink,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 28),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        for (final item in widget.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SettingCard(
                              item: item,
                              onTap: () => widget.onEdit(item),
                              onToggle: (on) => widget.onToggle(item, on),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Un ajuste: su nombre, una descripción corta (con "Ver más") y a la derecha su valor,
/// o un interruptor si es encender/apagar.
class _SettingCard extends StatelessWidget {
  final AppSettingItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _SettingCard({required this.item, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: item.isSwitch ? () => onToggle(item.value.round() != 1) : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTypography.body(size: 16, weight: FontWeight.w600)),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ExpandableText(
                    item.description,
                    style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (item.isSwitch)
            Semantics(
              label: item.label,
              child: Switch(
                value: item.value.round() == 1,
                activeTrackColor: AppColors.black,
                onChanged: onToggle,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: _ValueBlock(item: item),
            ),
        ],
      ),
    );
  }
}

/// El valor de un ajuste: el número grande y, debajo, su unidad en chico.
class _ValueBlock extends StatelessWidget {
  final AppSettingItem item;

  const _ValueBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final option = item.optionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (option != null)
          // Una opción ("Al primer escaneo"): se muestra con palabras, no como "1".
          Text(
            option[0].toUpperCase() + option.substring(1),
            textAlign: TextAlign.end,
            style: AppTypography.body(size: 14, weight: FontWeight.w600),
          )
        else ...[
          Text(item.format(item.value), style: AppTypography.display(size: 24)),
          if (item.unit.isNotEmpty)
            Text(
              item.unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 12, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
        ],
        if (item.isCustom) ...[
          const SizedBox(height: 6),
          const AppChip(label: 'Personalizado', style: AppChipStyle.pink),
        ],
      ],
    );
  }
}

/// Un texto largo en pocas líneas, con "Ver más" / "Ver menos" si no cabe.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const ExpandableText(this.text, {super.key, required this.style, this.maxLines = 2});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final translated = context.tr(widget.text);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: translated, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: widget.style,
            ),
            if (overflows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    _expanded ? 'Ver menos' : 'Ver más',
                    style: AppTypography.body(size: 13, weight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cambiar un ajuste: escribe el valor nuevo o vuelve al valor por defecto.
class SettingEditDialog extends StatefulWidget {
  final AppSettingItem item;
  final SettingsRepository repository;

  const SettingEditDialog({super.key, required this.item, required this.repository});

  @override
  State<SettingEditDialog> createState() => _SettingEditDialogState();
}

class _SettingEditDialogState extends State<SettingEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.item.format(widget.item.value));
  bool _isSaving = false;
  String? _error;

  AppSettingItem get _item => widget.item;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Acepta coma o punto decimal.
  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validate(String? value) {
    final n = _parse(value ?? '');
    if (n == null) return 'Escribe un número';
    if (!_item.isMoney && n != n.roundToDouble()) return 'Debe ser un número entero';
    if (n < _item.min || n > _item.max) {
      return 'Debe estar entre ${_item.format(_item.min)} y ${_item.format(_item.max)}';
    }
    return null;
  }

  Future<void> _save({required bool reset}) async {
    if (!reset && !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.repository.save(_item.key, reset ? null : _parse(_controller.text));
      if (mounted) Navigator.of(context).pop(true);
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
    final decimals = TextInputType.numberWithOptions(decimal: _item.isMoney);
    final formatters = [
      FilteringTextInputFormatter.allow(RegExp(_item.isMoney ? r'[0-9.,]' : r'[0-9]')),
    ];

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        _item.label.toUpperCase(),
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 24),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _item.description,
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 15, weight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _controller,
                hint: _item.unit.isEmpty ? _item.label : _item.unit,
                icon: Icons.tune_rounded,
                keyboardType: decimals,
                inputFormatters: formatters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(reset: false),
                helperText: _item.options.isNotEmpty
                    ? _item.unit
                    : 'Por defecto: ${_item.format(_item.defaultValue)} · de ${_item.format(_item.min)} a ${_item.format(_item.max)}',
                validator: _validate,
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (_item.isCustom)
          TextButton(
            onPressed: _isSaving ? null : () => _save(reset: true),
            child: const Text('Restablecer'),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _save(reset: false),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}
