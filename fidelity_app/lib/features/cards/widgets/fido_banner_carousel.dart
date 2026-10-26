import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_format.dart';
import '../../campaigns/data/campaigns_repository.dart' show Campaign;
import '../../card_sales/card_offer_screen.dart';
import '../../card_sales/data/card_sales_repository.dart';
import '../../games/data/games_repository.dart';
import '../../games/data/weekly_game_repository.dart';
import '../../games/game_invite_screen.dart';
import '../../games/weekly_game_screen.dart';
import '../../referrals/data/referrals_repository.dart';
import '../../referrals/invite_screen.dart';
import '../../referrals/points_text.dart';
import 'registered_scans_list.dart';

/// Cuántos premios tiene el cliente sin reclamar (en todos sus locales).
int pendingRewardCount(List<Map<String, dynamic>> cards) {
  var count = 0;
  for (final card in cards) {
    final rewards = (card['rewards'] as List?) ?? const [];
    count += rewards.where((r) => (r as Map)['status'] == 'pending').length;
  }
  return count;
}

/// La primera tarjeta que tiene un premio sin reclamar, o `null`.
Map<String, dynamic>? cardWithPendingReward(List<Map<String, dynamic>> cards) {
  for (final card in cards) {
    final rewards = (card['rewards'] as List?) ?? const [];
    if (rewards.any((r) => (r as Map)['status'] == 'pending')) return card;
  }
  return null;
}

/// Las poses de Fido de los banners (cada una es un archivo de `assets/images`).
enum FidoPose {
  cafe('assets/images/fido_cafe.png', 'Fido con un café'),
  idea('assets/images/fido_idea.png', 'Fido con una idea'),
  laptop('assets/images/fido_laptop.png', 'Fido con una computadora'),
  lapiz('assets/images/fido_lapiz.png', 'Fido con un lápiz'),
  pulgares('assets/images/fido_pulgares.png', 'Fido con los pulgares arriba'),
  brazos('assets/images/fido_brazos.png', 'Fido con los brazos cruzados');

  final String asset;
  final String label;

  const FidoPose(this.asset, this.label);
}

/// El color de la nube (Fido y la nube van sueltos sobre el fondo de la pantalla,
/// sin recuadro); el texto y el botón se ajustan para que se lean.
enum BannerTone {
  /// Nube rosa muy claro.
  soft,

  /// Nube rosa.
  white,

  /// Nube negra, con el texto blanco y el botón rosa.
  dark,
}

/// Un mensaje de Fido para el cliente: lo que puede hacer ahora.
class FidoBanner {
  /// Identifica el mensaje (para no reiniciar el carrusel si no cambió nada).
  final String id;
  final FidoPose pose;
  final BannerTone tone;
  final String title;
  final String body;

  /// El botón de la nube ("COMPRAR", "INVITAR"...).
  final String cta;
  final VoidCallback onTap;

  const FidoBanner({
    required this.id,
    required this.pose,
    required this.tone,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });
}

/// El carrusel de Fido en la parte principal del inicio: una nube que le dice
/// al cliente qué puede hacer (reclamar un premio, comprar una tarjeta, invitar
/// a un amigo...). Solo salen los mensajes que le sirven a esa persona y, si no
/// hay ninguno, no ocupa espacio.
class FidoBannerCarousel extends ConsumerWidget {
  /// Las tarjetas del cliente, para avisar de un premio o de que le falta un punto.
  final List<Map<String, dynamic>> cards;

  /// Abre el premio pendiente de una tarjeta.
  final ValueChanged<Map<String, dynamic>>? onOpenReward;

  /// Lleva a las tarjetas en venta (Explorar) cuando hay varias.
  final VoidCallback? onOpenOffers;

  /// Abre el escáner.
  final VoidCallback? onScan;

  /// Pasa de mensaje solo cada 6 segundos; en las pruebas se apaga.
  final bool autoPlay;

