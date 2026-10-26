import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/my_gifts_screen.dart';
import '../campaigns/widgets/gift_card_voucher.dart';
import 'data/card_sales_repository.dart';

/// Una tarjeta en venta: el cheque con su precio, qué incluye y cuánto queda.
/// El cliente la paga con tarjeta en PayPhone; el servidor confirma el cobro y
/// la tarjeta aparece en "Mis regalos".
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

  Future<void> _buy() async {
    setState(() => _opening = true);
    try {
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
    final soldOut = !bought && (offer.stockLeft ?? 0) <= 0;
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
                    const SizedBox(height: 14),
                    Text(
                      'Pagas con tarjeta en PayPhone. Si el pago no se aprueba, no se te cobra. '
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
                    : AppPrimaryButton(
                        label: soldOut ? 'Agotada' : 'Comprar por ${offer.priceText}',
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
