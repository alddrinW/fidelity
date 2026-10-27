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
import '../../../core/l10n/translator.dart';

/// "Mis negocios": todos los negocios y sucursales del dueño. Cada negocio principal
/// es una tarjeta negra y sus sucursales cuelgan de él con una línea rosa. Desde aquí
/// cambia de negocio, paga una sucursal nueva, agrega sucursales y gestiona el equipo.
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

    Widget card(BusinessOverview business, int index, {required bool hero}) {
      void team() => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeamScreen(businessId: business.id, businessName: business.name),
            ),
          );
      final isCurrent = business.id == currentId;
      final child = hero
          ? _PrincipalCard(
              business: business,
              isCurrent: isCurrent,
              onSelect: () => _select(context, ref, business),
              onPay: () => _pay(context, ref, business),
              onEdit: () => _edit(context, ref, business),
              onTeam: team,
            )
          : _BranchCard(
              business: business,
              isCurrent: isCurrent,
              onSelect: () => _select(context, ref, business),
              onPay: () => _pay(context, ref, business),
              onEdit: () => _edit(context, ref, business),
              onTeam: team,
            );
      return child.animate(delay: (40 * (index % 8)).ms).fadeIn().slideY(begin: 0.06);
    }

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
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            children: _groups(list, card),
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

  /// Cada negocio principal en su tarjeta negra y, debajo, sus sucursales colgando de
  /// él. Una sucursal cuyo principal no está en la lista sale suelta, al final.
  List<Widget> _groups(
    List<BusinessOverview> list,
    Widget Function(BusinessOverview business, int index, {required bool hero}) card,
  ) {
    final principals = list.where((b) => !b.isBranch).toList();
    final ids = principals.map((b) => b.id).toSet();
    final orphans = list.where((b) => b.isBranch && !ids.contains(b.parentId)).toList();

    final widgets = <Widget>[];
    var index = 0;
    for (final principal in principals) {
      final branches = list.where((b) => b.parentId == principal.id).toList();
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 28));
      widgets.add(card(principal, index++, hero: true));
      if (branches.isNotEmpty) {
        widgets.add(_BranchesHeader(count: branches.length));
        for (var i = 0; i < branches.length; i++) {
          widgets.add(_BranchTreeRow(
            isLast: i == branches.length - 1,
            child: card(branches[i], index++, hero: false),
          ));
        }
      }
    }
    if (orphans.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 28));
      for (final b in orphans) {
        widgets.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: card(b, index++, hero: false)));
      }
    }
    return widgets;
  }
}

/// "SUCURSALES ─────── 2": separa al negocio principal de lo que cuelga de él.
class _BranchesHeader extends StatelessWidget {
  final int count;

  const _BranchesHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text('SUCURSALES', style: AppTypography.label(size: 11, tracking: 3)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.black.withValues(alpha: 0.15))),
          const SizedBox(width: 10),
          Text('$count', style: AppTypography.label(size: 11, tracking: 1, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Una sucursal en el árbol: a la izquierda, la línea rosa que viene del negocio
/// principal y un punto que marca dónde cuelga la tarjeta.
class _BranchTreeRow extends StatelessWidget {
  final bool isLast;
  final Widget child;

  const _BranchTreeRow({required this.isLast, required this.child});

  /// A qué altura de la tarjeta está el punto (junto al nombre).
  static const double _dotTop = 30;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Stack(
              children: [
                // La línea baja hasta la última sucursal y ahí se corta en el punto.
                Positioned(
                  left: 5,
                  top: 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? _dotTop + 6 : null,
                  width: 2,
                  child: const ColoredBox(color: AppColors.pink),
                ),
                Positioned(
                  left: 0,
                  top: _dotTop,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.black, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// El logo del local (o una tiendita si no tiene) en un círculo.
class _Logo extends StatelessWidget {
  final BusinessOverview business;
  final double size;
  final bool onDark;

  const _Logo({required this.business, required this.size, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final logo = imageProviderFromUrl(business.logoUrl);
    final fallbackBackground = onDark ? AppColors.white : AppColors.black;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logo == null ? fallbackBackground : AppColors.white,
        shape: BoxShape.circle,
        image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover),
      ),
      child: logo == null
          ? Icon(Icons.storefront_outlined, size: size * 0.5, color: onDark ? AppColors.black : AppColors.white)
          : null,
    );
  }
}

/// Las etiquetas de un local: "Actual" y "Por activar".
class _Badges extends StatelessWidget {
  final BusinessOverview business;
  final bool isCurrent;
  final bool onDark;

  const _Badges({required this.business, required this.isCurrent, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    if (!isCurrent && business.isActive) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (isCurrent)
            onDark ? const _PinkChip(label: 'Actual') : const AppChip(label: 'Actual', style: AppChipStyle.dark),
          if (!business.isActive) const AppChip(label: 'Por activar'),
        ],
      ),
    );
  }
}

/// "Actual" sobre la tarjeta negra: rosa con letra negra.
class _PinkChip extends StatelessWidget {
  final String label;

  const _PinkChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(99)),
      child: Text(label.toUpperCase(), style: AppTypography.label(size: 10, tracking: 1.5)),
    );
  }
}

