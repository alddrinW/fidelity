import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/image_source.dart';
import '../../core/validators/app_validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_pill_tab_bar.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/fidely_badge.dart';
import '../feedback/widgets/feedback_sheet.dart';
import '../campaigns/campaign_detail_screen.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/widgets/gift_claim_tile.dart';
import '../games/data/games_repository.dart';
import '../games/game_invite_screen.dart';
import '../games/widgets/game_invite_tile.dart';
import 'providers/card_history_provider.dart';
import 'widgets/missions_route.dart';
import '../../core/l10n/translator.dart';
import '../../core/l10n/tr_text.dart';

/// Un local del cliente: arriba su cabecera con los sellos y el premio, y
/// debajo tres pestañas: los **premios** (por reclamar, entregados o rechazados,
/// con transferencia), las **gift cards** que el local le dio y los
/// **minijuegos** que le mandó.
class CardHistoryScreen extends ConsumerStatefulWidget {
  /// Las pestañas, para abrir la pantalla en una de ellas.
  static const int rewardsTab = 0;
  static const int giftCardsTab = 1;
  static const int gamesTab = 2;


  final String loyaltyCardId;
  final String businessId;
  final String businessName;
  final int initialTabIndex;

  const CardHistoryScreen({
    super.key,
    required this.loyaltyCardId,
    required this.businessId,
    required this.businessName,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CardHistoryScreen> createState() => _CardHistoryScreenState();
}

class _CardHistoryScreenState extends ConsumerState<CardHistoryScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(cardHistoryProvider.notifier).init(widget.loyaltyCardId, widget.businessId);
  }

  Future<void> _selectDateRange(DateTimeRange? currentRange) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.black,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      ref.read(cardHistoryProvider.notifier).updateDateRange(pickedRange);
    }
  }

  /// Solo se transfiere un premio que aún no se reclamó (HU-04): uno
  /// entregado o rechazado ya no tiene sentido transferirlo.
  bool _canTransfer(Map<String, dynamic> reward) =>
      (reward['status'] ?? 'pending') == 'pending';

  void _openTransferSheet(Map<String, dynamic> reward) {
    ref.read(cardHistoryProvider.notifier).clearTransferState();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _TransferSheet(
        rewardId: reward['id'] as String,
        onTransferred: (message) => messenger.showSnackBar(SnackBar(content: Text(message))),
      ),
    );
  }

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardHistoryProvider);
    final range = state.dateRange;
    final card = state.card;
    final name = card['name']?.toString().trim().isNotEmpty == true
        ? card['name'].toString()
        : widget.businessName;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        body: AppResponsiveBody(
          adaptive: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Builder(
                builder: (context) {
                  final tabs = DefaultTabController.of(context);
                  return RefreshIndicator(
                    color: AppColors.black,
                    edgeOffset: MediaQuery.paddingOf(context).top + 110,
                    onRefresh: () => ref.read(cardHistoryProvider.notifier).loadHistory(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // La cabecera con los datos del local y su avance.
                        SliverToBoxAdapter(
                          child: _CardHeader(
                            name: name,
                            logoUrl: card['logo_url']?.toString(),
                            subtitle: _subtitle(card),
                            points: (card['current_points'] as num?)?.toInt() ?? 0,
                            required: (card['points_required'] as num?)?.toInt() ?? 10,
                            reward: card['reward_description']?.toString().trim() ?? '',
                            fidely: FidelyInfo.fromMap(card),
                            hasData: card.isNotEmpty,
                            range: range,
                            rangeLabel: range == null
                                ? null
                                : '${_formatDay(range.start)} - ${_formatDay(range.end)}',
                            onFilter: () => _selectDateRange(range),
                            onClearFilter: () =>
                                ref.read(cardHistoryProvider.notifier).updateDateRange(null),
                          ),
                        ),
                        // Las pestañas se quedan fijas arriba al desplazar.
                        const SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedTabs(labels: ['Premios', 'Tarjetas', 'Minijuegos']),
                        ),
                        AnimatedBuilder(
                          animation: tabs,
                          builder: (context, _) => _tabContent(state, tabs.index),
                        ),
                        // Espacio extra abajo para que el botón flotante no tape
                        // el último movimiento de la lista.
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  );
                },
              ),
              // Sugerencia o reclamo: un botón flotante en la esquina, sin
              // texto, para no competir con las pestañas ni con el historial.
              Positioned(
                right: 24,
                bottom: 24,
                child: _FeedbackButton(
                  onPressed: () => showFeedbackSheet(
                    context,
                    businessId: widget.businessId,
                    businessName: widget.businessName,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Cafetería · Av. 12 de Octubre N24, Quito": la categoría y dónde queda.
  String? _subtitle(Map<String, dynamic> card) {
    final parts = [card['category'], card['address']]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// El contenido de la pestaña elegida, como sliver.
  Widget _tabContent(CardHistoryState state, int tab) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return switch (tab) {
      CardHistoryScreen.rewardsTab => _itemsSliver(
          state,
          state.rewards,
          emptyTitle: 'Sin premios',
          emptyMessage: 'Cuando completes la tarjeta, tu premio aparecerá aquí.',
          tileBuilder: (item) => _RewardTile(
            item: item,
            onTransfer: _canTransfer(item) ? () => _openTransferSheet(item) : null,
          ),
        ),
      CardHistoryScreen.giftCardsTab => _GiftCardsSliver(businessId: widget.businessId),
      _ => _GamesSliver(businessId: widget.businessId),
    };
  }

  Widget _itemsSliver(
    CardHistoryState state,
    List<Map<String, dynamic>> items, {
    required String emptyTitle,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) tileBuilder,
  }) {
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: state.error != null
            ? const AppEmptyState.error(
                message: 'No pudimos cargar tu historial. Desliza hacia abajo o vuelve a intentarlo.',
              )
            : AppEmptyState(title: emptyTitle, message: emptyMessage),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => tileBuilder(items[index])
            .animate(delay: (index.clamp(0, 6) * 60).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic),
      ),
    );
  }
}

