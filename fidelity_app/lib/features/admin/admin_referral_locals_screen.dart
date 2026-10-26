import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../referrals/data/referrals_repository.dart';
import 'widgets/admin_widgets.dart';

/// Invitar amigos: el administrador elige en qué locales los clientes pueden
/// usar sus puntos de invitación. Un local sin marcar no aparece en la lista
/// que ven los clientes.
class AdminReferralLocalsScreen extends ConsumerStatefulWidget {
  const AdminReferralLocalsScreen({super.key});

  @override
  ConsumerState<AdminReferralLocalsScreen> createState() => _AdminReferralLocalsScreenState();
}

class _AdminReferralLocalsScreenState extends ConsumerState<AdminReferralLocalsScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  /// Los cambios que se acaban de hacer (se ven al instante, antes de recargar).
  final Map<String, bool> _pending = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isEnabled(ReferralAdminBusiness b) => _pending[b.id] ?? b.enabled;

  Future<void> _toggle(ReferralAdminBusiness b, bool value) async {
    setState(() => _pending[b.id] = value);
    try {
      await ref.read(referralsRepositoryProvider).setBusiness(b.id, value);
      ref.invalidate(referralAdminBusinessesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(b.id));
      DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  /// Marca o desmarca todos los locales que se ven (según la búsqueda).
  Future<void> _setAll(List<ReferralAdminBusiness> visible, bool value) async {
    final ids = [for (final b in visible) if (_isEnabled(b) != value) b.id];
    if (ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        _pending[id] = value;
      }
    });
    try {
      await ref.read(referralsRepositoryProvider).setMany(ids, value);
      ref.invalidate(referralAdminBusinessesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final id in ids) {
          _pending.remove(id);
        }
      });
      DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(referralAdminBusinessesProvider);
    final all = async.valueOrNull ?? const <ReferralAdminBusiness>[];
    final term = _search.trim().toLowerCase();
    final visible = [for (final b in all) if (term.isEmpty || b.name.toLowerCase().contains(term)) b];
    final selected = all.where(_isEnabled).length;

    return AdminPageFrame(
      title: 'Locales de invitaciones',
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async {
          _pending.clear();
          ref.invalidate(referralAdminBusinessesProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elige en qué locales pueden los clientes usar sus puntos de invitación. '
                      'Los que no marques no aparecen para ellos.',
                      style: AppTypography.body(size: 14, weight: FontWeight.w300),
                    ),
                    const SizedBox(height: 12),
                    AdminSearchField(
                      controller: _searchController,
                      hint: 'Buscar local',
                      onChanged: (value) => setState(() => _search = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$selected de ${all.length} locales participan',
                            style: AppTypography.label(size: 12, tracking: 2),
                          ),
                        ),
                        TextButton(
                          onPressed: visible.isEmpty ? null : () => _setAll(visible, true),
                          child: const Text('Marcar todos'),
                        ),
                        TextButton(
                          onPressed: visible.isEmpty ? null : () => _setAll(visible, false),
                          child: const Text('Quitar todos'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (async.isLoading && all.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (async.hasError && all.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState.error(message: 'No pudimos cargar los locales. Desliza para reintentar.'),
              )
            else if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(title: 'Sin resultados', message: 'No hay locales activos con ese nombre.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _BusinessRow(
                    business: visible[i],
                    enabled: _isEnabled(visible[i]),
                    onChanged: (value) => _toggle(visible[i], value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BusinessRow extends StatelessWidget {
  final ReferralAdminBusiness business;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _BusinessRow({required this.business, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(business.logoUrl);

    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: enabled ? AppColors.pink : null,
      onTap: () => onChanged(!enabled),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.storefront_outlined, size: 22)
                : Padding(padding: const EdgeInsets.all(6), child: Image(image: image, fit: BoxFit.contain)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 16, weight: FontWeight.w600),
                ),
                if ((business.category ?? '').isNotEmpty)
                  Text(
                    business.category!,
                    style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeTrackColor: AppColors.black,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
