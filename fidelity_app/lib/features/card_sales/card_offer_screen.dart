import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../admin/data/admin_date_filter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/my_gifts_screen.dart';
import '../campaigns/widgets/gift_card_voucher.dart';
import 'card_transfer_screen.dart';
import 'data/card_sales_repository.dart';

/// Una tarjeta en venta: el cheque con su precio, qué incluye y cuánto queda.
/// El cliente la paga con tarjeta en PayPhone (el servidor confirma el cobro y la
/// tarjeta aparece en "Mis regalos") o por transferencia (sube el comprobante y el
/// administrador lo aprueba).
class CardOfferScreen extends ConsumerStatefulWidget {
  final Campaign offer;

  const CardOfferScreen({super.key, required this.offer});

  @override
  ConsumerState<CardOfferScreen> createState() => _CardOfferScreenState();
}

class _CardOfferScreenState extends ConsumerState<CardOfferScreen> with WidgetsBindingObserver {
  bool _opening = false;

  /// Ya se abrió PayPhone: al volver a la app se pregunta si el cobro llegó.
  bool _paying = false;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paying) _refresh();
  }

  /// La versión más reciente de la oferta (con los cupos y la tarjeta si ya se compró).
  Campaign get _offer {
    final offers = ref.watch(cardOffersProvider).valueOrNull ?? const <Campaign>[];
    return offers.where((o) => o.id == widget.offer.id).firstOrNull ?? widget.offer;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(cardOffersProvider);
    ref.invalidate(myClaimsProvider);
    try {
      final offers = await ref.read(cardOffersProvider.future);
      final current = offers.where((o) => o.id == widget.offer.id).firstOrNull;
      if (!mounted || current?.claim == null || _celebrated) return;
      _celebrated = true;
      _paying = false;
      await _showBought();
    } catch (_) {
      // Sin conexión: se reintenta cuando vuelva a la app.
    }
  }

  /// Con qué se puede pagar (si no se pudo saber, se asume PayPhone, como antes).
  Future<CardSalesRules> _rules() async {
    try {
      return await ref.read(cardSalesRulesProvider.future);
    } catch (_) {
      return const CardSalesRules(enabled: true);
    }
  }

  /// El cliente elige cómo pagar cuando hay más de una forma.
  Future<String?> _chooseMethod() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿CÓMO QUIERES PAGAR?', style: AppTypography.display(size: 26)),
              const SizedBox(height: 14),
              _MethodTile(
                icon: Icons.credit_card_rounded,
                title: 'Tarjeta de crédito o débito',
                subtitle: 'Pagas en PayPhone y la tarjeta llega al instante.',
                onTap: () => Navigator.of(sheetContext).pop('card'),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.account_balance_outlined,
                title: 'Transferencia bancaria',
                subtitle: 'Transfieres y subes tu comprobante; la tarjeta llega cuando lo aprobamos.',
                onTap: () => Navigator.of(sheetContext).pop('transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buy() async {
    setState(() => _opening = true);
    try {
      final rules = await _rules();
      String? method = rules.canChoose ? null : (rules.transferEnabled ? 'transfer' : 'card');
      if (method == null) {
        method = await _chooseMethod();
        if (method == null) return;
      }
      if (method == 'transfer') {
        final start = await ref.read(cardSalesRepositoryProvider).startTransfer(widget.offer.id);
        await _openTransfer(TransferStart(
          purchaseId: start.purchaseId,
          reference: start.reference,
          amountCents: start.amountCents,
          reservedUntil: start.reservedUntil,
          bankAccounts: start.bankAccounts.isNotEmpty ? start.bankAccounts : rules.bankAccounts,
        ));
        return;
      }
      final uri = await ref.read(cardSalesRepositoryProvider).startPurchase(widget.offer.id);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (opened) {
        _paying = true;
      } else {
        _showError('No se pudo abrir la página de pago.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openTransfer(TransferStart start) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CardTransferScreen(offer: _offer, start: start)),
    );
    if (sent == true) ref.invalidate(cardOffersProvider);
  }

  /// Retoma una transferencia que quedó esperando el comprobante.
  Future<void> _continueTransfer(TransferPurchase purchase) async {
    setState(() => _opening = true);
    try {
      final rules = await _rules();
      if (!mounted) return;
      await _openTransfer(TransferStart(
        purchaseId: purchase.id,
        reference: purchase.reference,
        amountCents: purchase.amountCents,
        reservedUntil: purchase.reservedUntil,
        bankAccounts: rules.bankAccounts,
      ));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _showBought() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.verified_rounded,
        leading: const FidoMascot(mood: FidoMood.celebrate, height: 120),
        title: '¡Compra aprobada!',
        message: 'Tu tarjeta de ${widget.offer.businesses.firstOrNull?.name ?? 'tu local'} ya está en Mis regalos.',
        primaryLabel: 'Ver mi tarjeta',
        onPrimary: () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyGiftsScreen()));
        },
        secondaryLabel: 'Cerrar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final business = offer.businesses.firstOrNull;
    final bought = offer.claim != null;
    final purchase = bought ? null : offer.purchase;
    final soldOut = !bought && purchase == null && (offer.stockLeft ?? 0) <= 0;
    final rules = ref.watch(cardSalesRulesProvider).valueOrNull;
    final ends = offer.endsAt;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Tarjeta en venta'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    GiftCardVoucher(
                      campaign: offer,
                      priceLabel: offer.priceText,
                      logoUrl: business?.logoUrl,
                      businessName: business?.name,
                    ).animate().fadeIn().slideY(begin: 0.05),
                    const SizedBox(height: 20),
                    AppCard(
                      radius: 28,
                      child: Column(
                        children: [
                          _Fact(
                            icon: Icons.storefront_outlined,
                            label: 'Se canjea en',
                            value: business?.name ?? 'El local',
                          ),
                          _Fact(
                            icon: Icons.event_available_outlined,
                            label: 'Vale',
                            value: '${offer.cardValidDays ?? 30} días desde que la compras',
                          ),
                          _Fact(
                            icon: Icons.inventory_2_outlined,
                            label: 'Quedan',
                            value: soldOut ? 'Agotada' : '${offer.stockLeft ?? 0} / ${offer.stock ?? 0}',
                          ),
                          if (ends != null)
                            _Fact(
                              icon: Icons.timer_outlined,
                              label: 'Se vende hasta',
                              value: EcuadorDateUtils.formatEcuadorDate(ends.toUtc().toIso8601String()),
                            ),
                        ],
                      ),
                    ),
                    if (purchase != null) ...[
                      const SizedBox(height: 14),
                      _TransferStatus(purchase: purchase),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      rules == null || (rules.cardEnabled && !rules.transferEnabled)
                          ? 'Pagas con tarjeta en PayPhone. Si el pago no se aprueba, no se te cobra. '
                              'Al canjearla, el local te la acepta mostrando su código.'
                          : rules.canChoose
                              ? 'Puedes pagar con tarjeta en PayPhone o por transferencia bancaria. '
                                  'Al canjearla, el local te la acepta mostrando su código.'
                              : 'Pagas por transferencia bancaria: subes tu comprobante y, cuando lo aprobamos, la tarjeta llega a Mis regalos. '
                                  'Al canjearla, el local te la acepta mostrando su código.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 48, 24),
                child: bought
                    ? AppPrimaryButton(
                        label: 'Ya la tienes: ver Mis regalos',
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const MyGiftsScreen())),
                      )
                    : purchase != null && purchase.isInReview
                        ? const AppPrimaryButton(label: 'Comprobante en revisión', onPressed: null)
                        : purchase != null && purchase.isPending
                            ? AppPrimaryButton(
                                label: 'Subir comprobante',
                                isLoading: _opening,
                                onPressed: () => _continueTransfer(purchase),
                              )
                            : AppPrimaryButton(
                                label: soldOut
                                    ? 'Agotada'
                                    : purchase != null && purchase.isRejected
                                        ? 'Intentar de nuevo'
                                        : 'Comprar por ${offer.priceText}',
                                isLoading: _opening,
                                onPressed: soldOut ? null : _buy,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dónde va la compra por transferencia: falta el comprobante, se está revisando o se rechazó.
class _TransferStatus extends StatelessWidget {
  final TransferPurchase purchase;

  const _TransferStatus({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String message, Color background) = switch (purchase.status) {
      'in_review' => (
          Icons.hourglass_top_rounded,
          'Estamos revisando tu comprobante',
          'Te avisaremos apenas lo aprobemos y tu tarjeta llegará a Mis regalos.',
          AppColors.surfaceMuted,
        ),
      'rejected' => (
          Icons.error_outline_rounded,
          'No pudimos aceptar tu comprobante',
          purchase.reviewNote ?? 'Revisa los datos e inténtalo de nuevo.',
          AppColors.pink.withValues(alpha: 0.35),
        ),
      _ => (
          Icons.receipt_long_outlined,
          'Falta tu comprobante',
          purchase.reservedUntil == null
              ? 'Sube la foto de tu transferencia para que la revisemos.'
              : 'Te guardamos la tarjeta hasta el ${formatShortDate(purchase.reservedUntil!)}: sube la foto de tu transferencia.',
          AppColors.pink.withValues(alpha: 0.35),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AppTypography.label(size: 12, tracking: 2)),
                const SizedBox(height: 4),
                Text(message, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
                const SizedBox(height: 6),
                Text(
                  '${purchase.reference} · ${centsText(purchase.amountCents)}',
                  style: AppTypography.body(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una forma de pagar en la hoja de elegir.
class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body(size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label.toUpperCase(), style: AppTypography.label(size: 11, tracking: 2))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.body(size: 14, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