  const FidoBannerCarousel({
    super.key,
    this.cards = const [],
    this.onOpenReward,
    this.onOpenOffers,
    this.onScan,
    this.autoPlay = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myGameInvitesProvider).valueOrNull ?? const <GameInvite>[];
    final referral = ref.watch(referralInfoProvider).valueOrNull;
    final offers = ref.watch(cardOffersProvider).valueOrNull ?? const <Campaign>[];
    final weekly = ref.watch(weeklyGameProvider).valueOrNull;

    final banners = <FidoBanner>[];

    // 1. Un premio esperando: lo más importante.
    final rewardCard = cardWithPendingReward(cards);
    if (rewardCard != null && onOpenReward != null) {
      final business = (rewardCard['businesses'] as Map?) ?? const {};
      banners.add(FidoBanner(
        id: 'reward-${rewardCard['id']}',
        pose: FidoPose.pulgares,
        tone: BannerTone.white,
        title: '¡Premio listo!',
        body: 'Pásate por ${business['name'] ?? 'tu local'} y reclama tu premio.',
        cta: 'VER PREMIO',
        onTap: () => onOpenReward!(rewardCard),
      ));
    }

    // 2. El juego de la semana (una vez por semana, en el negocio que elija).
    if (weekly != null && weekly.canPlay) {
      final chosen = weekly.isPlaying ? weekly.current?.businessName : null;
      final points = '${weekly.points} ${weekly.points == 1 ? 'punto' : 'puntos'}';
      banners.add(FidoBanner(
        id: 'weekly-${weekly.state}-${weekly.current?.businessId ?? ''}',
        pose: FidoPose.laptop,
        tone: BannerTone.dark,
        title: 'Juego de la semana',
        body: chosen == null ? 'Elige un negocio, juega y gana $points.' : 'Elegiste $chosen: ¡a jugar y ganar $points!',
        cta: chosen == null ? 'ELEGIR NEGOCIO' : 'JUGAR',
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeeklyGameScreen()));
          ref.invalidate(weeklyGameProvider);
        },
      ));
    }

    // 3. A un punto de un premio.
    final almost = cards.where(isOnePointAway).firstOrNull;
    if (almost != null && onScan != null) {
      final business = (almost['businesses'] as Map?) ?? const {};
      final reward = business['reward_description']?.toString().trim() ?? '';
      banners.add(FidoBanner(
        id: 'almost-${almost['id']}',
        pose: FidoPose.brazos,
        tone: BannerTone.soft,
        title: 'Te falta 1 punto',
        body: reward.isEmpty
            ? 'Escanea hoy en ${business['name'] ?? 'tu local'} y completa tu tarjeta.'
            : 'Escanea hoy en ${business['name'] ?? 'tu local'} y gana: $reward.',
        cta: 'ESCANEAR',
        onTap: onScan!,
      ));
    }

    // 4. Tarjetas que los locales venden (una abre su ficha; varias, Explorar).
    final buyable = offers.where((o) => o.claim == null).toList();
    if (buyable.isNotEmpty) {
      final one = buyable.length == 1 ? buyable.first : null;
      final cheapest = buyable.map((o) => o.priceCents ?? 0).reduce((a, b) => a < b ? a : b);
      banners.add(FidoBanner(
        id: 'offers-${buyable.map((o) => o.id).join(',')}',
        pose: FidoPose.cafe,
        tone: BannerTone.soft,
        title: one == null ? '${buyable.length} tarjetas en venta' : '${one.benefitLabel ?? one.title} por ${one.priceText}',
        body: one == null
            ? 'Desde ${centsText(cheapest)}. Cómpralas con tarjeta.'
            : '${one.businesses.firstOrNull?.name ?? 'Un local'}. Cómprala y canjéala en el local.',
        cta: 'COMPRAR',
        onTap: () async {
          if (one == null) {
            onOpenOffers?.call();
            return;
          }
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardOfferScreen(offer: one)));
          ref.invalidate(cardOffersProvider);
        },
      ));
    }

    // 5. Juegos que le mandaron los locales (hasta dos, para no llenar el carrusel).
    for (final invite in invites.where((i) => i.isOpen).take(2)) {
      banners.add(FidoBanner(
        id: 'game-${invite.id}',
        pose: FidoPose.laptop,
        tone: BannerTone.dark,
        title: 'Juega y gana',
        body: '${invite.gameName} de ${invite.businessName ?? 'un local'}. '
            '${invite.attemptsLeft == 1 ? 'Te queda 1 intento' : 'Te quedan ${invite.attemptsLeft} intentos'}.',
        cta: 'JUGAR',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GameInviteScreen(inviteId: invite.id)),
          );
          ref.invalidate(myGameInvitesProvider);
        },
      ));
    }

    // 6. Invitar amigos (o usar los puntos de invitación que ya ganó).
    if (referral != null && referral.visible) {
      final hasBalance = referral.balance > 0;
      final n = referral.friendsRequired;
      final earns = referral.referrerPoints > 0 ? pointsText(referral.referrerPoints) : null;
      final body = hasBalance
          ? 'Tienes ${pointsText(referral.balance)} de invitación: elige en qué local usarlos.'
          : earns == null
              ? 'Invita a un amigo a Fidelity.'
              : referral.inGroup > 0
                  ? 'Van ${referral.inGroup} de $n amigos. Al completar, ganas $earns.'
                  : 'Cuando se registren los $n con tu código, ganas $earns.';
      banners.add(FidoBanner(
        id: 'invite-${referral.balance}-${referral.inGroup}',
        pose: FidoPose.idea,
        tone: BannerTone.white,
        title: n == 1 ? 'Invita a un amigo' : 'Invita a $n amigos',
        body: body,
        cta: hasBalance ? 'ELEGIR LOCAL' : 'INVITAR',
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteScreen()));
          ref.invalidate(referralInfoProvider);
        },
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _BannerPager(
        // Si cambian los mensajes, el carrusel arranca de nuevo desde el primero.
        key: ValueKey(banners.map((b) => b.id).join('|')),
        banners: banners,
        autoPlay: autoPlay,
      ),
    );
  }
}

