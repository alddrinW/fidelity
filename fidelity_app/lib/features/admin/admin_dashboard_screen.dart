import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/language_selector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/app_nav_row.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../auth/providers/auth_provider.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../business/dashboard/widgets/dashboard_stat_card.dart';
import 'admin_activity_screen.dart';
import 'admin_businesses_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_games_screen.dart';
import 'admin_card_payouts_screen.dart';
import 'admin_referral_locals_screen.dart';
import 'admin_settings_screen.dart';
import '../notifications/widgets/notification_bell.dart';
import '../feedback/data/feedback_repository.dart';
import '../feedback/feedback_inbox_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_qr_stats_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_users_screen.dart';
import 'data/admin_repository.dart';
import 'widgets/admin_widgets.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _adminRepo = AdminRepository();
  bool _isLoading = true;
  AdminDashboardStats _stats = const AdminDashboardStats();

  StreamSubscription<void>? _scansSub;
  StreamSubscription<void>? _rewardsSub;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _scansSub = RealtimeSyncService().onScansChanged.listen((_) {
      if (mounted) _loadMetrics();
    });
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) _loadMetrics();
    });
  }

  @override
  void dispose() {
    _scansSub?.cancel();
    _rewardsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final stats = await _adminRepo.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      DashboardAnimatedToast.show(context, 'No se pudieron cargar las métricas', isError: true);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _feedbackInbox() {
    final repository = ref.read(feedbackRepositoryProvider);
    return FeedbackInboxScreen(
      title: 'Opiniones',
      load: repository.listAll,
      onResolve: repository.resolve,
      showUser: true,
    );
  }

  Future<void> _logout() => ref.read(authStateProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      DashboardStatCard(
        title: 'Negocios',
        value: '${_stats.businesses}',
        icon: Icons.storefront_rounded,
        subtitle: _stats.inactiveBusinesses > 0
            ? '${_stats.inactiveBusinesses} por activar'
            : null,
        onTap: () => _open(const AdminBusinessesScreen()),
      ),
      DashboardStatCard(
        title: 'Pagos',
        value: '${_stats.openPayments}',
        icon: Icons.payments_rounded,
        subtitle: _stats.openPayments > 0 ? 'por validar' : 'al día',
        onTap: () => _open(const AdminPaymentsScreen()),
      ),
      DashboardStatCard(
        title: 'Clientes',
        value: '${_stats.clients}',
        icon: Icons.people_alt_rounded,
        onTap: () => _open(const AdminUsersScreen()),
      ),
      DashboardStatCard(
        title: 'Escaneos',
        value: '${_stats.scans}',
        icon: Icons.qr_code_scanner_rounded,
        subtitle: _stats.pendingScans > 0 ? '${_stats.pendingScans} pendientes' : null,
        onTap: () => _open(const AdminActivityScreen()),
      ),
      DashboardStatCard(
        title: 'Premios',
        value: '${_stats.rewards}',
        icon: Icons.card_giftcard_rounded,
        subtitle: '${_stats.claimedRewards} entregados',
        onTap: () => _open(const AdminRewardsScreen()),
      ),
    ];

    final modules = <(IconData, String, Widget)>[
      (Icons.payments_rounded, 'Pagos de registro', const AdminPaymentsScreen()),
      (Icons.sports_esports_rounded, 'Minijuegos', const AdminGamesScreen()),
      (Icons.group_add_rounded, 'Invitar amigos', const AdminReferralLocalsScreen()),
      (Icons.payments_outlined, 'Pagos a locales', const AdminCardPayoutsScreen()),
      (Icons.storefront_rounded, 'Gestión de negocios', const AdminBusinessesScreen()),
      (Icons.category_rounded, 'Gestión de categorías', const AdminCategoriesScreen()),
      (Icons.people_alt_rounded, 'Gestión de usuarios', const AdminUsersScreen()),
      (Icons.bar_chart_rounded, 'Estadísticas QR', const AdminQrStatsScreen()),
      (Icons.history_rounded, 'Actividad global', const AdminActivityScreen()),
      (Icons.forum_outlined, 'Sugerencias y reclamos', _feedbackInbox()),
      (Icons.card_giftcard_rounded, 'Gestión de premios', const AdminRewardsScreen()),
      (Icons.tune_rounded, 'Ajustes del sistema', const AdminSettingsScreen()),
    ];

    return AdminPageFrame(
      title: 'Administración',
      // La campana y "cerrar sesión": dos botones, no caben en el hueco de uno.
      headerTrailingWidth: 96,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded, color: AppColors.black),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const AdminLoading()
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              color: AppColors.black,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  const AdminSectionLabel('Resumen general'),
                  ResponsiveGrid(minTileWidth: 380, children: cards),
                  const SizedBox(height: 32),
                  const AdminSectionLabel('Módulos'),
                  ResponsiveGrid(
                    minTileWidth: 380,
                    spacing: 12,
                    children: [
                      for (final (icon, label, screen) in modules)
                        AppNavRow(icon: icon, label: label, onTap: () => _open(screen)),
                      const LanguageRow(),
                    ],
                  ),
                ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.06),
              ),
            ),
    );
  }
}
