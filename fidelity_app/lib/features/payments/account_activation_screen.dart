import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../auth/data/auth_repository.dart';
import '../auth/providers/auth_provider.dart';
import 'data/payments_repository.dart';
import 'paga_ya_screen.dart';
import '../../core/l10n/tr_text.dart';

/// Pantalla de un negocio recién creado (o inactivo): explica que la cuenta se
/// activa al validar el pago y lleva al asistente "PAGA YA". Muestra el estado
/// del pago (pendiente, en revisión o rechazado).
class AccountActivationScreen extends ConsumerStatefulWidget {
  const AccountActivationScreen({super.key});

  @override
  ConsumerState<AccountActivationScreen> createState() => _AccountActivationScreenState();
}

class _AccountActivationScreenState extends ConsumerState<AccountActivationScreen> {
  PaymentOrder? _order;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final businessId = ref.read(authRepositoryProvider).currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No encontramos tu negocio.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await ref.read(paymentsRepositoryProvider).ensureOrder(businessId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      // Si el negocio ya fue activado entre tanto, el estado de sesión lo
      // detecta al refrescar; aquí solo mostramos el error.
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Vuelve a consultar el estado de la cuenta: si el administrador ya validó
  /// el pago, la sesión pasa sola al panel del negocio.
  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(authStateProvider.notifier).checkAuth();
      await _loadOrder();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openPagaYa() async {
    final order = _order;
    if (order == null) return;
    final reported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PagaYaScreen(order: order)),
    );
    if (reported == true) await _loadOrder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.black)
                      : _error != null
                          ? _ErrorView(message: _error!, onRetry: _loadOrder)
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                              child: _OrderView(
                                order: _order!,
                                isRefreshing: _isRefreshing,
                                onPay: _openPagaYa,
                                onRefresh: _refresh,
                              ),
                            ),
                ),
              ),
              AppTextAction(
                label: 'Cerrar sesión',
                onPressed: () => ref.read(authStateProvider.notifier).logout(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderView extends StatelessWidget {
  final PaymentOrder order;
  final bool isRefreshing;
  final VoidCallback onPay;
  final VoidCallback onRefresh;

  const _OrderView({
    required this.order,
    required this.isRefreshing,
    required this.onPay,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final reported = order.status == PaymentStatus.reported;
    final rejected = order.status == PaymentStatus.rejected;

    final String title = reported
        ? 'Pago en revisión'
        : rejected
            ? 'No pudimos validar tu pago'
            : '¡Negocio creado!';
    final String message = reported
        ? 'Recibimos tu aviso de pago. Te avisaremos cuando tu cuenta esté activa.'
        : rejected
            ? (order.adminNote?.isNotEmpty == true
                ? order.adminNote!
                : 'Revisa los datos de tu pago y repórtalo de nuevo.')
            : 'Para activar ${order.businessName} completa el pago del registro: '
                '${order.amountLabel}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          reported ? 'assets/images/logo_transparente.png' : 'assets/images/fido_celebra.png',
          height: 180,
          fit: BoxFit.contain,
          semanticLabel: 'Fido',
        ),
        const SizedBox(height: 16),
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTypography.display(size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 16, weight: FontWeight.w300),
        ),
        const SizedBox(height: 16),
        Center(
          child: AppChip(
            label: 'Ref. ${order.reference}',
            style: reported ? AppChipStyle.dark : AppChipStyle.outline,
            icon: reported ? Icons.hourglass_top_rounded : Icons.tag_rounded,
          ),
        ),
        const SizedBox(height: 32),
        if (reported)
          AppPrimaryButton(
            label: 'Actualizar estado',
            isLoading: isRefreshing,
            onPressed: onRefresh,
          )
        else ...[
          AppPrimaryButton(label: rejected ? 'Reportar de nuevo' : 'Paga ya', onPressed: onPay),
          const SizedBox(height: 8),
          AppTextAction(label: 'Ya me activaron', onPressed: isRefreshing ? null : onRefresh),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ALGO SALIÓ MAL',
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15, weight: FontWeight.w300),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(label: 'Reintentar', onPressed: onRetry),
        ],
      ),
    );
  }
}
