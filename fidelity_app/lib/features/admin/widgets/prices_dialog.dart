import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../../payments/data/payments_repository.dart';

/// El administrador fija lo que cuesta registrar un negocio y una sucursal.
/// Solo afecta a las órdenes de pago que se creen desde ese momento.
Future<void> showPricesDialog(BuildContext context, PaymentsRepository repository) async {
  PaymentPlan plan;
  try {
    plan = await repository.getPlan();
  } catch (e) {
    if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    return;
  }
  if (!context.mounted) return;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => PricesDialog(plan: plan, repository: repository),
  );
  if (saved == true && context.mounted) {
    DashboardAnimatedToast.show(context, 'Precios actualizados');
  }
}

class PricesDialog extends StatefulWidget {
  final PaymentPlan plan;
  final PaymentsRepository repository;

  const PricesDialog({super.key, required this.plan, required this.repository});

  @override
  State<PricesDialog> createState() => _PricesDialogState();
}

class _PricesDialogState extends State<PricesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _registration = TextEditingController(text: _format(widget.plan.registrationFee));
  late final _branch = TextEditingController(text: _format(widget.plan.branchFee));
  bool _isSaving = false;
  String? _error;

  static String _format(double v) => v.toStringAsFixed(2);

  @override
  void dispose() {
    _registration.dispose();
    _branch.dispose();
    super.dispose();
  }

  /// Acepta coma o punto decimal.
  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  static String? _validate(String? value) {
    final n = _parse(value ?? '');
    if (n == null) return 'Escribe un precio';
    if (n < 0.5) return 'El mínimo es 0.50';
    if (n > 10000) return 'El máximo es 10000';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.repository.updatePrices(
        registrationFee: double.parse(_parse(_registration.text)!.toStringAsFixed(2)),
        branchFee: double.parse(_parse(_branch.text)!.toStringAsFixed(2)),
      );
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
    const decimals = TextInputType.numberWithOptions(decimal: true);
    final formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'PRECIOS DEL REGISTRO',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lo que paga un dueño para activar su cuenta (${widget.plan.currency}). '
                'El cambio vale para los pagos nuevos; los ya emitidos conservan su monto.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 15, weight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _registration,
                hint: 'Registro de negocio',
                icon: Icons.storefront_outlined,
                keyboardType: decimals,
                inputFormatters: formatters,
                textInputAction: TextInputAction.next,
                validator: _validate,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _branch,
                hint: 'Alta de sucursal',
                icon: Icons.account_tree_outlined,
                keyboardType: decimals,
                inputFormatters: formatters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
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
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}
