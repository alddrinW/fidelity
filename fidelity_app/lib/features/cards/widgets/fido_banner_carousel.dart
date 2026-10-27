import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/utils/money_format.dart';
import '../../banners/data/banners_repository.dart';
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

/// Los banners ya diseñados (2000 × 648 px, proporción 3.09:1; el texto va dentro
/// de la imagen, en español).
class BannerImages {
  BannerImages._();

  /// "Gana 1 punto: invita a 3 amigos y canjea 1 punto en cualquier fidelytienda".
  static const invite = 'assets/images/banner_invitar_amigos.webp';

  /// "Juega y gana: juega los minijuegos y gana 1 punto y descuentos".
  static const play = 'assets/images/banner_juega_y_gana.webp';

  /// El Fido de esos banners (recortado de ellos, 745 × 648 px): el que acompaña a los
  /// mensajes que cambian con cada cliente, para que todo el carrusel tenga el mismo estilo.
  static const fido = 'assets/images/banner_fido.webp';

  /// Proporción del recorte de Fido.
  static const fidoRatio = 745 / 648;
}

/// El color del botón del banner (el resto va igual en todos: Fido, el título en
/// negro y el texto, sobre el fondo de la pantalla, sin recuadro).
enum BannerTone {
  /// Botón negro con texto blanco.
  soft,

  /// Botón rosa con texto negro.
  white,

  /// Botón negro con texto rosa.
  dark,
}

/// Un mensaje de Fido para el cliente: lo que puede hacer ahora.
class FidoBanner {
  /// Identifica el mensaje (para no reiniciar el carrusel si no cambió nada).
  final String id;
  final BannerTone tone;
  final String title;
  final String body;

  /// El botón de la nube ("COMPRAR", "INVITAR"...).
  final String cta;
  final VoidCallback? onTap;

  /// Un banner ya diseñado (imagen con su texto): se muestra tal cual, en vez de
  /// Fido con su mensaje. Puede ser uno que subió el administrador o uno de los que
  /// vienen con la app; estos últimos solo se usan cuando lo que dice la imagen es
  /// cierto para este cliente y en español (si no, sale el mensaje de Fido, que sí
  /// se ajusta y se traduce).
  final ImageProvider? image;

  /// Con `true`, los bordes de la imagen se funden con el fondo blanco de la pantalla;
  /// con `false` se ve como una imagen con las esquinas redondeadas.
  final bool blendWhite;