class _BannerPager extends StatefulWidget {
  final List<FidoBanner> banners;
  final bool autoPlay;

  const _BannerPager({super.key, required this.banners, required this.autoPlay});

  @override
  State<_BannerPager> createState() => _BannerPagerState();
}

class _BannerPagerState extends State<_BannerPager> {
  static const Duration _every = Duration(seconds: 6);

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  /// Cada vez que cambia de mensaje (solo o con el dedo) se cuentan otros 6 segundos.
  void _restartTimer() {
    _timer?.cancel();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.autoPlay || reduced || widget.banners.length < 2) return;
    _timer = Timer(_every, () {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;

    return Column(
      children: [
        SizedBox(
          height: FidoBannerCard.heightFor(context),
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _restartTimer();
            },
            itemBuilder: (_, i) => FidoBannerCard(banner: banners[i], animate: i == _page),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.black : AppColors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.black, width: 1.2),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class FidoBannerCard extends StatelessWidget {
  /// Alto del banner (medidas para el diseñador: 432 × 152 dp, 1296 × 456 px a 3x).
  /// Ya no lleva recuadro: lo que se ve es Fido y su nube.
  static const double height = 152;

  /// Con la letra del sistema más grande, el banner crece para que el texto quepa.
  static double heightFor(BuildContext context) =>
      height * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  final FidoBanner banner;

  /// Solo el banner que se está viendo mueve a Fido.
  final bool animate;

  const FidoBannerCard({super.key, required this.banner, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final (Color bubble, Color text, Color ctaBackground, Color ctaForeground) = switch (banner.tone) {
      BannerTone.soft => (
          Color.alphaBlend(AppColors.pink.withValues(alpha: 0.38), AppColors.white),
          AppColors.black,
          AppColors.black,
          AppColors.white,
        ),
      BannerTone.white => (AppColors.pink, AppColors.black, AppColors.black, AppColors.white),
      BannerTone.dark => (AppColors.black, AppColors.white, AppColors.pink, AppColors.black),
    };
    final still = !animate || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    Widget fido = Image.asset(
      banner.pose.asset,
      height: 126,
      fit: BoxFit.contain,
      semanticLabel: banner.pose.label,
    );
    if (!still) {
      // Fido flota despacio, unas cuantas veces: no se queda moviéndose para siempre.
      fido = fido
          .animate(onPlay: (c) => c.repeat(reverse: true, count: 8))
          .moveY(begin: 0, end: -5, duration: 1500.ms, curve: Curves.easeInOut);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: true,
        label: '${banner.title}. ${banner.body}',
        excludeSemantics: true,
        // Sin recuadro: solo Fido y su nube; todo el banner responde al toque.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: banner.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 2, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Align(alignment: Alignment.bottomCenter, child: fido),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // La colita de la nube, hacia Fido.
                        Positioned(
                          left: -6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Transform.rotate(
                              angle: 0.785398,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: bubble,
                                  border: const Border(
                                    left: BorderSide(color: AppColors.black, width: 1.2),
                                    bottom: BorderSide(color: AppColors.black, width: 1.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                          decoration: BoxDecoration(
                            color: bubble,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.black, width: 1.2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner.title.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display(size: 18, color: text).copyWith(height: 1.05),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                banner.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(size: 12, weight: FontWeight.w300, color: text),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ctaBackground,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  banner.cta,
                                  style: AppTypography.label(size: 10, tracking: 1.2, color: ctaForeground),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
