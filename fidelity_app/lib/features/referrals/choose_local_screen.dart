import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../cards/providers/my_cards_provider.dart';
import 'data/referrals_repository.dart';
import 'points_text.dart';

/// Elegir en qué local usar los puntos de invitación: solo salen los locales
/// que el administrador marcó como participantes. Se puede usar un punto, o
/// varios de una vez, en el local elegido.
class ChooseLocalScreen extends ConsumerWidget {
  const ChooseLocalScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, ReferralLocal local, int balance) async {
    final used = await showModalBottomSheet<ReferralUsed>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => UsePointsSheet(local: local, balance: balance, repository: ref.read(referralsRepositoryProvider)),
    );
    if (used == null) return;

    ref.invalidate(referralInfoProvider);
    ref.invalidate(referralLocalsProvider);
    // Su tarjeta de ese local ya tiene los puntos nuevos.
    ref.read(myCardsProvider.notifier).refreshCards();
    if (!context.mounted) return;

    final prize = used.newRewards > 0 ? ' ¡Ganaste un premio!' : '';
    DashboardAnimatedToast.show(context, '¡Listo! Sumaste ${pointsText(used.used)} en ${used.businessName}.$prize');
    // Sin puntos por usar, no hay nada más que elegir.
    if (used.balance <= 0) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locals = ref.watch(referralLocalsProvider);
    final balance = ref.watch(referralInfoProvider).valueOrNull?.balance ?? 0;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Elegir local'),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tienes ${pointsText(balance)} de invitación. Toca el local donde quieres usarlos.',
                    style: AppTypography.body(size: 15, weight: FontWeight.w300),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.black,
                  onRefresh: () async => ref.invalidate(referralLocalsProvider),
                  child: locals.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
                    error: (_, __) => ListView(children: const [
                      SizedBox(
                        height: 360,
                        child: AppEmptyState.error(message: 'No pudimos cargar los locales. Desliza para reintentar.'),
                      ),
                    ]),
                    data: (list) => list.isEmpty
                        ? ListView(children: const [
                            SizedBox(
                              height: 360,
                              child: AppEmptyState(
                                title: 'Aún no hay locales',
                                message:
                                    'Todavía no hay locales donde usar tus puntos de invitación. Tus puntos se guardan: vuelve pronto.',
                              ),
                            ),
                          ])
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) => _LocalTile(
                              local: list[i],
                              onTap: balance > 0 ? () => _pick(context, ref, list[i], balance) : null,
                            ).animate(delay: (40 * (i % 8)).ms).fadeIn().slideY(begin: 0.05),
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

class _LocalTile extends StatelessWidget {
  final ReferralLocal local;
  final VoidCallback? onTap;

  const _LocalTile({required this.local, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(local.logoUrl);
    final mine = local.currentPoints;

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.storefront_outlined, color: AppColors.black, size: 26)
                : Padding(padding: const EdgeInsets.all(8), child: Image(image: image, fit: BoxFit.contain)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  local.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 22),
                ),
                if ((local.category ?? '').isNotEmpty)
                  Text(
                    local.category!,
                    style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 4),
                Text(
                  mine == null
                      ? 'Todavía no tienes tarjeta aquí'
                      : 'Llevas $mine de ${local.pointsRequired} puntos aquí',
                  style: AppTypography.body(size: 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 30),
        ],
      ),
    );
  }
}

/// Confirmar el uso: cuántos puntos y en qué local. Devuelve el resultado.
class UsePointsSheet extends StatefulWidget {
  final ReferralLocal local;
  final int balance;
  final ReferralsRepository repository;

  const UsePointsSheet({super.key, required this.local, required this.balance, required this.repository});

  @override
  State<UsePointsSheet> createState() => _UsePointsSheetState();
}

class _UsePointsSheetState extends State<UsePointsSheet> {
  int _points = 1;
  bool _isSaving = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.use(widget.local.id, points: _points);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.local;
    final after = (local.currentPoints ?? 0) + _points;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(local.name.toUpperCase(), textAlign: TextAlign.center, style: AppTypography.display(size: 28)),
            const SizedBox(height: 8),
            Text(
              local.currentPoints == null
                  ? 'Se creará tu tarjeta en este local con tus puntos de invitación.'
                  : 'Llevas ${local.currentPoints} de ${local.pointsRequired} puntos aquí.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
            if (widget.balance > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    tooltip: context.tr('Menos'),
                    onPressed: _points > 1 && !_isSaving
                        ? () => setState(() {
                              if (_points > 1) _points--;
                            })
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text('$_points', textAlign: TextAlign.center, style: AppTypography.display(size: 40)),
                  ),
                  IconButton.outlined(
                    tooltip: context.tr('Más'),
                    onPressed: _points < widget.balance && !_isSaving
                        ? () => setState(() {
                              if (_points < widget.balance) _points++;
                            })
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              after >= local.pointsRequired
                  ? '¡Con ${pointsText(_points)} completas tu premio!'
                  : 'Tendrás $after de ${local.pointsRequired} puntos',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 14, weight: FontWeight.w600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Usar ${pointsText(_points)} aquí',
              isLoading: _isSaving,
              onPressed: _confirm,
            ),
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
