import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../../auth/data/auth_repository.dart';
import '../../payments/data/payments_repository.dart';
import '../../payments/paga_ya_screen.dart';
import '../create_business_screen.dart';
import '../dashboard/widgets/dashboard_animated_toast.dart';
import '../profile/business_profile_screen.dart';
import '../team/team_screen.dart';
import 'branches_repository.dart';
import '../../../core/l10n/tr_text.dart';

/// "Mis negocios": matriz de control de todos los negocios y sucursales del
/// dueño. Desde aquí cambia de negocio, paga una sucursal nueva, agrega
/// sucursales y gestiona el equipo de cada local.
class MyBusinessesScreen extends ConsumerWidget {
  const MyBusinessesScreen({super.key});

  Future<void> _select(BuildContext context, WidgetRef ref, BusinessOverview business) async {
    await ref.read(authRepositoryProvider).selectBusiness(business.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Edita el local: su logo, sus datos y su campaña.
  Future<void> _edit(BuildContext context, WidgetRef ref, BusinessOverview business) async {
    try {
      final businesses = await ref.read(authRepositoryProvider).myBusinesses();
      if (!context.mounted) return;
      final data = businesses.firstWhere(
        (b) => b['id']?.toString() == business.id,
        orElse: () => {'id': business.id, 'name': business.name},
      );
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => BusinessProfileScreen(business: data)),
      );
      if (changed == true) ref.invalidate(businessOverviewProvider);
    } catch (e) {
      if (context.mounted) {
        DashboardAnimatedToast.show(context, e.toString(), isError: true);
      }
    }
  }

  /// Un negocio sin activar se activa pagando: abre el asistente PAGA YA.
  Future<void> _pay(BuildContext context, WidgetRef ref, BusinessOverview business) async {
    try {
      final order = await ref.read(paymentsRepositoryProvider).ensureOrder(business.id);
      if (!context.mounted) return;
      final reported = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PagaYaScreen(order: order)),
      );
      if (reported == true) ref.invalidate(businessOverviewProvider);
    } catch (e) {
      if (context.mounted) {
        DashboardAnimatedToast.show(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _addBranch(
    BuildContext context,
    WidgetRef ref,
    List<BusinessOverview> all,
  ) async {
    final principals = all.where((b) => !b.isBranch).toList();
    if (principals.isEmpty) return;

    BusinessOverview? parent = principals.first;
    if (principals.length > 1) {
      parent = await showModalBottomSheet<BusinessOverview>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('SUCURSAL DE…', style: AppTypography.display(size: 26)),
              ),
              for (final p in principals)
                ListTile(
                  title: Text(p.name, style: AppTypography.body(size: 17)),
                  onTap: () => Navigator.of(sheetContext).pop(p),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
    if (parent == null || !context.mounted) return;

    // El formulario de sucursal parte de los datos del negocio principal.
    final businesses = await ref.read(authRepositoryProvider).myBusinesses();
    final parentData = businesses.firstWhere(
      (b) => b['id']?.toString() == parent!.id,
      orElse: () => {'id': parent!.id, 'name': parent.name},
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateBusinessScreen(parent: parentData)),
    );
    ref.invalidate(businessOverviewProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(businessOverviewProvider);
    final currentId = ref.watch(authRepositoryProvider).currentUser?.businessId;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          maxWidth: 640,
          child: Column(
            children: [
              const AppPageHeader(title: 'Mis negocios'),
              Expanded(
                child: overview.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.black),
                  ),
                  error: (e, _) => const AppEmptyState.error(message: 'No pudimos cargar tus negocios. Desliza para reintentar.',
                  ),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          title: 'Sin negocios',
                          message: 'Aquí verás tus negocios y sucursales.',
                        )
                      : RefreshIndicator(
                          color: AppColors.black,
                          onRefresh: () async => ref.invalidate(businessOverviewProvider),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final business = list[index];
                              return _BranchFrame(
                                isBranch: business.isBranch,
                                child: _BusinessCard(
                                  business: business,
                                  isCurrent: business.id == currentId,
                                  onSelect: () => _select(context, ref, business),
                                  onPay: () => _pay(context, ref, business),
                                  onEdit: () => _edit(context, ref, business),
                                  onTeam: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TeamScreen(
                                        businessId: business.id,
                                        businessName: business.name,
                                      ),
                                    ),
                                  ),
                                ).animate(delay: (40 * (index % 8)).ms).fadeIn().slideY(begin: 0.06),
                              );
                            },
                          ),
                        ),
                ),
              ),
              if (overview.hasValue && overview.value!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: AppPrimaryButton(
                    label: 'Agregar sucursal',
                    onPressed: () => _addBranch(context, ref, overview.value!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una sucursal cuelga de su negocio con una línea rosa a la izquierda, sin
/// encogerse: así la tarjeta conserva el ancho que necesitan sus datos.
class _BranchFrame extends StatelessWidget {
  final bool isBranch;
  final Widget child;

  const _BranchFrame({required this.isBranch, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isBranch) return child;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.pink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final BusinessOverview business;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onTeam;

  const _BusinessCard({
    required this.business,
    required this.isCurrent,
    required this.onSelect,
    required this.onPay,
    required this.onEdit,
    required this.onTeam,
  });

  @override
  Widget build(BuildContext context) {
    final logo = imageProviderFromUrl(business.logoUrl);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: logo == null ? AppColors.black : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover),
                ),
                child: logo == null
                    ? const Icon(Icons.storefront_outlined, color: AppColors.white)
                    : null,
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
                      style: AppTypography.display(size: 24),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isCurrent) const AppChip(label: 'Actual', style: AppChipStyle.dark),
                        if (business.isBranch)
                          const AppChip(label: 'Sucursal', style: AppChipStyle.outline),
                        if (!business.isActive) const AppChip(label: 'Por activar'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(22),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Metric(label: 'Clientes', value: business.customers),
                  const _MetricDivider(),
                  _Metric(label: 'Hoy', value: business.scansToday),
                  const _MetricDivider(),
                  _Metric(label: 'Pendientes', value: business.pendingScans),
                  const _MetricDivider(),
                  _Metric(label: 'Equipo', value: business.approvers),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!business.isActive) ...[
            AppPrimaryButton(label: 'Paga ya', onPressed: onPay),
            const SizedBox(height: 12),
          ] else if (!isCurrent) ...[
            AppPrimaryButton(label: 'Usar este negocio', onPressed: onSelect),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _ActionPill(icon: Icons.groups_2_outlined, label: 'Mi equipo', onTap: onTeam),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(icon: Icons.edit_outlined, label: 'Editar', onTap: onEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Acción secundaria de la tarjeta: píldora con borde, sin competir con el
/// botón principal.
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.black, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: AppColors.black),
                    const SizedBox(width: 8),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      style: AppTypography.label(size: 12, tracking: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: AppColors.black.withValues(alpha: 0.12),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: AppTypography.display(size: 28)),
          const SizedBox(height: 2),
          // Una sola línea siempre: si no cabe, la letra se achica en vez de partirse.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: AppTypography.label(size: 10, tracking: 1, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
