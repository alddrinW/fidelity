import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_chip.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/person_avatar.dart';
import '../../../profile/campaign_settings_screen.dart';
import '../../providers/dashboard_provider.dart';
import '../dashboard_stat_card.dart';
import '../../../../../core/l10n/tr_text.dart';

/// Métricas del negocio: clientes, puntos otorgados, premios ganados y la
/// meta de puntos (que lleva a "Mi campaña" para cambiarla).
class TabStatistics extends ConsumerStatefulWidget {
  const TabStatistics({super.key});

  @override
  ConsumerState<TabStatistics> createState() => _TabStatisticsState();
}

class _TabStatisticsState extends ConsumerState<TabStatistics> {
  void _showCustomersModal(List<Map<String, dynamic>> customers) {
    _showListModal(
      title: 'Lista de clientes',
      items: customers,
      subtitleBuilder: (card) => '${card['total_points_lifetime'] ?? 0} puntos en total',
      trailingBuilder: (card) => Text(
        '${card['current_points'] ?? 0} pts',
        style: AppTypography.label(size: 14, tracking: 1),
      ),
    );
  }

  void _showTopScansModal(List<Map<String, dynamic>> customers) {
    final sorted = List<Map<String, dynamic>>.from(customers)
      ..sort((a, b) => ((b['total_points_lifetime'] ?? 0) as int)
          .compareTo((a['total_points_lifetime'] ?? 0) as int));

    _showListModal(
      title: 'Ranking de puntos',
      items: sorted.where((c) => (c['total_points_lifetime'] ?? 0) > 0).toList(),
      subtitleBuilder: (card) => 'Puntos aprobados en total',
      trailingBuilder: (card) => Text(
        '${card['total_points_lifetime'] ?? 0}',
        style: AppTypography.display(size: 22),
      ),
    );
  }

  void _showRewardsModal(List<Map<String, dynamic>> customers) {
    final sorted = List<Map<String, dynamic>>.from(customers)
      ..sort((a, b) =>
          ((b['rewards_claimed'] ?? 0) as int).compareTo((a['rewards_claimed'] ?? 0) as int));

    _showListModal(
      title: 'Ranking de premios',
      items: sorted.where((c) => (c['rewards_claimed'] ?? 0) > 0).toList(),
      subtitleBuilder: (card) {
        final earned = card['rewards_claimed'] ?? 0;
        final transferred = card['rewards_transferred'] ?? 0;
        return '$earned premios ganados · $transferred transferidos';
      },
      trailingBuilder: (card) => AppChip(
        label: '${card['rewards_claimed'] ?? 0}',
        icon: Icons.card_giftcard_rounded,
      ),
    );
  }

  void _showListModal({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required Widget Function(Map<String, dynamic>) trailingBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title.toUpperCase(), style: AppTypography.display(size: 28)),
                            Text(
                              '${items.length} registros',
                              style: AppTypography.body(
                                size: 14,
                                weight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const AppEmptyState(
                          title: 'Sin registros',
                          message: 'Aún no hay datos para mostrar.',
                          imageHeight: 120,
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final profile = item['profiles'];
                            final name = (profile?['full_name'] ?? 'Usuario').toString();

                            return AppCard(
                              radius: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  PersonAvatar(
                                    name: name,
                                    avatarUrl: profile?['avatar_url']?.toString(),
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name.toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.label(size: 13, tracking: 0.5),
                                              ),
                                            ),
                                            if (profile?['is_demo'] == true) ...[
                                              const SizedBox(width: 8),
                                              const AppChip(
                                                label: 'Demo',
                                                style: AppChipStyle.outline,
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          subtitleBuilder(item),
                                          style: AppTypography.body(
                                            size: 13,
                                            weight: FontWeight.w300,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  trailingBuilder(item),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editCampaign(Map<String, dynamic> business) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CampaignSettingsScreen(business: business)),
    );
    if (saved == true && mounted) {
      ref.read(dashboardProvider.notifier).loadData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final customers = state.customers;
    final business = state.business;

    if (business == null) return const SizedBox();

    final realCustomers = customers.where((c) => c['profiles']?['is_demo'] != true);
    final totalPoints = realCustomers.fold<int>(
      0,
      (sum, card) => sum + ((card['total_points_lifetime'] ?? 0) as int),
    );
    final totalRewards = realCustomers.fold<int>(
      0,
      (sum, card) => sum + ((card['rewards_claimed'] ?? 0) as int),
    );

    final createdAt = EcuadorDateUtils.toEcuadorTime(business['created_at'] ?? '');
    final daysLive = EcuadorDateUtils.nowEcuador().difference(createdAt).inDays;
    final formattedDate =
        "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}";

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INFORMACIÓN DE CAMPAÑA',
                style: AppTypography.label(size: 13, tracking: 3, color: AppColors.white),
              ),
              const SizedBox(height: 18),
              _CampaignRow(label: 'Inicio', value: formattedDate),
              const SizedBox(height: 10),
              _CampaignRow(label: 'Tiempo activo', value: '$daysLive días'),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: 16),
        DashboardStatCard(
          title: 'Clientes',
          value: '${customers.length}',
          icon: Icons.people_outline_rounded,
          subtitle: 'Personas únicas que te visitaron',
          onTap: () => _showCustomersModal(customers),
        ).animate(delay: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        DashboardStatCard(
          title: 'Puntos',
          value: '$totalPoints',
          icon: Icons.qr_code_scanner_rounded,
          subtitle: 'Escaneos aprobados en total',
          onTap: () => _showTopScansModal(customers),
        ).animate(delay: 160.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        DashboardStatCard(
          title: 'Premios',
          value: '$totalRewards',
          icon: Icons.card_giftcard_rounded,
          subtitle: 'Ganados por tus clientes',
          onTap: () => _showRewardsModal(customers),
        ).animate(delay: 240.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        DashboardStatCard(
          title: 'Requisito',
          value: '${business['points_required']}',
          icon: Icons.edit_outlined,
          subtitle: 'Puntos para un premio · toca para editar',
          onTap: () => _editCampaign(business),
        ).animate(delay: 320.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _CampaignRow extends StatelessWidget {
  final String label;
  final String value;

  const _CampaignRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.label(size: 11, tracking: 2, color: Colors.white54),
        ),
        Text(
          value,
          style: AppTypography.body(size: 16, weight: FontWeight.w500, color: AppColors.white),
        ),
      ],
    );
  }
}
