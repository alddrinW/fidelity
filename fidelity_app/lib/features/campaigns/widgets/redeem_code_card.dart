import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../data/campaigns_repository.dart';
import '../../../core/l10n/tr_text.dart';

/// El local canjea el código que le muestra un cliente (tarjeta de regalo o
/// premio de ruta). Lo usan el dueño y el aprobador.
class RedeemCodeCard extends ConsumerStatefulWidget {
  /// Se llama tras un canje exitoso (p. ej. para refrescar contadores).
  final VoidCallback? onRedeemed;

  const RedeemCodeCard({super.key, this.onRedeemed});

  @override
  ConsumerState<RedeemCodeCard> createState() => _RedeemCodeCardState();
}

class _RedeemCodeCardState extends ConsumerState<RedeemCodeCard> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      DashboardAnimatedToast.show(context, 'Escribe el código del cliente', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ref.read(campaignsRepositoryProvider).redeem(code);
      if (!mounted) return;
      _controller.clear();
      widget.onRedeemed?.call();
      await showDialog<void>(
        context: context,
        builder: (_) => AppMessageDialog(
          icon: Icons.check_circle_outline_rounded,
          title: '¡Canjeado!',
          message: [
            if (result.benefitLabel != null) result.benefitLabel!,
            if (result.userName != null) 'para ${result.userName}',
          ].join(' '),
          hint: result.campaignTitle,
        ),
      );
    } catch (e) {
      if (mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CANJEAR CÓDIGO', style: AppTypography.label(size: 12, tracking: 4)),
          const SizedBox(height: 4),
          Text(
            'Escribe el código que te muestra el cliente en su tarjeta de regalo o premio.',
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _controller,
            hint: 'Ej. GFT-ABC234',
            icon: Icons.qr_code_2_rounded,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _redeem(),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(label: 'Canjear', isLoading: _isLoading, onPressed: _redeem),
        ],
      ),
    );
  }
}
