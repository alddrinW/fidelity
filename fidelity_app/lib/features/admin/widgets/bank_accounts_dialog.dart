import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/l10n/translator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../../payments/data/payments_repository.dart';

/// Las cuentas a las que los dueños transfieren o depositan el pago de su
/// registro. Las fija el administrador; sin ninguna, solo queda el pago con tarjeta.
Future<void> showBankAccountsDialog(BuildContext context, PaymentsRepository repository) async {
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
    builder: (_) => BankAccountsDialog(plan: plan, repository: repository),
  );
  if (saved == true && context.mounted) {
    DashboardAnimatedToast.show(context, 'Cuentas actualizadas');
  }
}

/// Máximo de cuentas que acepta el servidor.
const int kMaxBankAccounts = 5;

class _AccountFields {
  final bank = TextEditingController();
  final number = TextEditingController();
  final type = TextEditingController();
  final holder = TextEditingController();
  final taxId = TextEditingController();

  _AccountFields([BankAccount? a]) {
    bank.text = a?.bank ?? '';
    number.text = a?.accountNumber ?? '';
    type.text = a?.accountType ?? '';
    holder.text = a?.holder ?? '';
    taxId.text = a?.taxId ?? '';
  }

  BankAccount toAccount() => BankAccount(
        bank: bank.text.trim(),
        accountNumber: number.text.trim(),
        accountType: type.text.trim(),
        holder: holder.text.trim(),
        taxId: taxId.text.trim(),
      );

  void dispose() {
    for (final c in [bank, number, type, holder, taxId]) {
      c.dispose();
    }
  }
}

class BankAccountsDialog extends StatefulWidget {
  final PaymentPlan plan;
  final PaymentsRepository repository;

  const BankAccountsDialog({super.key, required this.plan, required this.repository});

  @override
  State<BankAccountsDialog> createState() => _BankAccountsDialogState();
}

class _BankAccountsDialogState extends State<BankAccountsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<_AccountFields> _rows = [
    for (final a in widget.plan.bankAccounts) _AccountFields(a),
  ];
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  static String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Campo obligatorio' : null;

  static String? _number(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Campo obligatorio';
    if (!RegExp(r'^[0-9-]{4,30}$').hasMatch(text)) return 'Entre 4 y 30 dígitos';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accounts = [for (final r in _rows) r.toAccount()];
    if (accounts.map((a) => a.accountNumber).toSet().length != accounts.length) {
      setState(() => _error = 'Hay dos cuentas con el mismo número');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.repository.updateBankAccounts(accounts);
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

  Widget _row(int index) {
    final r = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.black.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cuenta ${index + 1}', style: AppTypography.body(size: 15, weight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: context.tr('Quitar cuenta'),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                          _rows.removeAt(index).dispose();
                        }),
              ),
            ],
          ),
          AppTextField(
            controller: r.bank,
            hint: 'Banco',
            icon: Icons.account_balance_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: r.number,
            hint: 'Número de cuenta',
            icon: Icons.tag_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
            textInputAction: TextInputAction.next,
            validator: _number,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: r.type,
            hint: 'Tipo de cuenta (ahorros, corriente)',
            icon: Icons.savings_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: r.holder,
            hint: 'Titular',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: r.taxId,
            hint: 'Cédula o RUC del titular',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'CUENTAS BANCARIAS',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aquí transfieren o depositan los dueños el pago del registro. '
                  'Sin cuentas, solo queda el pago con tarjeta.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 15, weight: FontWeight.w300),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _rows.length; i++) _row(i),
                if (_rows.length < kMaxBankAccounts)
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => setState(() => _rows.add(_AccountFields())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar cuenta'),
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
