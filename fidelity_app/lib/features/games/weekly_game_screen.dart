import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import '../cards/providers/my_cards_provider.dart';
import 'data/weekly_game_repository.dart';
import 'game_invite_screen.dart';

/// "Juego de la semana": una vez por semana (de lunes a domingo) el cliente
/// elige en qué negocio quiere ganar su punto y juega. Los negocios donde ya
/// ganó salen bloqueados; si pierde, pierde la semana pero el negocio sigue libre.
class WeeklyGameScreen extends ConsumerStatefulWidget {
  const WeeklyGameScreen({super.key});

  @override
  ConsumerState<WeeklyGameScreen> createState() => _WeeklyGameScreenState();
}

class _WeeklyGameScreenState extends ConsumerState<WeeklyGameScreen> {
  /// El negocio que se está abriendo (para mostrarle su carga).
  String? _opening;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _play(String inviteId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameInviteScreen(inviteId: inviteId)));
    if (!mounted) return;
    // Si ganó, sus puntos cambiaron: se actualizan sus tarjetas y el estado de la semana.
    ref.invalidate(weeklyGameProvider);
    ref.read(myCardsProvider.notifier).refreshCards(silent: true);
  }

  Future<void> _choose(WeeklyBusiness business) async {
    if (_opening != null) return;
    setState(() => _opening = business.id);
    try {
      final inviteId = await ref.read(weeklyGameRepositoryProvider).start(business.id);
      ref.invalidate(weeklyGameProvider);
      if (!mounted) return;
      await _play(inviteId);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(weeklyGameProvider);

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          maxWidth: 560,
          child: Column(
            children: [
              const AppPageHeader(title: 'Juego de la semana'),
              Expanded(
                child: status.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
                  error: (_, __) => const AppEmptyState.error(
                    message: 'No pudimos cargar tu juego de la semana. Desliza para reintentar.',
                  ),
                  data: (s) => RefreshIndicator(
                    color: AppColors.black,
                    onRefresh: () async => ref.invalidate(weeklyGameProvider),
                    child: _body(s),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(WeeklyStatus s) {
    if (s.isOff) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 360,
            child: AppEmptyState(
              title: 'Juego no disponible',
              message: 'El juego de la semana no está disponible por ahora. ¡Vuelve pronto!',
              mood: FidoMood.sad,
            ),
          ),
        ],
      );
    }
    if (s.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 360,
            child: AppEmptyState(
              title: 'Aún no tienes negocios',
              message: 'Escanea el código QR de un negocio y podrás jugar aquí para ganar puntos.',
            ),
          ),
        ],
      );
    }
    if (s.isDone) return _Done(status: s);

    final points = '${s.points} ${s.points == 1 ? 'punto' : 'puntos'}';
    final current = s.current;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        const Center(child: FidoMascot(mood: FidoMood.celebrate, height: 130)),
        const SizedBox(height: 8),
        Text(
          s.isPlaying ? 'TU JUEGO DE LA SEMANA' : 'ELIGE TU NEGOCIO',
          textAlign: TextAlign.center,
          style: AppTypography.display(size: 32),
        ),
        const SizedBox(height: 6),
        Text(
          s.isPlaying
              ? 'Elegiste ${current?.businessName ?? 'un negocio'}: ¡a jugar!'
              : 'Juegas una vez por semana. Si ganas, sumas $points en el negocio que elijas.',
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 15, weight: FontWeight.w300),
        ),
        if (s.isPlaying && current != null) ...[
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: current.status == 'playing' ? 'Seguir jugando' : 'Jugar',
            isLoading: _opening == current.businessId,
            onPressed: () => _play(current.inviteId),
          ),
          if (current.canChange) ...[
            const SizedBox(height: 16),
            Text(
              'O elige otro negocio antes de jugar:',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 14, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          ],
        ],
        const SizedBox(height: 16),
        if (!s.isPlaying || (current?.canChange ?? false))
          for (final business in s.businesses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusinessTile(
                business: business,
                chosen: current?.businessId == business.id,
                loading: _opening == business.id,
                onTap: business.blocked ? null : () => _choose(business),
              ).animate().fadeIn().slideY(begin: 0.05),
            ),
        if (s.businesses.any((b) => b.blocked)) ...[
          const SizedBox(height: 4),
          Text(
            'Los negocios donde ya ganaste no se pueden repetir hasta que hayas ganado en todos.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 12, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Un negocio para elegir: el que ya ganó sale apagado y con un candado.
class _BusinessTile extends StatelessWidget {
  final WeeklyBusiness business;
  final bool chosen;
  final bool loading;
  final VoidCallback? onTap;

  const _BusinessTile({required this.business, required this.chosen, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(business.logoUrl);
    final blocked = business.blocked;

    return Semantics(
      button: !blocked,
      enabled: !blocked,
      label: blocked ? '${business.name}. Ya ganaste aquí' : business.name,
      excludeSemantics: true,
      child: Opacity(
        opacity: blocked ? 0.5 : 1,
        child: AppCard(
          radius: 28,
          padding: const EdgeInsets.all(16),
          color: chosen ? AppColors.pink : (blocked ? AppColors.surfaceMuted : null),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: image == null
                    ? const Icon(Icons.storefront_outlined, size: 26)
                    : Padding(padding: const EdgeInsets.all(7), child: Image(image: image, fit: BoxFit.contain)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(size: 22),
                    ),
                    Text(
                      blocked
                          ? 'Ya ganaste aquí'
                          : 'Llevas ${business.currentPoints} de ${business.pointsRequired} puntos',
                      style: AppTypography.body(size: 13, weight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
              else
                Icon(blocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, size: blocked ? 24 : 30),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ya jugó esta semana: ganó o perdió, y vuelve el lunes.
class _Done extends StatelessWidget {
  final WeeklyStatus status;

  const _Done({required this.status});

  @override
  Widget build(BuildContext context) {
    final current = status.current;
    final won = current?.isWon ?? false;
    final next = status.nextAt;
    final points = '${status.points} ${status.points == 1 ? 'punto' : 'puntos'}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      children: [
        Center(child: FidoMascot(mood: won ? FidoMood.euphoric : FidoMood.sad, height: 150)),
        const SizedBox(height: 8),
        Text(
          won ? '¡GANASTE!' : 'ESTA SEMANA NO',
          textAlign: TextAlign.center,
          style: AppTypography.display(size: 40),
        ),
        const SizedBox(height: 8),
        Text(
          won
              ? 'Sumaste $points en ${current?.businessName ?? 'tu negocio'}.'
              : 'Perdiste tus intentos, pero ${current?.businessName ?? 'ese negocio'} sigue libre para elegirlo otra semana.',
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 16, weight: FontWeight.w300),
        ),
        const SizedBox(height: 20),
        AppCard(
          radius: 28,
          color: AppColors.pink,
          child: Column(
            children: [
              Text('VUELVE EL LUNES', style: AppTypography.label(size: 12, tracking: 3)),
              if (next != null)
                Text(
                  '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}',
                  style: AppTypography.display(size: 40),
                ),
              Text(
                won
                    ? 'Entonces podrás elegir otro negocio.'
                    : 'Entonces podrás jugar de nuevo.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 13, weight: FontWeight.w300),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