  const FidoBanner({
    this.image,
    this.blendWhite = true,
    required this.id,
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
    // Las imágenes que vienen con la app traen su texto en español.
    final spanish = ref.watch(languageProvider) == AppLanguage.es;
    // Los banners que subió el administrador. Mientras no haya ninguno (ya respondió el
    // servidor, o no se pudo consultar) salen los dos diseños que vienen con la app.
    final bannersAsync = ref.watch(clientBannersProvider);
    final adminBanners = bannersAsync.valueOrNull ?? const <ClientBanner>[];
    final builtInImages = !bannersAsync.isLoading && adminBanners.isEmpty;

    final banners = <FidoBanner>[];

    // 1. Un premio esperando: lo más importante.
    final rewardCard = cardWithPendingReward(cards);
    if (rewardCard != null && onOpenReward != null) {
      final business = (rewardCard['businesses'] as Map?) ?? const {};
      banners.add(FidoBanner(
        id: 'reward-${rewardCard['id']}',
        tone: BannerTone.white,
        title: '¡Premio listo!',
        body: 'Pásate por ${business['name'] ?? 'tu local'} y reclama tu premio.',
        cta: 'VER PREMIO',
        onTap: () => onOpenReward!(rewardCard),
      ));
    }

    // 2. El juego de la semana (una vez por semana, en el negocio que elija). Si no hay nada
    // más específico que decir (todavía no eligió negocio y el punto es 1), sale el diseño
    // "Juega y gana" del ingeniero; así sale también cuando el juego está apagado o ya jugó:
    // al tocarlo abre el juego de la semana, que explica en qué estado está.
    Future<void> openWeekly() async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeeklyGameScreen()));
      ref.invalidate(weeklyGameProvider);
    }

    final weeklyOpen = weekly != null && weekly.canPlay;
    final weeklySpecific = weeklyOpen && !(weekly.isAvailable && weekly.points == 1);
    if (weekly != null && builtInImages && spanish && !weeklySpecific) {
      banners.add(FidoBanner(
        id: 'weekly-image',
        image: const AssetImage(BannerImages.play),
        tone: BannerTone.dark,
        title: 'Juega y gana',
        body: 'Juega los minijuegos y gana 1 punto y descuentos.',
        cta: 'JUGAR',
        onTap: openWeekly,
      ));
    } else if (weekly != null && weeklyOpen) {
      final chosen = weekly.isPlaying ? weekly.current?.businessName : null;
      final points = '${weekly.points} ${weekly.points == 1 ? 'punto' : 'puntos'}';
      banners.add(FidoBanner(
        id: 'weekly-${weekly.state}-${weekly.current?.businessId ?? ''}',
        tone: BannerTone.dark,
        title: 'Juego de la semana',
        body: chosen == null ? 'Elige un negocio, juega y gana $points.' : 'Elegiste $chosen: ¡a jugar y ganar $points!',
        cta: chosen == null ? 'ELEGIR NEGOCIO' : 'JUGAR',
        onTap: openWeekly,
      ));
    }

    // 3. A un punto de un premio.
    final almost = cards.where(isOnePointAway).firstOrNull;
    if (almost != null && onScan != null) {
      final business = (almost['businesses'] as Map?) ?? const {};
      final reward = business['reward_description']?.toString().trim() ?? '';
      banners.add(FidoBanner(
        id: 'almost-${almost['id']}',
        tone: BannerTone.soft,
        title: 'Te falta 1 punto',
        body: reward.isEmpty
            ? 'Escanea hoy en ${business['name'] ?? 'tu local'} y completa tu tarjeta.'
            : 'Escanea hoy en ${business['name'] ?? 'tu local'} y gana: $reward.',
        cta: 'ESCANEAR',
        onTap: onScan!,
      ));
    }

    // Lo que sube el administrador: imágenes ya diseñadas, en el orden que él eligió.
    for (final b in adminBanners) {
      final image = imageProviderFromUrl(b.imageUrl);
      if (image == null) continue;
      banners.add(FidoBanner(
        id: 'admin-${b.id}-${b.imageUrl.hashCode}',
        image: image,
        blendWhite: b.blendWhite,
        tone: BannerTone.soft,
        title: b.title,
        body: '',
        cta: '',
        onTap: _adminAction(context, ref, b),
      ));
    }

    // 4. Tarjetas que los locales venden (una abre su ficha; varias, Explorar).
    final buyable = offers.where((o) => o.claim == null).toList();
    if (buyable.isNotEmpty) {
      final one = buyable.length == 1 ? buyable.first : null;
      final cheapest = buyable.map((o) => o.priceCents ?? 0).reduce((a, b) => a < b ? a : b);
      banners.add(FidoBanner(
        id: 'offers-${buyable.map((o) => o.id).join(',')}',
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
        // "Invita a 3 amigos y canjea 1 punto": vale con la regla de 3 amigos y 1
        // punto, y mientras no tenga puntos por usar (ahí toca otro mensaje).
        image: builtInImages && spanish && n == 3 && referral.referrerPoints == 1 && !hasBalance
            ? const AssetImage(BannerImages.invite)
            : null,
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

extension on FidoBannerCarousel {
  /// Lo que hace el banner al tocarlo (`null`: no hace nada).
  VoidCallback? _adminAction(BuildContext context, WidgetRef ref, ClientBanner b) {
    switch (b.action) {
      case BannerAction.none:
        return null;
      case BannerAction.invite:
        return () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteScreen()));
          ref.invalidate(referralInfoProvider);
        };
      case BannerAction.weeklyGame:
        return () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeeklyGameScreen()));
          ref.invalidate(weeklyGameProvider);
        };
      case BannerAction.offers:
        return onOpenOffers;
      case BannerAction.scan:
        return onScan;
      case BannerAction.link:
        final uri = Uri.tryParse(b.linkUrl ?? '');
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
        return () => launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  /// El cliente está moviendo el carrusel con el dedo.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  /// Cada vez que cambia de mensaje (solo o con el dedo) se cuentan otros 6 segundos.
  /// Pasa solo aunque el sistema tenga las animaciones apagadas (muchos celulares y
  /// emuladores las apagan y el carrusel se veía quieto): en ese caso el cambio es
  /// directo, sin deslizar.
  void _restartTimer() {
    _timer?.cancel();
    if (!widget.autoPlay || widget.banners.length < 2) return;
    _timer = Timer(_every, () {
      if (!mounted) return;
      // Si el cliente tiene el dedo encima, o aún no hay página, se espera otro turno.
      if (_dragging || !_controller.hasClients) {
        _restartTimer();
        return;
      }
      final next = (_page + 1) % widget.banners.length;
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduced) {
        _controller.jumpToPage(next);
      } else {
        _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
              if (n is ScrollEndNotification && _dragging) {
                _dragging = false;
                _restartTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: banners.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                _restartTimer();
              },
              itemBuilder: (_, i) => FidoBannerCard(banner: banners[i]),
            ),
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
  /// Sin recuadro: lo que se ve es Fido y su mensaje, como en los banners del ingeniero.
  static const double height = 152;

  /// Con la letra del sistema más grande, el banner crece para que el texto quepa.
  static double heightFor(BuildContext context) =>
      height * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  final FidoBanner banner;

  const FidoBannerCard({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    if (banner.image != null) return _ImageBanner(banner: banner);

    final (Color ctaBackground, Color ctaForeground) = switch (banner.tone) {
      BannerTone.soft => (AppColors.black, AppColors.white),
      BannerTone.white => (AppColors.pink, AppColors.black),
      BannerTone.dark => (AppColors.black, AppColors.pink),
    };

    // El mismo estilo de los banners del ingeniero: su Fido de fieltro, que sale del
    // fondo blanco, y a la derecha el título grande, el texto y un botoncito.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: banner.onTap != null,
        label: '${banner.title}. ${banner.body}',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: banner.onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.hasBoundedHeight ? constraints.maxHeight : heightFor(context);
                // Fido ocupa como mucho el 42 % del ancho: en un celular angosto o con la
                // letra grande se achica para dejarle sitio al texto.
                final fidoHeight = h < constraints.maxWidth * 0.42 / BannerImages.fidoRatio
                    ? h
                    : constraints.maxWidth * 0.42 / BannerImages.fidoRatio;
                return Row(
                  children: [
                    SizedBox(
                      width: fidoHeight * BannerImages.fidoRatio,
                      height: fidoHeight,
                      child: _ImageBanner.feather(
                        Image.asset(
                          BannerImages.fido,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'Fido',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              banner.title.toUpperCase(),
                              maxLines: 2,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.display(size: 22, color: AppColors.black).copyWith(height: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              banner.body,
                              maxLines: 3,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(size: 11, weight: FontWeight.w300, color: AppColors.black),
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
                                style: AppTypography.label(size: 9, tracking: 1.2, color: ctaForeground),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Un banner ya diseñado: la imagen completa, que se toca para ir a la acción. Se
/// ajusta al ancho (no se recorta). Con [FidoBanner.blendWhite] su fondo blanco se
/// funde con el de la pantalla: los bordes donde Fido queda cortado (izquierda, arriba
/// y abajo) se difuminan hacia el blanco, así Fido sale del fondo y no se ve un
/// rectángulo. Sin eso, se ve como una imagen con las esquinas redondeadas.
class _ImageBanner extends StatelessWidget {
  final FidoBanner banner;

  /// Proporción de las imágenes (2000 × 648 px).
  static const double aspectRatio = 2000 / 648;

  /// Cuánto se difumina cada borde (fracción del ancho o del alto).
  static const double fadeLeft = 0.14;
  static const double fadeVertical = 0.12;

  /// Esquinas de una imagen que no se funde.
  static const double radius = 28;

  const _ImageBanner({required this.banner});

  /// Una máscara que vuelve transparente la orilla de [child].
  static Widget _fade(Widget child, LinearGradient gradient) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: gradient.createShader,
        child: child,
      );

  /// Difumina hacia el blanco los bordes izquierdo, de arriba y de abajo: ahí es donde
  /// Fido queda cortado por la imagen.
  static Widget feather(Widget image) {
    const clear = Color(0x00FFFFFF);
    const solid = Color(0xFFFFFFFF);
    image = _fade(
      image,
      const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [clear, solid, solid],
        stops: [0, fadeLeft, 1],
      ),
    );
    return _fade(
      image,
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [clear, solid, solid, clear],
        stops: [0, fadeVertical, 1 - fadeVertical, 1],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image(
      image: banner.image!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      // Si la imagen no carga, el banner queda vacío en vez de romper el carrusel.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (banner.blendWhite) {
      image = feather(image);
    } else {
      image = ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    }

    return Semantics(
      button: banner.onTap != null,
      label: banner.body.isEmpty ? banner.title : '${banner.title}. ${banner.body}',
      excludeSemantics: true,
      child: Align(
        // El alto se reserva desde el inicio (por la proporción de la imagen):
        // el banner no "salta" al terminar de cargar y ya se puede tocar.
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(36),
              onTap: banner.onTap,
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}
