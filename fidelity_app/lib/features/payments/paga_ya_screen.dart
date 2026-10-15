import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/fido_says.dart';
import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import 'data/payments_repository.dart';

/// Asistente "PAGA YA", guiado por Fido, en tres pasos:
/// 1) resumen del plan y costo, 2) elegir cómo pagar (transferencia bancaria
/// con los datos de la cuenta, o tarjeta en la pasarela de pago), 3) confirmar:
/// subir el comprobante de la transferencia o avisar que ya se pagó con tarjeta.
///
/// Cierra con `true` si el pago quedó reportado.
class PagaYaScreen extends ConsumerStatefulWidget {
  final PaymentOrder order;

  const PagaYaScreen({super.key, required this.order});

  @override
  ConsumerState<PagaYaScreen> createState() => _PagaYaScreenState();
}

class _PagaYaScreenState extends ConsumerState<PagaYaScreen> {
  static const _lastStep = 2;

  final _noteController = TextEditingController();
  int _step = 0;
  bool _isSending = false;
  PaymentMethod? _method;
  PickedImage? _proof;

  PaymentOrder get _order => widget.order;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickProof() async {
    try {
      final picked = await pickImageFromGallery(maxSide: 1280);
      if (picked != null && mounted) setState(() => _proof = picked);
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _openCardGateway(PaymentPlan plan) async {
    final uri = plan.cardPaymentUri(_order);
    if (uri == null) {
      _showError('El pago con tarjeta no está disponible por ahora.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showError('No se pudo abrir la pasarela de pago.');
  }

  /// La transferencia se valida con la foto del comprobante.
  String? _validateReport() {
    final method = _method;
    if (method == null) return 'Elige cómo quieres pagar.';
    if (method == PaymentMethod.transfer && _proof == null) {
      return 'Adjunta la foto del comprobante.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validateReport();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref.read(paymentsRepositoryProvider).report(
            _order.id,
            method: _method!,
            note: _noteController.text,
            proofDataUri: _proof?.dataUri,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppMessageDialog(
          icon: Icons.hourglass_top_rounded,
          title: 'Pago reportado',
          message: 'Lo validaremos lo antes posible y te avisaremos por '
              'notificación cuando tu cuenta esté activa.',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(paymentPlanProvider);
    final methods = plan.valueOrNull?.availableMethods ?? const <PaymentMethod>[];

    // Si el método elegido dejó de estar disponible, se descarta.
    if (_method != null && plan.hasValue && !methods.contains(_method)) _method = null;

    final canAdvance = _step != 1 || (_method != null && methods.isNotEmpty);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(title: 'Paga ya', onBack: _back),
              _StepDots(current: _step, total: _lastStep + 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: switch (_step) {
                      0 => _PlanStep(order: _order),
                      1 => plan.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.black),
                            ),
                          ),
                          error: (e, _) => const FidoSays(
                            message: 'No pudimos cargar los métodos de pago. '
                                'Vuelve atrás e inténtalo de nuevo.',
                          ),
                          data: (plan) => _MethodStep(
                            order: _order,
                            plan: plan,
                            method: _method,
                            onMethod: (m) => setState(() => _method = m),
                            onCopy: _copy,
                          ),
                        ),
                      _ => _ConfirmStep(
                          method: _method ?? PaymentMethod.transfer,
                          noteController: _noteController,
                          proof: _proof,
                          onPickProof: _pickProof,
                          onRemoveProof: () => setState(() => _proof = null),
                          onOpenGateway: plan.hasValue ? () => _openCardGateway(plan.value!) : null,
                        ),
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 32, 32),
                  child: _step < _lastStep
                      ? AppCircleButton(
                          tooltip: 'Siguiente paso',
                          onPressed: canAdvance ? () => setState(() => _step++) : null,
                        )
                      : SizedBox(
                          width: 280,
                          child: AppPrimaryButton(
                            label: _method == PaymentMethod.card ? 'Ya pagué' : 'Enviar comprobante',
                            isLoading: _isSending,
                            onPressed: _submit,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;

  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${current + 1} de $total',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.black : AppColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.black, width: 1.2),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  final PaymentOrder order;

  const _PlanStep({required this.order});

  static const _features = [
    'Tarjetas de fidelidad para tus clientes',
    'Código QR de tu local para escanear',
    'Panel para aprobar escaneos y entregar premios',
    'Estadísticas, clientes y campañas',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step-plan'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FidoSays(message: '¡Hola! Te guío en 3 pasos para activar tu negocio.'),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.conceptLabel.toUpperCase(),
                style: AppTypography.label(size: 12, tracking: 4),
              ),
              const SizedBox(height: 8),
              Text(order.amountLabel, style: AppTypography.display(size: 48)),
              Text(
                'Pago único para activar ${order.businessName}',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.black),
              const SizedBox(height: 16),
              for (final feature in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: AppTypography.body(size: 15, weight: FontWeight.w300),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paso 2: elegir el método y ver cómo pagar con él.
class _MethodStep extends StatelessWidget {
  final PaymentOrder order;
  final PaymentPlan plan;
  final PaymentMethod? method;
  final ValueChanged<PaymentMethod> onMethod;
  final Future<void> Function(String text, String message) onCopy;

  const _MethodStep({
    required this.order,
    required this.plan,
    required this.method,
    required this.onMethod,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final methods = plan.availableMethods;

    if (methods.isEmpty) {
      return const Column(
        key: ValueKey('step-method'),
        children: [
          FidoSays(
            message: 'Los métodos de pago aún no están disponibles. '
                'Inténtalo más tarde.',
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('step-method'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FidoSays(message: 'Elige cómo quieres pagar.'),
        const SizedBox(height: 24),
        Row(
          children: [
            for (var i = 0; i < methods.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _MethodOption(
                  method: methods[i],
                  selected: method == methods[i],
                  onTap: () => onMethod(methods[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (method == PaymentMethod.transfer && plan.bankAccounts.isNotEmpty)
          _TransferDetails(order: order, banks: plan.bankAccounts, onCopy: onCopy)
        else if (method == PaymentMethod.card)
          _CardSteps(order: order),
      ],
    );
  }
}

class _MethodOption extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodOption({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      excludeSemantics: true,
      child: AppCard(
        radius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        color: selected ? AppColors.pink : AppColors.white,
        onTap: onTap,
        child: Column(
          children: [
            Icon(method.icon, size: 34),
            const SizedBox(height: 10),
            Text(
              method.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.label(size: 12, tracking: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuentas para transferir (una tarjeta por banco), con botones para copiar
/// cada dato. El dueño elige a cuál transferir.
class _TransferDetails extends StatelessWidget {
  final PaymentOrder order;
  final List<BankAccount> banks;
  final Future<void> Function(String text, String message) onCopy;

  const _TransferDetails({required this.order, required this.banks, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          banks.length > 1
              ? 'TRANSFIERE O DEPOSITA A UNA DE ESTAS CUENTAS'
              : 'TRANSFIERE O DEPOSITA A ESTA CUENTA',
          textAlign: TextAlign.center,
          style: AppTypography.display(size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          'Realiza el pago por ${order.amountLabel} y escribe tu referencia como concepto.',
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 14, weight: FontWeight.w300),
        ),
        const SizedBox(height: 16),
        for (final bank in banks) ...[
          _BankCard(bank: bank, onCopy: onCopy),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(
            children: [
              _DataRow(label: 'Monto', value: order.amountLabel),
              _DataRow(
                label: 'Referencia',
                value: order.reference,
                onCopy: () => onCopy(order.reference, 'Referencia copiada'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Cuando termines, toca siguiente para subir la foto de tu comprobante.',
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 14,
            weight: FontWeight.w300,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BankCard extends StatelessWidget {
  final BankAccount bank;
  final Future<void> Function(String text, String message) onCopy;

  const _BankCard({required this.bank, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bank.bank != null)
            Text(bank.bank!.toUpperCase(), style: AppTypography.label(size: 13, tracking: 3)),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  bank.accountNumber,
                  style: AppTypography.display(size: 34),
                ),
              ),
              _CopyButton(
                tooltip: 'Copiar número de cuenta',
                onPressed: () => onCopy(bank.accountNumber, 'Número de cuenta copiado'),
              ),
            ],
          ),
          if (bank.accountType != null) _DataRow(label: 'Tipo', value: bank.accountType!),
          if (bank.holder != null)
            _DataRow(
              label: 'Beneficiario',
              value: bank.holder!,
              onCopy: () => onCopy(bank.holder!, 'Beneficiario copiado'),
            ),
          if (bank.taxId != null)
            _DataRow(
              label: 'CI/RUC',
              value: bank.taxId!,
              onCopy: () => onCopy(bank.taxId!, 'CI/RUC copiado'),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DataRow({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: AppTypography.label(size: 11, tracking: 2, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTypography.body(size: 15, weight: FontWeight.w500),
            ),
          ),
          if (onCopy != null) _CopyButton(tooltip: 'Copiar', onPressed: onCopy!),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _CopyButton({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr(tooltip),
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.copy_rounded, size: 20),
      onPressed: onPressed,
    );
  }
}

/// Pasos del pago con tarjeta (se paga en la pasarela del proveedor).
class _CardSteps extends StatelessWidget {
  final PaymentOrder order;

  const _CardSteps({required this.order});

  static const _steps = [
    'Toca el botón siguiente.',
    'Te llevaremos a la pasarela de pago 100% segura.',
    'Ingresa los datos de tu tarjeta de crédito o débito.',
    'Vuelve aquí y confirma tu pago.',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARJETA DÉBITO/CRÉDITO', style: AppTypography.display(size: 24)),
          const SizedBox(height: 4),
          Text(
            'Pagas ${order.amountLabel} (ref. ${order.reference}).',
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          const SizedBox(height: 12),
          Text(
            'Pasos rápidos para pagar:',
            style: AppTypography.body(size: 15, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: AppTypography.label(size: 12, tracking: 0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: AppTypography.body(size: 15, weight: FontWeight.w300),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Paso 3: subir el comprobante (transferencia) o confirmar el pago con tarjeta.
class _ConfirmStep extends StatelessWidget {
  final PaymentMethod method;
  final TextEditingController noteController;
  final PickedImage? proof;
  final VoidCallback onPickProof;
  final VoidCallback onRemoveProof;
  final VoidCallback? onOpenGateway;

  const _ConfirmStep({
    required this.method,
    required this.noteController,
    required this.proof,
    required this.onPickProof,
    required this.onRemoveProof,
    required this.onOpenGateway,
  });

  @override
  Widget build(BuildContext context) {
    final isCard = method == PaymentMethod.card;

    return Column(
      key: const ValueKey('step-confirm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FidoSays(
          message: isCard
              ? 'Paga en la pasarela y vuelve aquí para confirmar.'
              : 'Sube la foto de tu comprobante para validarlo más rápido.',
        ),
        const SizedBox(height: 24),
        if (isCard) ...[
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: onOpenGateway,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('IR A PAGAR CON TARJETA'),
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: noteController,
            hint: 'N.º de transacción (opcional)',
            icon: Icons.tag_rounded,
            textInputAction: TextInputAction.done,
          ),
        ] else ...[
          Text('FOTO DEL COMPROBANTE *', style: AppTypography.label(size: 13, tracking: 4)),
          const SizedBox(height: 4),
          Text(
            'Foto clara y legible del depósito o la transferencia.',
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          const SizedBox(height: 12),
          _ProofPicker(proof: proof, onPick: onPickProof, onRemove: onRemoveProof),
          const SizedBox(height: 24),
          AppTextField(
            controller: noteController,
            hint: 'N.º de transacción o comprobante (opcional)',
            icon: Icons.tag_rounded,
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }
}

/// Casilla punteada para elegir la foto del comprobante; muestra la vista
/// previa cuando ya hay una.
class _ProofPicker extends StatelessWidget {
  final PickedImage? proof;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ProofPicker({required this.proof, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (proof != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.memory(
              proof!.bytes,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          IconButton.filled(
            tooltip: context.tr('Quitar comprobante'),
            style: IconButton.styleFrom(backgroundColor: AppColors.black),
            icon: const Icon(Icons.close_rounded, color: AppColors.white),
            onPressed: onRemove,
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Subir foto del comprobante',
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.placeholderIcon, width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_camera_outlined, size: 32),
              const SizedBox(height: 8),
              Text(
                'HAZ CLIC AQUÍ PARA SUBIR LA FOTO',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 13, tracking: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