/// La pestaña "Tarjetas": las gift cards que este local le dio al cliente.
class _GiftCardsSliver extends ConsumerWidget {
  final String businessId;

  const _GiftCardsSliver({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(myClaimsProvider);

    return claims.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState.error(message: 'No pudimos cargar tus gift cards. Desliza para reintentar.'),
      ),
      data: (all) {
        final mine = claimsOfBusiness(all, businessId);
        if (mine.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'Sin gift cards',
              message: 'Cuando este local te regale una gift card, aparecerá aquí.',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          sliver: SliverList.separated(
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) => GiftClaimTile(
              claim: mine[index],
              onTap: () async {
                final campaign = mine[index].campaign;
                if (campaign == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CampaignDetailScreen(campaign: campaign, claim: mine[index]),
                  ),
                );
                ref.invalidate(myClaimsProvider);
              },
            )
                .animate(delay: (index.clamp(0, 6) * 60).ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}

/// La pestaña "Minijuegos": los juegos que este local le mandó al cliente.
class _GamesSliver extends ConsumerWidget {
  final String businessId;

  const _GamesSliver({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myGameInvitesProvider);

    return invites.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState.error(message: 'No pudimos cargar tus minijuegos. Desliza para reintentar.'),
      ),
      data: (all) {
        final mine = invitesOfBusiness(all, businessId);
        if (mine.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'Sin minijuegos',
              message: 'Cuando este local te mande un juego para ganar un premio, aparecerá aquí.',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          sliver: SliverList.separated(
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => GameInviteTile(
              invite: mine[index],
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GameInviteScreen(inviteId: mine[index].id)),
                );
                ref.invalidate(myGameInvitesProvider);
                ref.invalidate(myClaimsProvider);
              },
            )
                .animate(delay: (index.clamp(0, 6) * 60).ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}

/// Las pestañas (Premios, Tarjetas, Minijuegos), fijas bajo la cabecera.
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  final List<String> labels;

  const _PinnedTabs({required this.labels});

  static const double _height = 64;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppColors.white,
      child: Align(
        alignment: Alignment.center,
        child: AppPillTabBar(labels: labels),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabs oldDelegate) => oldDelegate.labels != labels;
}

/// La cabecera de la tarjeta de un local: una franja rosa con el logo del
/// negocio, su nombre y dónde queda, y debajo sus sellos (el premio va en el
/// mensaje de la tarjeta de sellos).
class _CardHeader extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final String? subtitle;
  final int points;
  final int required;
  final String reward;

  /// Su insignia FidelyUsuario en este local (o cuánto le falta).
  final FidelyInfo fidely;

  /// Si ya llegaron los datos de la tarjeta (antes solo se sabe el nombre).
  final bool hasData;
  final DateTimeRange? range;
  final String? rangeLabel;
  final VoidCallback onFilter;
  final VoidCallback onClearFilter;

  const _CardHeader({
    required this.name,
    required this.logoUrl,
    required this.subtitle,
    required this.points,
    required this.required,
    required this.reward,
    required this.fidely,
    required this.hasData,
    required this.range,
    required this.rangeLabel,
    required this.onFilter,
    required this.onClearFilter,
  });

  static const double _logoSize = 88;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final image = imageProviderFromUrl(logoUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // La franja rosa: volver y filtrar por fechas.
            Container(
              height: topInset + 112,
              padding: EdgeInsets.fromLTRB(8, topInset + 8, 8, 0),
              decoration: const BoxDecoration(
                color: AppColors.pink,
                border: Border(bottom: BorderSide(color: AppColors.black, width: 1.5)),
              ),
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('Volver'),
                    icon: const Icon(Icons.chevron_left_rounded, size: 40, color: AppColors.black),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr('Filtrar por fechas'),
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.black,
                      size: range == null ? 26 : 22,
                    ),
                    style: range == null
                        ? null
                        : IconButton.styleFrom(backgroundColor: AppColors.white),
                    onPressed: onFilter,
                  ),
                ],
              ),
            ),
            // El logo del negocio, montado sobre el borde de la franja.
            Positioned(
              left: 24,
              bottom: -_logoSize / 2,
              child: Container(
                width: _logoSize,
                height: _logoSize,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.black, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: image == null
                    ? const Icon(Icons.storefront_outlined, color: AppColors.black, size: 34)
                    : Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
        SizedBox(height: _logoSize / 2 + 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 32),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 14, weight: FontWeight.w300, color: AppColors.textSecondary),
                ),
              ],
              if (rangeLabel != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppChip(label: rangeLabel!, icon: Icons.filter_alt_outlined),
                    IconButton(
                      tooltip: context.tr('Quitar filtro'),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: onClearFilter,
                    ),
                  ],
                ),
              ],
              if (hasData) ...[
                const SizedBox(height: 16),
                // Al entrar al local: su insignia FidelyUsuario o cuánto le falta.
                FidelyStatusCard(info: fidely, businessName: name),
                const SizedBox(height: 12),
                _StampsCard(points: points, required: required, reward: reward),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// "TUS SELLOS": un círculo por cada punto; el último es el premio.
class _StampsCard extends StatelessWidget {
  final int points;
  final int required;
  final String reward;

  const _StampsCard({required this.points, required this.required, required this.reward});

  /// A partir de aquí los círculos no caben bien y se usa una barra.
  static const int maxStamps = 12;

  @override
  Widget build(BuildContext context) {
    final total = required < 1 ? 1 : required;
    final done = points.clamp(0, total);
    final left = total - done;

    final String message;
    if (left == 0) {
      message = reward.isEmpty ? '¡Tu premio está listo!' : '¡Tu premio está listo: $reward!';
    } else if (left == 1) {
      message = reward.isEmpty ? 'Te falta 1 punto para tu premio' : 'Un punto más y consigues: $reward';
    } else {
      message = reward.isEmpty ? 'Te faltan $left puntos para tu premio' : 'Te faltan $left puntos para: $reward';
    }

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('TUS SELLOS', style: AppTypography.label(size: 12, tracking: 3))),
              Text('$done / $total', style: AppTypography.display(size: 22)),
            ],
          ),
          const SizedBox(height: 14),
          if (total > maxStamps)
            ProgressBar(value: done / total, height: 14)
          else
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: total <= 4 ? total : (total <= 8 ? 4 : 6),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 0; i < total; i++)
                  Center(
                    child: _Stamp(
                      key: ValueKey(i < done ? 'sello-$i-ganado' : 'sello-$i-falta'),
                      filled: i < done,
                      isPrize: i == total - 1 && left > 0,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}

/// Un sello: ganado (rosa con visto), por ganar (vacío) o el premio (regalo
/// con el borde punteado).
class _Stamp extends StatelessWidget {
  final bool filled;
  final bool isPrize;

  const _Stamp({super.key, required this.filled, required this.isPrize});

  static const double size = 38;

  @override
  Widget build(BuildContext context) {
    if (isPrize) {
      return CustomPaint(
        painter: _DashedCirclePainter(),
        child: const SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.card_giftcard_rounded, size: 20, color: AppColors.black),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? AppColors.pink : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: filled ? const Icon(Icons.check_rounded, size: 21, color: AppColors.black) : null,
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final radius = size.width / 2 - 0.6;
    final center = Offset(size.width / 2, size.height / 2);
    const dashes = 14;
    const sweep = 2 * 3.1415926535 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Botón flotante de "Sugerencia o reclamo": un círculo rosa con el ícono de
/// conversación. Va en la esquina inferior y no lleva texto para no cargar la
/// pantalla; el tooltip explica qué hace.
class _FeedbackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FeedbackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sugerencia o reclamo',
      excludeSemantics: true,
      child: Tooltip(
        message: context.tr('Sugerencia o reclamo'),
        child: Material(
          color: AppColors.pink,
          shape: CircleBorder(side: BorderSide(color: AppColors.black, width: 1.4)),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.black,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo gris con el icono del movimiento.
class _TileIcon extends StatelessWidget {
  final IconData icon;

  const _TileIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
      child: Icon(icon, size: 24, color: AppColors.black),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTransfer;

  const _RewardTile({required this.item, this.onTransfer});

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'pending').toString();
    final title = (item['businesses']?['reward_description'] ?? item['reward_description'] ?? 'Premio')
        .toString();
    final description = item['description']?.toString();

    final AppChip chip;
    String? note;
    switch (status) {
      case 'approved':
      case 'claimed':
        chip = const AppChip(label: 'Entregado', style: AppChipStyle.dark);
      case 'rejected':
        chip = const AppChip(label: 'Rechazado', style: AppChipStyle.outline);
      default:
        chip = const AppChip(label: 'Por reclamar');
        note = 'Muéstralo en el local para reclamarlo.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TileIcon(Icons.card_giftcard_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: AppTypography.display(size: 22)),
                    if (description != null &&
                        description.isNotEmpty &&
                        description.toLowerCase() != title.toLowerCase())
                      Text(
                        description,
                        style: AppTypography.body(size: 14, weight: FontWeight.w300),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'GANADO: ${EcuadorDateUtils.formatEcuadorTime(item['earned_at']).toUpperCase()}',
                      style: AppTypography.body(
                        size: 11,
                        weight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
          ],
          if (onTransfer != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTransfer,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('TRANSFERIR A UN AMIGO'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black, width: 1.2),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: AppTypography.label(size: 11, tracking: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja inferior para transferir un premio por correo. Es un widget propio
/// para que el controlador y la clave del formulario se liberen con ella.
class _TransferSheet extends ConsumerStatefulWidget {
  final String rewardId;
  final void Function(String message) onTransferred;

  const _TransferSheet({required this.rewardId, required this.onTransferred});

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareAppLink() async {
    const message =
        '¡Descarga Fidelity! Tu amigo te transferirá un premio. Descarga aquí: https://fidelity.app/download';
    // ignore: deprecated_member_use
    await Share.share(message);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(cardHistoryProvider.notifier)
        .transferReward(widget.rewardId, _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardHistoryProvider);

    ref.listen<CardHistoryState>(cardHistoryProvider, (prev, next) {
      if (prev?.transferSuccessMessage == null && next.transferSuccessMessage != null) {
        Navigator.of(context).pop();
        widget.onTransferred(next.transferSuccessMessage!);
      }
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'TRANSFERIR PREMIO',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el correo de tu amigo para transferirle este premio.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 15, weight: FontWeight.w300),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _emailController,
                  hint: 'Correo del destinatario',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: AppValidators.validateEmail,
                ),
                if (state.transferErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.pink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.transferErrorMessage!,
                          style: AppTypography.body(size: 14, weight: FontWeight.w500),
                        ),
                        if (state.showInviteButton) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _shareAppLink,
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('INVITAR A UN AMIGO'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.black,
                              side: const BorderSide(color: AppColors.black, width: 1.2),
                              shape: const StadiumBorder(),
                              textStyle: AppTypography.label(size: 11, tracking: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Transferir',
                  isLoading: state.isTransferLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 4),
                Center(
                  child: AppTextAction(
                    label: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
