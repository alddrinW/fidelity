import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
                    for (final group in data.groups) ...[
                      const SizedBox(height: 12),
                      AdminSectionLabel(group.label),
                      if (group.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          child: Text(
                            group.description,
                            style: AppTypography.body(size: 14, weight: FontWeight.w300),
                          ),
                        ),
                      for (final (i, item) in data.itemsOf(group.id).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SettingCard(item: item, onTap: () => _edit(context, ref, item))
                              .animate(delay: (40 * (i % 8)).ms)
                              .fadeIn()
                              .slideY(begin: 0.06),
                        ),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final AppSettingItem item;
  final VoidCallback onTap;

  const _SettingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTypography.body(size: 17, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: AppTypography.body(size: 14, weight: FontWeight.w300),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.unit.isEmpty ? item.format(item.value) : '${item.format(item.value)} ${context.tr(item.unit)}',
                style: AppTypography.display(size: 22),
              ),
              if (item.isCustom) ...[
                const SizedBox(height: 6),
                const AppChip(label: 'Personalizado', style: AppChipStyle.pink),
              ],
            ],
          ),
        ],
      ),
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
                helperText:
                    'Por defecto: ${_item.format(_item.defaultValue)} · de ${_item.format(_item.min)} a ${_item.format(_item.max)}',
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