/// El negocio principal: una tarjeta negra con sus cifras en rosa.
class _PrincipalCard extends StatelessWidget {
  final BusinessOverview business;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onTeam;

  const _PrincipalCard({
    required this.business,
    required this.isCurrent,
    required this.onSelect,
    required this.onPay,
    required this.onEdit,
    required this.onTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Logo(business: business, size: 56, onDark: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(size: 26, color: AppColors.white),
                    ),
                    _Badges(business: business, isCurrent: isCurrent, onDark: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.white.withValues(alpha: 0.18))),
            ),
            child: Row(
              children: [
                _Metric(label: 'Clientes', value: business.customers, onDark: true),
                _Metric(label: 'Hoy', value: business.scansToday, onDark: true),
                _Metric(label: 'Pendientes', value: business.pendingScans, onDark: true),
                _Metric(label: 'Equipo', value: business.approvers, onDark: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!business.isActive) ...[
            _Cta(label: 'Paga ya', onTap: onPay, onDark: true),
            const SizedBox(height: 12),
          ] else if (!isCurrent) ...[
            _Cta(label: 'Usar este negocio', onTap: onSelect, onDark: true),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _ActionPill(icon: Icons.groups_2_outlined, label: 'Mi equipo', onTap: onTeam, onDark: true)),
              const SizedBox(width: 10),
              Expanded(child: _ActionPill(icon: Icons.edit_outlined, label: 'Editar', onTap: onEdit, onDark: true)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una sucursal: tarjeta chica con el nombre, las cifras en una línea y sus acciones.
class _BranchCard extends StatelessWidget {
  final BusinessOverview business;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onTeam;

  const _BranchCard({
    required this.business,
    required this.isCurrent,
    required this.onSelect,
    required this.onPay,
    required this.onEdit,
    required this.onTeam,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Logo(business: business, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(size: 19),
                    ),
                    _Badges(business: business, isCurrent: isCurrent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Las cifras, juntas en una sola franja (la letra se achica si no caben).
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _Metric(label: 'Clientes', value: business.customers, compact: true),
                _Metric(label: 'Hoy', value: business.scansToday, compact: true),
                _Metric(label: 'Pendientes', value: business.pendingScans, compact: true),
                _Metric(label: 'Equipo', value: business.approvers, compact: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: !business.isActive
                    ? _Cta(label: 'Paga ya', onTap: onPay)
                    : isCurrent
                        ? const SizedBox.shrink()
                        : _Cta(label: 'Usar este negocio', onTap: onSelect),
              ),
              if (!business.isActive || !isCurrent) const SizedBox(width: 8),
              _IconAction(icon: Icons.groups_2_outlined, tooltip: 'Mi equipo', onTap: onTeam),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.edit_outlined, tooltip: 'Editar', onTap: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}

/// El botón principal de un local: rosa sobre la tarjeta negra, negro sobre blanco.
class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool onDark;

  const _Cta({required this.label, required this.onTap, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onDark ? AppColors.pink : AppColors.black,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: onDark ? 52 : 44,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  style: AppTypography.label(size: 12, tracking: 2, color: onDark ? AppColors.black : AppColors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Acción secundaria de la tarjeta negra: píldora con borde blanco.
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool onDark;

  const _ActionPill({required this.icon, required this.label, required this.onTap, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final color = onDark ? AppColors.white : AppColors.black;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color, width: 1.2)),
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
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      style: AppTypography.label(size: 12, tracking: 2, color: color),
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

/// Acción de una sucursal que solo lleva el ícono (con su nombre para lectores de pantalla).
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr(tooltip),
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.black, width: 1.2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: AppColors.black)),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  /// Sobre la tarjeta negra: número rosa y etiqueta clara.
  final bool onDark;

  /// En la franja de una sucursal: números más chicos.
  final bool compact;

  const _Metric({required this.label, required this.value, this.onDark = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: AppTypography.display(size: compact ? 22 : 30, color: onDark ? AppColors.pink : AppColors.black),
          ),
          const SizedBox(height: 2),
          // Una sola línea siempre: si no cabe, la letra se achica en vez de partirse.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: AppTypography.label(
                  size: 10,
                  tracking: 1,
                  color: onDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
