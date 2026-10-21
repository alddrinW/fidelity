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
                              return Padding(
                                padding: EdgeInsets.only(left: business.isBranch ? 24 : 0),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 6),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(label: 'Clientes', value: business.customers),
              _Metric(label: 'Hoy', value: business.scansToday),
              _Metric(label: 'Pendientes', value: business.pendingScans),
              _Metric(label: 'Equipo', value: business.approvers),
            ],
          ),
          const SizedBox(height: 16),
          if (!business.isActive)
            AppPrimaryButton(label: 'Paga ya', onPressed: onPay)
          else if (!isCurrent)
            AppPrimaryButton(label: 'Usar este negocio', onPressed: onSelect),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextAction(label: 'Mi equipo', onPressed: onTeam),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextAction(label: 'Editar este local', onPressed: onEdit),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTypography.display(size: 28)),
          Text(
            label.toUpperCase(),
            style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
